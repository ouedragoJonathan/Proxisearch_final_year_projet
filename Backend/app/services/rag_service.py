import logging
import random
import re
from typing import Literal

import ollama
import chromadb
from bson import ObjectId
from ollama import ResponseError

from app.core.config import settings
from app.models import Produit, Stand, Promotion, Categorie

logger = logging.getLogger(__name__)

_PROMPT_CLASSIFICATION = """Tu es un classificateur d'intention pour un assistant de marché.
Ta SEULE tâche est de juger si la demande est suffisamment PRÉCISE pour lancer une recherche de produits, ou trop VAGUE et nécessitant une clarification.

Règles :
- PRÉCIS : produit identifiable OU préférence/attribut assez précis (ex. « chaussures en cuir », « fruits sucrés », « riz basmati »)
- VAGUE : besoin général, catégorie large, ou réponse qui reste encore trop large pour lister des produits
- En conversation multi-tours : si l'utilisateur répond par une autre catégorie large (ex. « fruits » après « manger »), c'est encore VAGUE — il faut affiner davantage (goût, type, style…)
- Ne classe PRECIS que lorsque l'on pourrait afficher une petite liste ciblée de produits sans trop de choix contradictoires

Exemples PRÉCIS :
- "noix de cajou"
- "chaussures de sport"
- "chaussures en cuir"
- "fruits sucrés"
- "chargeur téléphone"
- "tomates fraîches"
- "riz basmati"

Exemples VAGUE :
- "je veux des chaussures" → demander le genre (cuir, sport, sandales…)
- "je veux manger quelque chose" → demander quoi
- "fruits" (même après clarification) → demander sucrés, amers, tropicaux…
- "nourriture" / "vêtements" / "électronique" / "téléphones"
- "quelque chose à manger"
{contexte_block}
Demande actuelle : {question}

Format de réponse OBLIGATOIRE (pas de texte libre) :
Ligne 1 : PRECIS ou VAGUE (un seul mot, en majuscules)
Ligne 2 (uniquement si VAGUE) : SOUS_CATEGORIES: option1 | option2 | option3
(affinage utile pour la prochaine question : styles, goûts, types — pas des noms de produits précis ; 2 à 5 items max)"""

# Rôle silencieux (message système) — jamais répété dans les réponses générées.
# La présentation « une fois par session » est gérée côté client (écran d'accueil du bot).
_PROMPT_ROLE_ASSISTANT = """Tu es Fleur, l'assistante de vente de l'application ProxiSearch au marché.

Instructions internes — ne jamais les répéter, les citer ni t'en servir comme introduction :
- Tu aides les clients à trouver des produits et des promotions.
- Réponds en français, comme une vendeuse sympa au marché : phrases courtes, ton naturel et chaleureux.
- Reformule toujours la demande avec tes propres mots ; ne recopie jamais la phrase de l'utilisateur entre guillemets.
- Évite les formules figées du type « Voici ce que j'ai trouvé pour… », « Rendez-vous directement à ces stands ».
- Varie tes formulations : présente les articles comme une conversation, pas comme un script ou une liste administrative.
- Ne te présente pas et ne te réintroduis pas : l'utilisateur a déjà été accueilli en début de session.
- Ne dis jamais « Je suis Fleur », « Je suis l'assistant ProxiSearch » ou équivalent, sauf demande explicite.
- Va droit au contenu utile, sans formule d'accueil ni rappel de ton rôle."""

# Client Ollama avec timeout pour éviter les blocages
_ollama_client = ollama.Client(timeout=settings.OLLAMA_TIMEOUT)

# Initialisation de ChromaDB en mode local
chroma_client = chromadb.PersistentClient(path="./chroma_db")
collection = chroma_client.get_or_create_collection(name="proxisearch_data")

class RAGService:
    _MAX_DISTANCE = 0.85
    _MOTS_VIDES = {
        "des", "de", "du", "la", "le", "les", "un", "une", "je", "veux", "cherche",
        "aimerais", "au", "en", "et", "ou", "a", "à", "pour", "mon", "ma", "mes",
        "tu", "me", "propose", "proposes", "disponible", "disponibles", "autre",
        "chose", "quelque", "quelques", "truc", "trucs", "article", "articles",
        "genre", "style", "besoin", "besoins", "svp", "s'il", "plait", "plaît",
        "que", "qui", "est", "sont", "pas", "ya", "mtn", "maintenant",
        "vous", "avez", "quels", "quelles", "type", "types", "sorte", "sortes",
        "dispose", "disposes", "duspose", "dusposes", "acheter", "trouver",
        "voir", "avoir", "prendre", "svt", "svp",
    }
    _TERMES_VAGUES = {
        "nourriture", "manger", "mange", "repas", "snack", "encas",
        "boisson", "boissons", "vetements", "vêtements",
        "habits", "habit", "electronique", "électronique", "tech", "technologie",
        "fruit", "fruits", "legume", "legumes", "légume", "légumes",
        "viande", "poisson", "poissons", "epicerie", "épicerie", "alimentation",
        "cosmetique", "cosmétique", "accessoire", "accessoires",
        "chaussure", "chaussures", "telephone", "téléphone", "telephones",
        "téléphones", "smartphone", "smartphones",
        "ordinateur", "ordinateurs", "informatique", "sac", "sacs",
        "bijou", "bijoux", "parfum", "parfums", "produit", "produits",
        "truc", "trucs", "article", "articles", "objet", "objets",
    }
    # Suggestions d'affinage si le LLM / la base ne fournissent rien
    _AFFINAGES_PAR_THEME: dict[str, list[str]] = {
        "chaussure": ["Cuir", "Sport / baskets", "Sandales", "Ville / habillées"],
        "chaussures": ["Cuir", "Sport / baskets", "Sandales", "Ville / habillées"],
        "manger": ["Fruits", "Légumes", "Viande", "Poissons", "Épicerie"],
        "nourriture": ["Fruits", "Légumes", "Viande", "Poissons", "Épicerie"],
        "repas": ["Fruits", "Légumes", "Viande", "Poissons", "Épicerie"],
        "fruit": ["Fruits sucrés", "Fruits acidulés", "Agrumes", "Fruits tropicaux", "Fruits secs"],
        "fruits": ["Fruits sucrés", "Fruits acidulés", "Agrumes", "Fruits tropicaux", "Fruits secs"],
        "legume": ["Feuilles", "Racines", "Légumes frais", "Légumes secs"],
        "legumes": ["Feuilles", "Racines", "Légumes frais", "Légumes secs"],
        "légume": ["Feuilles", "Racines", "Légumes frais", "Légumes secs"],
        "légumes": ["Feuilles", "Racines", "Légumes frais", "Légumes secs"],
        "vetement": ["Hommes", "Femmes", "Enfants", "Traditionnel"],
        "vetements": ["Hommes", "Femmes", "Enfants", "Traditionnel"],
        "vêtement": ["Hommes", "Femmes", "Enfants", "Traditionnel"],
        "vêtements": ["Hommes", "Femmes", "Enfants", "Traditionnel"],
        "habits": ["Hommes", "Femmes", "Enfants", "Traditionnel"],
        "telephone": ["Smartphones", "Accessoires", "Chargeurs", "Écouteurs"],
        "téléphone": ["Smartphones", "Accessoires", "Chargeurs", "Écouteurs"],
        "telephones": ["Smartphones", "Accessoires", "Chargeurs", "Écouteurs"],
        "téléphones": ["Smartphones", "Accessoires", "Chargeurs", "Écouteurs"],
        "electronique": ["Téléphones", "Ordinateurs", "Accessoires"],
        "électronique": ["Téléphones", "Ordinateurs", "Accessoires"],
        "boisson": ["Eau", "Jus", "Boissons chaudes", "Sodas"],
        "boissons": ["Eau", "Jus", "Boissons chaudes", "Sodas"],
    }
    _MOTS_ACCESSOIRE = {
        "coque", "câble", "cable", "chargeur", "étui", "etui", "protection",
        "housse", "adaptateur", "film",
    }
    _MARQUES_PRODUITS = {
        "iphone", "ipad", "macbook", "mac", "airpods", "apple", "imac",
        "samsung", "dell", "hp", "lenovo", "asus", "msi", "watch",
        "banane", "bananes", "aubergine", "aubergines", "tomate", "riz",
    }
    _ALIAS_RECHERCHE: dict[str, list[str]] = {
        "apple": ["iphone", "ipad", "macbook", "imac", "airpods", "apple watch"],
        "mac": ["macbook", "imac"],
        "telephone": ["iphone", "samsung", "smartphone"],
        "téléphone": ["iphone", "samsung", "smartphone"],
        "telephones": ["iphone", "samsung", "smartphone"],
        "téléphones": ["iphone", "samsung", "smartphone"],
        "smartphone": ["iphone", "samsung"],
        "smartphones": ["iphone", "samsung"],
        "ordinateur": ["macbook", "imac", "dell", "hp", "lenovo", "asus", "msi"],
        "portable": ["macbook", "dell", "hp", "lenovo", "asus", "msi"],
    }

    @staticmethod
    def _options_ollama() -> dict:
        opts: dict = {"num_ctx": settings.OLLAMA_NUM_CTX}
        if settings.OLLAMA_NUM_GPU > 0:
            opts["num_gpu"] = settings.OLLAMA_NUM_GPU
        return opts

    @staticmethod
    def _options_ollama_chat() -> dict:
        opts = RAGService._options_ollama()
        opts["temperature"] = 0.78
        opts["top_p"] = 0.9
        return opts

    _FALLBACKS_CLARIFICATION: dict[str, list[str]] = {
        "chaussure": [
            "Quel style de chaussures vous ferait plaisir — cuir, sport, sandales ?",
            "Vous cherchez plutôt du cuir, des baskets ou autre chose comme chaussures ?",
            "Côté chaussures, vous avez une idée du style — ville, sport, décontracté ?",
        ],
        "manger": [
            "Vous avez envie de quoi exactement — fruits, légumes, viande, autre chose ?",
            "Que diriez-vous de préciser un peu — fruits, légumes, poisson… ?",
            "Pour manger, qu'est-ce qui vous tente le plus en ce moment ?",
        ],
        "fruit": [
            "Quels fruits vous tentent — plutôt sucrés, acidulés ou exotiques ?",
            "Vous penchez pour quoi comme fruits — doux, acidulés, tropicaux ?",
            "Des fruits en particulier ? Sucrés, acidulés, agrumes… dites-moi.",
        ],
        "vetement": [
            "Quel type de vêtements vous intéresse — homme, femme, enfant, traditionnel ?",
            "Vous cherchez des vêtements pour qui, et dans quel style ?",
            "Côté habits, vous avez une préférence de style ou de taille ?",
        ],
        "generique": [
            "Pouvez-vous m'en dire un peu plus pour que je cible mieux ?",
            "Précisez-moi le style ou le type que vous avez en tête.",
            "Dites-moi un peu plus ce qui vous conviendrait.",
        ],
    }

    @staticmethod
    def _formater_prix_fcfa(prix: int) -> str:
        if prix == int(prix):
            return f"{int(prix)} FCFA"
        return f"{prix:.2f}".replace(".", ",") + " FCFA"

    @staticmethod
    def _normaliser_mot(mot: str) -> str:
        mot = mot.lower().strip()
        if len(mot) > 3 and mot.endswith("s"):
            return mot[:-1]
        return mot

    @staticmethod
    def _texte_correspond_mot(texte: str, mot: str) -> bool:
        texte = texte.lower()
        mot = RAGService._normaliser_mot(mot)
        if len(mot) < 2:
            return False
        if mot in texte:
            return True
        for partie in re.split(r"[\s\-/]+", texte):
            if RAGService._normaliser_mot(partie) == mot:
                return True
        return False

    @staticmethod
    def _score_produit(question: str, produit: dict) -> float:
        q = question.lower()
        nom = produit.get("nom", "").lower()
        description = produit.get("description", "").lower()
        score = 0.0

        mots = RAGService._extraire_mots(question) - RAGService._MOTS_VIDES
        for mot in mots:
            if RAGService._texte_correspond_mot(nom, mot):
                score += 15
            elif RAGService._texte_correspond_mot(description, mot):
                score += 5

        if any(m in q for m in ("iphone", "ipad", "macbook", "mac ", "macbook", "airpods")):
            if any(a in nom for a in RAGService._MOTS_ACCESSOIRE):
                if not any(a in q for a in RAGService._MOTS_ACCESSOIRE):
                    score -= 25

        if RAGService._categorie_pertinente(produit.get("nom_categorie", ""), question):
            score += 8

        return score

    @staticmethod
    def _est_requete_assez_precise(question: str) -> bool:
        q = question.lower().strip()
        if len(q) < 2:
            return False
        if re.search(r"\b(je\s+(veux|cherche)|j'aimerais|donne|montre|propose)\b", q):
            mots = RAGService._extraire_mots(q) - RAGService._MOTS_VIDES
            if mots:
                return True
        mots = RAGService._extraire_mots(q) - RAGService._MOTS_VIDES
        if any(m in RAGService._MARQUES_PRODUITS or RAGService._normaliser_mot(m) in RAGService._MARQUES_PRODUITS for m in mots):
            return True
        if len(mots) >= 2:
            return True
        return len(mots) == 1 and len(next(iter(mots))) >= 4

    @staticmethod
    def _resumer_besoin_client(question: str) -> str:
        """Extrait l'essence de la demande sans formules d'intention."""
        q = question.strip()
        q = re.sub(
            r"^(je\s+(veux|cherche|voudrais)|j'aimerais|donne[z]?[- ]moi|"
            r"montre[z]?|propose[z]?)\s+",
            "",
            q,
            flags=re.IGNORECASE,
        ).strip()
        return q or question.strip()

    @staticmethod
    def _construire_reponse_produits_naturelle(
        question: str,
        produits: list[dict],
    ) -> str:
        """Réponse conversationnelle structurée, sans tournure de script."""
        if not produits:
            return (
                "Je n'ai rien qui corresponde vraiment à ça pour le moment. "
                "Essayez d'autres mots-clés ou parcourez les catégories du marché."
            )

        besoin = RAGService._resumer_besoin_client(question)

        if len(produits) == 1:
            p = produits[0]
            prix = RAGService._formater_prix_fcfa(p.get("prix", 0))
            nom = p.get("nom", "ce produit")
            stand = p.get("nom_stand", "un stand du marché")
            variantes = [
                f"Pour {besoin}, j'ai repéré {nom} chez {stand}, à {prix}.",
                f"Côté {besoin}, il y a {nom} au stand {stand} — {prix}.",
                f"J'ai trouvé {nom} chez {stand}, affiché à {prix}.",
            ]
            return (
                random.choice(variantes)
                + " Les cartes ci-dessous vous mènent directement au stand."
            )

        intros = [
            f"Pour {besoin}, j'ai repéré plusieurs modèles au marché.",
            f"Côté {besoin}, voilà ce qui est disponible en ce moment.",
            f"J'ai trouvé quelques options intéressantes pour {besoin}.",
        ]
        parties: list[str] = [random.choice(intros)]
        for index, p in enumerate(produits):
            prix = RAGService._formater_prix_fcfa(p.get("prix", 0))
            nom = p.get("nom", "Produit")
            stand = p.get("nom_stand", "un stand du marché")
            categorie = p.get("nom_categorie", "")
            if index == 0:
                debut = "D'abord"
            elif index == len(produits) - 1:
                debut = "Et aussi"
            else:
                debut = "Ensuite"
            detail = f"{debut}, {nom}"
            if categorie and categorie.lower() not in ("général", "general"):
                detail += f" ({categorie})"
            detail += f" chez {stand}, à {prix}"
            parties.append(detail + ".")

        parties.append(
            "Appuyez sur une carte ci-dessous pour vous rendre au stand de votre choix."
        )
        return " ".join(parties)

    @staticmethod
    def _reponse_fallback(question: str, produits: list[dict] | None = None) -> str:
        """Réponse de secours quand Ollama (mistral) est indisponible."""
        if produits:
            return RAGService._construire_reponse_produits_naturelle(question, produits)
        return (
            "Je n'ai rien qui corresponde vraiment à ça pour le moment. "
            "Essayez d'autres mots-clés ou parcourez les catégories du marché."
        )

    @staticmethod
    def _est_reponse_scriptee(texte: str, question: str | None = None) -> bool:
        if not texte or not texte.strip():
            return True
        t = texte.lower()
        marqueurs = (
            "voici ce que j'ai trouvé",
            "rendez-vous directement",
            "rendez vous directement",
            "je suis fleur",
            "assistant proxisearch",
        )
        if any(m in t for m in marqueurs):
            return True
        if question:
            q = question.strip()
            if len(q) >= 8 and q.lower() in t:
                return True
            if f"« {q} »".lower() in t or f'"{q}"'.lower() in t:
                return True
        lignes = [l.strip() for l in texte.splitlines() if l.strip()]
        if len(lignes) >= 2 and all(
            re.match(r"^[\d•\-\*\.]+\s", l) for l in lignes
        ):
            return True
        return False

    @staticmethod
    def _post_traiter_reponse_naturelle(
        texte: str,
        question: str | None = None,
    ) -> str:
        if not texte:
            return texte
        resultat = RAGService._nettoyer_reponse_scriptee(texte, question=question)
        if question:
            besoin = RAGService._resumer_besoin_client(question)
            for variante in (
                question,
                question.lower(),
                f"« {question} »",
                f'"{question}"',
                f"« {question.lower()} »",
            ):
                if variante.lower() in resultat.lower() and besoin.lower() != variante.lower():
                    resultat = re.sub(
                        re.escape(variante),
                        besoin,
                        resultat,
                        flags=re.IGNORECASE,
                    )
        return resultat.strip()

    @staticmethod
    def _nettoyer_reponse_scriptee(
        texte: str,
        question: str | None = None,
    ) -> str:
        """Retire ou remplace les tournures figées que le modèle reproduit parfois."""
        if not texte:
            return texte
        lignes = texte.splitlines()
        nettoyees: list[str] = []
        intro_ajoutee = False
        for ligne in lignes:
            l = ligne.strip()
            if not l:
                nettoyees.append(ligne)
                continue
            if re.match(
                r"^voici ce que j'ai trouvé pour",
                l,
                re.IGNORECASE,
            ):
                if question and not intro_ajoutee:
                    besoin = RAGService._resumer_besoin_client(question)
                    nettoyees.append(
                        random.choice([
                            f"Pour {besoin}, voilà ce que j'ai repéré :",
                            f"Côté {besoin}, j'ai trouvé ceci au marché :",
                            f"Pour répondre à votre envie de {besoin} :",
                        ])
                    )
                    intro_ajoutee = True
                continue
            if re.search(
                r"rendez[- ]vous directement à ces stands",
                l,
                re.IGNORECASE,
            ):
                nettoyees.append(
                    "Les cartes ci-dessous vous mènent directement aux stands."
                )
                continue
            nettoyees.append(ligne)
        resultat = "\n".join(nettoyees).strip()
        return resultat or texte.strip()

    @staticmethod
    def _fallback_clarification(question: str, sujet: str) -> str:
        theme = (question or sujet).lower()
        if any(t in theme for t in ("chaussure",)):
            return random.choice(RAGService._FALLBACKS_CLARIFICATION["chaussure"])
        if any(t in theme for t in ("manger", "nourriture", "repas")):
            return random.choice(RAGService._FALLBACKS_CLARIFICATION["manger"])
        if any(t in theme for t in ("fruit",)):
            return random.choice(RAGService._FALLBACKS_CLARIFICATION["fruit"])
        if any(t in theme for t in ("vêtement", "vetement", "habit")):
            return random.choice(RAGService._FALLBACKS_CLARIFICATION["vetement"])
        return random.choice(RAGService._FALLBACKS_CLARIFICATION["generique"])

    @staticmethod
    def _generer_reponse_llm(
        prompt_ia: str,
        system: str | None = None,
        question: str | None = None,
    ) -> str | None:
        """Appelle Ollama ; retourne None si le modèle chat est indisponible."""
        try:
            if system:
                output = _ollama_client.chat(
                    model=settings.OLLAMA_CHAT_MODEL,
                    messages=[
                        {"role": "system", "content": system},
                        {"role": "user", "content": prompt_ia},
                    ],
                    options=RAGService._options_ollama_chat(),
                )
                brut = output["message"]["content"]
                return RAGService._post_traiter_reponse_naturelle(brut, question=question)
            output = _ollama_client.generate(
                model=settings.OLLAMA_CHAT_MODEL,
                prompt=prompt_ia,
                options={**RAGService._options_ollama(), "temperature": 0.1},
            )
            return RAGService._post_traiter_reponse_naturelle(
                output["response"], question=question
            )
        except (ResponseError, ConnectionError, TimeoutError, OSError) as exc:
            logger.warning("Ollama échoué (%s): %s", settings.OLLAMA_CHAT_MODEL, exc)
            return None

    @staticmethod
    def _construire_bloc_contexte(
        requete_initiale: str | None,
        derniere_clarification: str | None,
    ) -> str:
        if not requete_initiale and not derniere_clarification:
            return ""
        lignes = ["\nContexte de la conversation en cours :"]
        if requete_initiale:
            lignes.append(f"- Recherche initiale de l'utilisateur : « {requete_initiale} »")
        if derniere_clarification:
            lignes.append(f"- Dernière clarification posée par l'assistant : « {derniere_clarification} »")
        lignes.append(
            "Interprète la demande actuelle en tenant compte de ce contexte "
            "(la réponse de l'utilisateur précise souvent la demande initiale)."
        )
        return "\n".join(lignes) + "\n"

    @staticmethod
    def _extraire_mots(texte: str) -> set[str]:
        return set(re.findall(r"[\wàâäéèêëïîôùûüç'-]+", texte.lower()))

    @staticmethod
    def _extraire_mots_contenu(question: str) -> set[str]:
        return RAGService._extraire_mots(question) - RAGService._MOTS_VIDES

    @staticmethod
    def _est_terme_large(mot: str) -> bool:
        cle = RAGService._normaliser_mot(mot)
        return cle in RAGService._TERMES_VAGUES or mot.lower() in RAGService._TERMES_VAGUES

    @staticmethod
    def _est_demande_vague(
        question: str,
        requete_initiale: str | None = None,
    ) -> bool:
        """Détecte une demande trop large pour lister des produits directement."""
        q = question.lower().strip()
        mots_contenu = RAGService._extraire_mots_contenu(question)

        if RAGService._est_question_inventaire(q):
            return True

        if not mots_contenu:
            return True

        # Intention d'achat sans cible précise : « je veux … », « quelque chose à manger »
        marqueur_vague = re.search(
            r"\b(je\s+(veux|cherche|voudrais)|j'aimerais|donne[z]?[- ]moi|"
            r"montre[z]?|propose[z]?|quelque\s+chose|n['']importe)\b",
            q,
        )

        if marqueur_vague:
            if not mots_contenu:
                return True
            if len(mots_contenu) == 1 and RAGService._est_terme_large(next(iter(mots_contenu))):
                return True
            if all(RAGService._est_terme_large(m) for m in mots_contenu):
                return True
            # Ex. « je veux manger quelque chose » après filtrage des mots vides
            if any(RAGService._est_terme_large(m) for m in mots_contenu) and len(mots_contenu) <= 2:
                non_larges = [m for m in mots_contenu if not RAGService._est_terme_large(m)]
                if not non_larges:
                    return True

        if len(mots_contenu) == 1 and RAGService._est_terme_large(next(iter(mots_contenu))):
            return True

        if mots_contenu and all(RAGService._est_terme_large(m) for m in mots_contenu):
            return True

        # En multi-tours : une réponse avec au moins un attribut non générique → assez précis
        if requete_initiale and len(mots_contenu) <= 4:
            non_larges = [m for m in mots_contenu if not RAGService._est_terme_large(m)]
            if non_larges:
                return False
            return True

        return False

    @staticmethod
    def _suggestions_affinage_theme(texte: str) -> list[str]:
        """Retourne des options d'affinage connues pour un thème vague."""
        mots = RAGService._extraire_mots_contenu(texte)
        for mot in mots:
            cle = RAGService._normaliser_mot(mot)
            if cle in RAGService._AFFINAGES_PAR_THEME:
                return list(RAGService._AFFINAGES_PAR_THEME[cle])
            if mot.lower() in RAGService._AFFINAGES_PAR_THEME:
                return list(RAGService._AFFINAGES_PAR_THEME[mot.lower()])
        return []

    @staticmethod
    def _est_question_inventaire(question: str) -> bool:
        """Questions du type « quels types avez-vous ? » — toujours clarifier."""
        q = question.lower().strip()
        return bool(
            re.search(
                r"\b(quels?\s+types?|quelles?\s+sortes?|"
                r"qu['']est[- ]ce\s+que\s+vous\s+(avez|proposez)|"
                r"vous\s+(avez|proposez)|dispose[z]?)\b",
                q,
            )
        )

    @staticmethod
    def _requete_cible_produit_precis(requete: str, produits: list[dict]) -> bool:
        """Vrai si la requête désigne clairement un produit parmi les résultats."""
        requete_lower = requete.lower().strip()
        mots_non_larges = {
            m for m in RAGService._extraire_mots_contenu(requete)
            if not RAGService._est_terme_large(m)
        }

        for produit in produits:
            nom = produit.get("nom", "").strip()
            if not nom:
                continue
            nom_lower = nom.lower()
            if nom_lower == requete_lower:
                return True
            if nom_lower in requete_lower or requete_lower in nom_lower:
                return True
            if mots_non_larges & RAGService._extraire_mots(nom_lower):
                return True

        scores = [RAGService._score_produit(requete, p) for p in produits]
        if not scores:
            return False
        scores_tries = sorted(scores, reverse=True)
        return scores_tries[0] >= 15 and (
            len(scores_tries) == 1 or scores_tries[0] >= scores_tries[1] * 1.5
        )

    @staticmethod
    def _doit_affiner_avant_affichage(
        question: str,
        requete_effective: str,
        produits: list[dict],
        requete_initiale: str | None = None,
    ) -> bool:
        """Plusieurs résultats sans cible précise → poser une question avant de lister."""
        if not produits or len(produits) <= 1:
            return False
        if RAGService._est_demande_vague(question, requete_initiale):
            return True
        if RAGService._est_question_inventaire(question):
            return True
        return not RAGService._requete_cible_produit_precis(requete_effective, produits)

    @staticmethod
    def _est_selection_categorie_explicite(question: str) -> bool:
        """Vrai si l'utilisateur choisit une catégorie (chip), pas une phrase vague."""
        q = question.strip()
        if not q or len(q) > 80:
            return False
        if RAGService._est_demande_vague(q):
            return False
        return len(RAGService._extraire_mots_contenu(q)) <= 5

    @staticmethod
    def _est_nouveau_sujet(question: str, requete_initiale: str | None) -> bool:
        """Détecte un changement de sujet (ex. téléphones → fruits)."""
        if not requete_initiale:
            return False
        q = question.lower().strip()
        marqueurs = (
            "je veux", "je cherche", "j'aimerais", "montrez", "donnez-moi",
            "maintenant", "sinon", "plutôt", "autre chose", "changer de",
        )
        if any(q.startswith(m) for m in marqueurs):
            return True
        mots_q = RAGService._extraire_mots(q) - RAGService._MOTS_VIDES
        mots_init = RAGService._extraire_mots(requete_initiale) - RAGService._MOTS_VIDES
        if not mots_q:
            return False
        return not bool(mots_q & mots_init)

    @staticmethod
    def _categorie_pertinente(nom_categorie: str, question: str) -> bool:
        """Vérifie si une catégorie correspond aux termes de la question."""
        if not nom_categorie or nom_categorie.lower() in ("général", "general"):
            return False
        q_mots = RAGService._extraire_mots(question) - RAGService._MOTS_VIDES
        cat_mots = RAGService._extraire_mots(nom_categorie) - RAGService._MOTS_VIDES
        if q_mots & cat_mots:
            return True
        for q in q_mots:
            for c in cat_mots:
                if len(q) >= 4 and len(c) >= 4 and (q.startswith(c) or c.startswith(q)):
                    return True
        return False

    @staticmethod
    async def _trouver_categorie_par_nom(terme: str) -> Categorie | None:
        terme = terme.strip()
        if not terme or len(terme) < 2:
            return None
        exacte = await Categorie.find_one({
            "nom": {"$regex": f"^{re.escape(terme)}$", "$options": "i"}
        })
        if exacte:
            return exacte
        partielles = await Categorie.find({
            "nom": {"$regex": re.escape(terme), "$options": "i"}
        }).to_list()
        if not partielles:
            return None
        if len(partielles) == 1:
            return partielles[0]
        terme_lower = terme.lower()
        for cat in partielles:
            if cat.nom.lower() == terme_lower:
                return cat
        return partielles[0]

    @staticmethod
    async def _enrichir_produit(produit: Produit) -> dict:
        nom_categorie = "Général"
        nom_stand = "Stand partenaire"
        stand_id = None
        position_x = None
        position_y = None
        position_verrouillee = False

        stand = await RAGService._stand_pour_produit(produit)
        if getattr(produit, "categorie_id", None):
            categorie = await Categorie.get(produit.categorie_id)
            if categorie:
                nom_categorie = categorie.nom
            if stand:
                nom_stand = getattr(stand, "nom_du_stand", nom_stand)
                stand_id = str(stand.id)
                position_x = stand.position_x
                position_y = stand.position_y
                position_verrouillee = bool(stand.position_verrouillee)

        return {
            "id": str(produit.id),
            "nom": produit.nom,
            "description": getattr(produit, "description", ""),
            "prix": produit.prix,
            "photo_url": produit.photo_url,
            "nom_stand": nom_stand,
            "nom_categorie": nom_categorie,
            "stand_id": stand_id,
            "position_x": position_x,
            "position_y": position_y,
            "position_verrouillee": position_verrouillee,
        }

    @staticmethod
    async def _contexte_texte_produit(produit: Produit) -> str:
        texte, _, _, _ = await RAGService._construire_texte_produit(produit)
        return texte

    @staticmethod
    async def _rechercher_mongodb(
        question: str,
        n_results: int = 10,
    ) -> tuple[list[dict], list[str]]:
        mots = [
            m for m in RAGService._extraire_mots(question) - RAGService._MOTS_VIDES
            if len(m) >= 2
        ]
        termes: set[str] = set()
        for mot in mots:
            termes.add(mot)
            cle = RAGService._normaliser_mot(mot)
            if cle in RAGService._ALIAS_RECHERCHE:
                termes.update(RAGService._ALIAS_RECHERCHE[cle])
        if not termes:
            return [], []

        or_conditions: list[dict] = []
        for mot in termes:
            regex = {"$regex": re.escape(mot), "$options": "i"}
            or_conditions.extend([{"nom": regex}, {"description": regex}])

        produits = await Produit.find({"$or": or_conditions}).to_list()
        if not produits:
            return [], []

        scored: list[tuple[float, dict, str]] = []
        for produit in produits:
            enrichi = await RAGService._enrichir_produit(produit)
            score = RAGService._score_produit(question, enrichi)
            if score <= 0:
                continue
            contexte = await RAGService._contexte_texte_produit(produit)
            scored.append((score, enrichi, contexte))

        scored.sort(key=lambda item: item[0], reverse=True)
        top = scored[:n_results]
        if not top:
            return [], []
        return [item[1] for item in top], [item[2] for item in top]

    @staticmethod
    def _fusionner_resultats(
        *paires: tuple[list[dict], list[str]],
        n_results: int = 3,
    ) -> tuple[list[dict], list[str]]:
        produits: list[dict] = []
        contextes: list[str] = []
        vus: set[str] = set()

        for liste_produits, liste_contextes in paires:
            for produit, contexte in zip(liste_produits, liste_contextes):
                pid = produit.get("id")
                if not pid or pid in vus:
                    continue
                vus.add(pid)
                produits.append(produit)
                contextes.append(contexte)
                if len(produits) >= n_results:
                    return produits, contextes

        return produits, contextes

    @staticmethod
    async def _rechercher_par_categorie(
        categorie: Categorie,
        n_results: int = 3,
        question: str | None = None,
    ) -> tuple[list[dict], list[str]]:
        produits = await Produit.find(
            Produit.categorie_id == categorie.id
        ).to_list()
        if not produits:
            return [], []

        if question:
            scored: list[tuple[float, Produit]] = [
                (
                    RAGService._score_produit(
                        question,
                        {
                            "nom": p.nom,
                            "description": getattr(p, "description", ""),
                            "nom_categorie": categorie.nom,
                        },
                    ),
                    p,
                )
                for p in produits
            ]
            scored = [(s, p) for s, p in scored if s > 0]
            if scored:
                scored.sort(key=lambda item: item[0], reverse=True)
                produits = [p for _, p in scored[: max(n_results * 3, n_results)]]
            else:
                produits = produits[:n_results]
        else:
            produits = produits[:n_results]

        enrichis: list[dict] = []
        contextes: list[str] = []
        for produit in produits[:n_results]:
            enrichis.append(await RAGService._enrichir_produit(produit))
            contextes.append(await RAGService._contexte_texte_produit(produit))
        return enrichis, contextes

    @staticmethod
    def _construire_requete_effective(
        question: str,
        requete_initiale: str | None,
        derniere_clarification: str | None,
        est_nouveau_sujet: bool = False,
        est_selection_categorie: bool = False,
    ) -> str:
        question = question.strip()
        if est_nouveau_sujet or est_selection_categorie:
            return question
        if not requete_initiale and not derniere_clarification:
            return question
        parties = [p for p in (requete_initiale, question) if p]
        return " ".join(parties)

    @staticmethod
    def _parser_classification(
        reponse_brute: str | None,
    ) -> tuple[Literal["PRECIS", "VAGUE"], list[str]]:
        if not reponse_brute:
            return "PRECIS", []
        lignes = [l.strip() for l in reponse_brute.strip().splitlines() if l.strip()]
        premiere_ligne = lignes[0].upper() if lignes else ""
        if "VAGUE" in premiere_ligne:
            precision: Literal["PRECIS", "VAGUE"] = "VAGUE"
        elif "PRECIS" in premiere_ligne:
            precision = "PRECIS"
        else:
            precision = "PRECIS"

        suggestions: list[str] = []
        for ligne in lignes[1:]:
            if "SOUS_CATEGORIES" in ligne.upper():
                _, _, reste = ligne.partition(":")
                for part in reste.split("|"):
                    item = part.strip()
                    if item:
                        suggestions.append(item)
                break
        return precision, suggestions[:5]

    @staticmethod
    def _classifier_heuristique(
        question: str,
        requete_initiale: str | None = None,
    ) -> Literal["PRECIS", "VAGUE"]:
        """Secours quand Ollama est indisponible."""
        if RAGService._est_demande_vague(question, requete_initiale):
            return "VAGUE"
        return "PRECIS"

    @staticmethod
    def classifier_intention(
        question: str,
        requete_initiale: str | None = None,
        derniere_clarification: str | None = None,
    ) -> tuple[Literal["PRECIS", "VAGUE"], list[str]]:
        """Étape A — juge si la question est assez précise pour une recherche produit."""
        contexte_block = RAGService._construire_bloc_contexte(
            requete_initiale, derniere_clarification
        )
        prompt = _PROMPT_CLASSIFICATION.format(
            contexte_block=contexte_block,
            question=question.strip(),
        )
        reponse = RAGService._generer_reponse_llm(prompt)
        if reponse is None:
            precision = RAGService._classifier_heuristique(question, requete_initiale)
            suggestions: list[str] = []
        else:
            precision, suggestions = RAGService._parser_classification(reponse)
            if (
                precision == "PRECIS"
                and RAGService._est_demande_vague(question, requete_initiale)
            ):
                precision = "VAGUE"
        logger.info(
            "Classification intention « %s » → %s (suggestions=%s)",
            question,
            precision,
            suggestions,
        )
        return precision, suggestions

    @staticmethod
    def _recherche_chroma_sous_categories(
        question: str,
        n_results: int = 15,
    ) -> list[str]:
        """Recherche vectorielle légère (ChromaDB uniquement) pour repérer des sous-catégories."""
        try:
            response_embedding = _ollama_client.embed(
                model=settings.OLLAMA_EMBED_MODEL,
                input=question,
            )
            question_embedding = response_embedding["embeddings"][0]
            results = collection.query(
                query_embeddings=[question_embedding],
                n_results=n_results,
                include=["metadatas", "distances"],
            )
        except (ResponseError, ConnectionError, TimeoutError, OSError) as exc:
            logger.warning("Recherche Chroma sous-catégories échouée: %s", exc)
            return []

        metadatas = results.get("metadatas", [[]])[0] or []
        distances = results.get("distances", [[]])[0] or []
        categories_vues: set[str] = set()
        sous_categories: list[str] = []

        for index, meta in enumerate(metadatas):
            if not isinstance(meta, dict):
                continue
            distance = distances[index] if index < len(distances) else None
            if distance is not None and distance > RAGService._MAX_DISTANCE:
                continue
            nom = (meta.get("nom_categorie") or "").strip()
            if not nom or nom.lower() in ("général", "general"):
                continue
            cle = nom.lower()
            if cle in categories_vues:
                continue
            categories_vues.add(cle)
            sous_categories.append(nom)

        return sous_categories[:6]

    @staticmethod
    def _fusionner_sous_categories(
        *listes: list[str],
        max_items: int = 6,
    ) -> list[str]:
        fusion: list[str] = []
        vues: set[str] = set()
        for liste in listes:
            for item in liste:
                nom = item.strip()
                if not nom:
                    continue
                cle = nom.lower()
                if cle in vues:
                    continue
                vues.add(cle)
                fusion.append(nom)
                if len(fusion) >= max_items:
                    return fusion
        return fusion

    @staticmethod
    async def _extraire_types_produits(terme: str, max_items: int = 6) -> list[str]:
        """Propose des types de produits concrets pour affiner une demande vague."""
        mots = [
            m for m in RAGService._extraire_mots_contenu(terme)
            if len(m) >= 3
        ]
        if not mots:
            return []

        or_conditions: list[dict] = []
        for mot in mots:
            regex = {"$regex": re.escape(mot), "$options": "i"}
            or_conditions.extend([{"nom": regex}, {"description": regex}])

        try:
            produits = await Produit.find({"$or": or_conditions}).to_list()
        except Exception as exc:
            logger.warning("MongoDB indisponible (types produits) : %s", exc)
            return []
        types_vus: set[str] = set()
        types: list[str] = []
        for produit in produits:
            nom = produit.nom.strip()
            if not nom:
                continue
            cle = nom.lower()
            if cle in types_vus:
                continue
            types_vus.add(cle)
            types.append(nom)
            if len(types) >= max_items:
                break
        return types

    @staticmethod
    async def _extraire_sous_categories(
        question: str,
        n_results: int = 15,
        suggestions_llm: list[str] | None = None,
    ) -> list[str]:
        """Identifie les sous-catégories réelles du marché (sans pipeline produit complet)."""
        terme = question.strip()
        mots = [
            m for m in RAGService._extraire_mots_contenu(terme)
            if len(m) >= 3
        ]

        categories_mongo: list[Categorie] = []
        try:
            for mot in mots:
                trouvees = await Categorie.find({
                    "$or": [
                        {"nom": {"$regex": re.escape(mot), "$options": "i"}},
                        {"description": {"$regex": re.escape(mot), "$options": "i"}},
                    ]
                }).to_list()
                categories_mongo.extend(trouvees)
        except Exception as exc:
            logger.warning("MongoDB indisponible (sous-catégories) : %s", exc)

        categories_vues: set[str] = set()
        sous_categories: list[str] = []
        for cat in categories_mongo:
            nom = cat.nom.strip()
            if not nom or nom.lower() in ("général", "general"):
                continue
            if not RAGService._categorie_pertinente(nom, terme):
                continue
            cle = nom.lower()
            if cle in categories_vues:
                continue
            categories_vues.add(cle)
            sous_categories.append(nom)

        chroma_categories = RAGService._recherche_chroma_sous_categories(
            terme, n_results=n_results
        )
        for nom in chroma_categories:
            if RAGService._categorie_pertinente(nom, terme):
                cle = nom.lower()
                if cle not in categories_vues:
                    categories_vues.add(cle)
                    sous_categories.append(nom)

        if sous_categories:
            fusion = RAGService._fusionner_sous_categories(
                sous_categories,
                suggestions_llm or [],
                RAGService._suggestions_affinage_theme(terme),
            )
            if len(fusion) <= 1:
                types_produits = await RAGService._extraire_types_produits(terme)
                if types_produits:
                    return RAGService._fusionner_sous_categories(
                        types_produits,
                        fusion,
                        suggestions_llm or [],
                        RAGService._suggestions_affinage_theme(terme),
                    )
            return fusion

        try:
            toutes = await Categorie.find_all().to_list()
        except Exception as exc:
            logger.warning("MongoDB indisponible (liste catégories) : %s", exc)
            toutes = []

        for cat in toutes:
            nom = cat.nom.strip()
            if not nom or nom.lower() in ("général", "general"):
                continue
            if RAGService._categorie_pertinente(nom, terme):
                cle = nom.lower()
                if cle not in categories_vues:
                    categories_vues.add(cle)
                    sous_categories.append(nom)

        fusion = RAGService._fusionner_sous_categories(
            sous_categories,
            chroma_categories,
            suggestions_llm or [],
            RAGService._suggestions_affinage_theme(terme),
        )
        if len(fusion) <= 1:
            types_produits = await RAGService._extraire_types_produits(terme)
            if types_produits:
                return RAGService._fusionner_sous_categories(
                    types_produits,
                    fusion,
                    suggestions_llm or [],
                    RAGService._suggestions_affinage_theme(terme),
                )
        if not fusion:
            return RAGService._suggestions_affinage_theme(terme)
        return fusion

    @staticmethod
    def _generer_clarification(
        question: str,
        sous_categories: list[str],
        requete_initiale: str | None = None,
    ) -> str:
        """Génère une question de clarification pour fouiller le besoin du client."""
        sujet = requete_initiale or question
        besoin = RAGService._resumer_besoin_client(sujet)
        if sous_categories:
            choix = ", ".join(sous_categories)
            prompt = (
                "Tu es une vendeuse curieuse au marché : tu fouilles un peu avant de proposer.\n"
                f"Demande actuelle (à reformuler, ne pas recopier) : {question}\n"
                f"Besoin général du client : {besoin}\n"
                f"Pistes d'affinage (affichées en boutons séparés, ne pas toutes les lister) : {choix}\n\n"
                "Rédige UNE courte question orale et naturelle pour affiner le besoin.\n"
                "Varie le ton à chaque fois — évite les formules figées du type "
                "« Ok pour les fruits — plutôt sucrés… » ou « Voici ce que… ».\n"
                "Ne cite pas la phrase exacte du client entre guillemets.\n"
                "Ne liste pas toutes les options dans le texte (elles sont en boutons).\n"
                "Ne cite pas de stands ni de prix. Une seule question. Sans présentation."
            )
        else:
            prompt = (
                f"L'utilisateur a une demande encore vague : {question} "
                f"(besoin général : {besoin}).\n"
                "Rédige UNE courte question pour l'aider à préciser "
                "le genre, le style, le goût ou le type de produit. "
                "Ton vendeuse curieuse, naturelle, sans recopier sa phrase. Sans présentation."
            )

        reponse = RAGService._generer_reponse_llm(
            prompt,
            system=_PROMPT_ROLE_ASSISTANT,
            question=question,
        )
        if reponse and not RAGService._est_reponse_scriptee(reponse, question):
            return reponse.strip()

        return RAGService._fallback_clarification(question, sujet)

    @staticmethod
    async def _construire_reponse_clarification(
        question: str,
        sujet_initial: str,
        terme_clarification: str,
        suggestions_llm: list[str] | None = None,
        options_produits: list[dict] | None = None,
    ) -> dict:
        """Assemble une réponse de clarification avec puces cliquables."""
        # Préférer des axes d'affinage (goût, style…) aux noms de produits bruts
        # tant que la demande reste vague — on « fouille » avant de lister.
        affinage_theme = RAGService._suggestions_affinage_theme(
            f"{terme_clarification} {question} {sujet_initial}"
        )
        if options_produits and not RAGService._est_demande_vague(question, sujet_initial):
            sous_categories = [
                p["nom"] for p in options_produits if p.get("nom")
            ][:6]
        else:
            sous_categories = await RAGService._extraire_sous_categories(
                terme_clarification,
                n_results=15,
                suggestions_llm=suggestions_llm,
            )
            if affinage_theme:
                sous_categories = RAGService._fusionner_sous_categories(
                    affinage_theme,
                    sous_categories,
                    suggestions_llm or [],
                )

        reponse = RAGService._generer_clarification(
            question,
            sous_categories,
            requete_initiale=sujet_initial,
        )
        return {
            "reponse": reponse,
            "produits": [],
            "resultat_trouve": False,
            "type_reponse": "clarification",
            "sous_categories": sous_categories,
            "precision": "VAGUE",
            "contexte_conversation": {
                "requete_initiale": sujet_initial,
                "derniere_clarification": reponse,
            },
        }

    @staticmethod
    async def traiter_question(
        question: str,
        requete_initiale: str | None = None,
        derniere_clarification: str | None = None,
    ) -> dict:
        """
        Pipeline RAG en deux étapes :
        A) classification PRECIS/VAGUE
        B) recherche produits ou clarification selon le résultat
        """
        question = question.strip()
        if not question:
            return {
                "reponse": "Veuillez poser une question.",
                "produits": [],
                "resultat_trouve": False,
                "type_reponse": "clarification",
                "sous_categories": [],
                "precision": None,
            }

        nouveau_sujet = RAGService._est_nouveau_sujet(question, requete_initiale)
        if nouveau_sujet:
            requete_initiale = None
            derniere_clarification = None

        selection_explicite = RAGService._est_selection_categorie_explicite(question)
        categorie_cible = (
            await RAGService._trouver_categorie_par_nom(question)
            if selection_explicite
            else None
        )
        est_selection_categorie = categorie_cible is not None

        requete_effective = RAGService._construire_requete_effective(
            question,
            requete_initiale,
            derniere_clarification,
            est_nouveau_sujet=nouveau_sujet,
            est_selection_categorie=est_selection_categorie,
        )

        precision, suggestions_llm = RAGService.classifier_intention(
            question,
            requete_initiale=requete_initiale,
            derniere_clarification=derniere_clarification,
        )

        # Une sélection de catégorie (chip) n'est « précise » que si ce n'est plus un terme large
        # Ex. « fruits » après « manger » → on continue à fouiller (sucrés, amers…)
        if (
            precision == "VAGUE"
            and est_selection_categorie
            and categorie_cible is not None
            and requete_initiale is not None
            and not RAGService._est_demande_vague(question, requete_initiale)
        ):
            precision = "PRECIS"
        elif precision == "PRECIS" and RAGService._est_demande_vague(
            question, requete_initiale
        ):
            precision = "VAGUE"

        # Sujet suivi : après une réponse d'affinage, recentrer sur le besoin affiné
        if requete_initiale and not nouveau_sujet:
            sujet_initial = requete_effective
        else:
            sujet_initial = requete_initiale or question

        if precision == "VAGUE":
            # Si la réponse est encore une catégorie large (« fruits »),
            # recentrer l'affinage dessus plutôt que sur toute la phrase initiale.
            mots_q = RAGService._extraire_mots_contenu(question)
            if mots_q and all(RAGService._est_terme_large(m) for m in mots_q):
                terme_clarification = question
            else:
                terme_clarification = requete_effective if requete_initiale else question
            return await RAGService._construire_reponse_clarification(
                question,
                sujet_initial,
                terme_clarification,
                suggestions_llm=suggestions_llm,
            )

        if categorie_cible:
            produits, contexte = await RAGService._rechercher_par_categorie(
                categorie_cible, n_results=6, question=requete_effective
            )
            if produits and RAGService._doit_affiner_avant_affichage(
                question, requete_effective, produits, requete_initiale
            ):
                return await RAGService._construire_reponse_clarification(
                    question,
                    sujet_initial,
                    requete_effective,
                    suggestions_llm=suggestions_llm,
                    options_produits=produits,
                )
            if produits:
                produits = produits[:3]
                contexte = contexte[:3]
                reponse_ia = RAGService.interroger_ia(
                    requete_effective,
                    contexte_documents=contexte,
                    produits=produits,
                )
                return {
                    "reponse": reponse_ia,
                    "produits": produits,
                    "resultat_trouve": True,
                    "type_reponse": "produits",
                    "sous_categories": [],
                    "precision": "PRECIS",
                    "contexte_conversation": None,
                }

        produits, contexte = await RAGService.rechercher_produits(
            requete_effective, n_results=6
        )
        if produits and RAGService._doit_affiner_avant_affichage(
            question, requete_effective, produits, requete_initiale
        ):
            return await RAGService._construire_reponse_clarification(
                question,
                sujet_initial,
                requete_effective,
                suggestions_llm=suggestions_llm,
                options_produits=produits,
            )

        produits = produits[:3]
        contexte = contexte[:3]
        reponse_ia = RAGService.interroger_ia(
            requete_effective,
            contexte_documents=contexte,
            produits=produits,
        )
        return {
            "reponse": reponse_ia,
            "produits": produits,
            "resultat_trouve": len(produits) > 0,
            "type_reponse": "produits",
            "sous_categories": [],
            "precision": "PRECIS",
            "contexte_conversation": None,
        }

    @staticmethod
    async def _stand_pour_produit(produit: Produit) -> Stand | None:
        if not getattr(produit, "categorie_id", None):
            return None
        return await Stand.find_one({
            "$or": [
                {"categories.$id": produit.categorie_id},
                {"categories": produit.categorie_id},
            ]
        })

    @staticmethod
    async def _construire_texte_produit(produit: Produit) -> tuple[str, str, str | None, str]:
        nom_categorie = "Général"
        nom_stand = "un stand partenaire"
        vendeur_id = None

        stand = await RAGService._stand_pour_produit(produit)
        if getattr(produit, "categorie_id", None):
            categorie = await Categorie.get(produit.categorie_id)
            if categorie:
                nom_categorie = categorie.nom

            if stand:
                nom_stand = getattr(stand, "nom_du_stand", "un stand partenaire")
                if hasattr(stand, "vendeur") and stand.vendeur:
                    vendeur_id = getattr(stand.vendeur, "id", None)

        texte_descriptif = (
            f"Produit : {produit.nom}. "
            f"Type : {nom_categorie}. "
            f"Catégorie : {nom_categorie}. "
            f"Prix : {produit.prix} FCFA. "
            f"Description : {getattr(produit, 'description', '')}. "
            f"Disponible au stand : '{nom_stand}'."
        )

        promo = None
        if vendeur_id:
            promo = await Promotion.find_one({
                "$or": [
                    {"produit_id": produit.id},
                    {"vendeur_id": str(vendeur_id)}
                ]
            })

        if promo:
            texte_descriptif += (
                f" ATTENTION, ce produit bénéficie d'une promotion actuelle ! "
                f"Titre de la promo : {promo.titre}. "
                f"Détails de la réduction : {promo.description}."
            )

        return texte_descriptif, nom_stand, str(vendeur_id) if vendeur_id else None, nom_categorie

    @staticmethod
    async def synchroniser_produit(produit: Produit) -> None:
        texte_descriptif, nom_stand, vendeur_id, nom_categorie = (
            await RAGService._construire_texte_produit(produit)
        )
        response = _ollama_client.embed(
            model=settings.OLLAMA_EMBED_MODEL,
            input=texte_descriptif
        )
        embedding = response["embeddings"][0]

        collection.upsert(
            ids=[str(produit.id)],
            embeddings=[embedding],
            documents=[texte_descriptif],
            metadatas={
                "vendeur_id": vendeur_id or "inconnu",
                "nom_stand": nom_stand,
                "nom_categorie": nom_categorie,
                "a_une_promo": "true" if "promotion actuelle" in texte_descriptif else "false",
            },
        )

    @staticmethod
    def supprimer_produit_index(produit_id: str) -> None:
        collection.delete(ids=[str(produit_id)])

    @staticmethod
    async def synchroniser_donnees():
        """
        Parcourt les PRODUITS, remonte à la Catégorie puis au Stand associé,
        génère les embeddings et stocke le tout enrichi dans ChromaDB.
        """
        produits = await Produit.find_all().to_list(length=500)

        if not produits:
            return {"status": "error", "message": "Aucun produit trouvé dans MongoDB."}

        for produit in produits:
            await RAGService.synchroniser_produit(produit)

        return {"status": "success", "message": f"{len(produits)} produit(s) synchronisé(s) avec succès dans le RAG !"}

    @staticmethod
    def _filtrer_resultats_semantiques(results: dict, n_results: int = 3) -> tuple[list[str], list[str]]:
        ids = results.get("ids", [[]])[0] or []
        documents = results.get("documents", [[]])[0] or []
        distances = results.get("distances", [[]])[0] or []

        ids_filtres: list[str] = []
        documents_filtres: list[str] = []

        for index, produit_id in enumerate(ids):
            distance = distances[index] if index < len(distances) else None
            if distance is not None and distance > RAGService._MAX_DISTANCE:
                continue
            ids_filtres.append(produit_id)
            documents_filtres.append(documents[index] if index < len(documents) else "")
            if len(ids_filtres) >= n_results:
                break

        return ids_filtres, documents_filtres

    @staticmethod
    def interroger_ia(
        question: str,
        contexte_documents: list[str] | None = None,
        produits: list[dict] | None = None,
    ) -> str:
        if contexte_documents:
            contexte = "\n".join(contexte_documents)
        else:
            response_embedding = _ollama_client.embed(
                model=settings.OLLAMA_EMBED_MODEL,
                input=question
            )
            question_embedding = response_embedding["embeddings"][0]
            results = collection.query(
                query_embeddings=[question_embedding],
                n_results=3,
                include=["documents", "distances"]
            )
            _, documents_filtres = RAGService._filtrer_resultats_semantiques(results, n_results=3)
            contexte = (
                "\n".join(documents_filtres)
                if documents_filtres
                else "Aucun produit ou promotion ne correspond à cette demande."
            )

        besoin = RAGService._resumer_besoin_client(question)
        if produits:
            lignes_produits = []
            for p in produits:
                prix = RAGService._formater_prix_fcfa(p.get("prix", 0))
                cat = p.get("nom_categorie", "")
                detail = f"- {p.get('nom', 'Produit')}"
                if cat and cat.lower() not in ("général", "general"):
                    detail += f" ({cat})"
                detail += f" : {prix} chez {p.get('nom_stand', 'stand partenaire')}"
                lignes_produits.append(detail)
            bloc_produits = "\n".join(lignes_produits)
        else:
            bloc_produits = contexte

        prompt_ia = (
            "Tu présentes des produits trouvés au marché à un client.\n\n"
            "Règles de style (OBLIGATOIRES) :\n"
            "- Parle comme une vendeuse naturelle au marché, pas comme un robot ni un formulaire.\n"
            f"- Reformule le besoin (« {besoin} ») avec tes propres mots ; "
            "ne recopie jamais la phrase complète du client entre guillemets.\n"
            "- Interdit : « Voici ce que j'ai trouvé pour… », listes à puces administratives, "
            "« Rendez-vous directement à ces stands ».\n"
            "- 2 à 4 phrases fluides : intro courte, puis chaque produit intégré dans le discours "
            "(nom, prix en FCFA, stand).\n"
            "- Termine en invitant à consulter les cartes produits, sans formule figée.\n"
            "- Ne confonds pas un accessoire (coque, câble, chargeur) avec l'appareil principal "
            "sauf si le client le demande explicitement.\n"
            "- Si le contexte ne contient pas le produit demandé, dis-le clairement sans inventer.\n"
            "- Cite obligatoirement le nom du stand pour chaque produit.\n"
            "- Réponds directement, sans introduction ni présentation.\n\n"
            f"Produits à présenter :\n{bloc_produits}\n\n"
            f"Besoin du client (reformuler, ne pas recopier) : {besoin}"
        )

        reponse = RAGService._generer_reponse_llm(
            prompt_ia,
            system=_PROMPT_ROLE_ASSISTANT,
            question=question,
        )
        if reponse and not RAGService._est_reponse_scriptee(reponse, question):
            return reponse

        logger.warning("Utilisation de la réponse fallback (Ollama indisponible ou réponse scriptée).")
        return RAGService._reponse_fallback(question, produits)

    @staticmethod
    async def rechercher_produits(question: str, n_results: int = 3) -> tuple[list[dict], list[str]]:
        """Recherche hybride : MongoDB (nom/description) puis sémantique ChromaDB."""
        categorie = await RAGService._trouver_categorie_par_nom(question)
        if categorie:
            return await RAGService._rechercher_par_categorie(
                categorie, n_results, question=question
            )

        mongo_produits, mongo_contextes = await RAGService._rechercher_mongodb(
            question, n_results=max(n_results * 3, 9)
        )

        fetch_count = max(n_results * 4, 12)
        response_embedding = _ollama_client.embed(
            model=settings.OLLAMA_EMBED_MODEL,
            input=question
        )
        question_embedding = response_embedding["embeddings"][0]

        results = collection.query(
            query_embeddings=[question_embedding],
            n_results=fetch_count,
            include=["documents", "distances"]
        )

        ids_filtres, documents_filtres = RAGService._filtrer_resultats_semantiques(
            results, fetch_count
        )

        sem_produits: list[dict] = []
        sem_contextes: list[str] = []
        for index, produit_id_str in enumerate(ids_filtres):
            try:
                produit = await Produit.get(ObjectId(produit_id_str))
            except Exception:
                continue
            if not produit:
                continue
            sem_produits.append(await RAGService._enrichir_produit(produit))
            sem_contextes.append(
                documents_filtres[index] if index < len(documents_filtres) else ""
            )

        if mongo_produits or sem_produits:
            fusionnes = RAGService._fusionner_resultats(
                (mongo_produits, mongo_contextes),
                (sem_produits, sem_contextes),
                n_results=n_results * 3,
            )
            produits_enrichis, contextes = fusionnes
            if produits_enrichis:
                scored = sorted(
                    zip(produits_enrichis, contextes),
                    key=lambda pair: RAGService._score_produit(question, pair[0]),
                    reverse=True,
                )
                produits_enrichis = [p for p, _ in scored[:n_results]]
                contextes = [c for _, c in scored[:n_results]]
                return produits_enrichis, contextes

        return [], []