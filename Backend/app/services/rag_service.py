import logging
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
- PRÉCIS : nom de produit identifiable ou sous-catégorie étroite (un type de produit clair)
- VAGUE : catégorie large, terme générique, plusieurs types de produits possibles

Exemples PRÉCIS :
- "noix de cajou"
- "chaussures de sport"
- "chargeur téléphone"
- "tomates fraîches"
- "riz basmati"
- "crème solaire"

Exemples VAGUE :
- "nourriture"
- "vêtements"
- "électronique"
- "fruits"
- "téléphones"
- "quelque chose à manger"
{contexte_block}
Demande actuelle : {question}

Format de réponse OBLIGATOIRE (pas de texte libre) :
Ligne 1 : PRECIS ou VAGUE (un seul mot, en majuscules)
Ligne 2 (uniquement si VAGUE) : SOUS_CATEGORIES: option1 | option2 | option3
(suggestions plausibles de sous-catégories, séparées par | ; 2 à 5 items max)"""

# Rôle silencieux (message système) — jamais répété dans les réponses générées.
# La présentation « une fois par session » est gérée côté client (écran d'accueil du bot).
_PROMPT_ROLE_ASSISTANT = """Tu es Fleur, l'assistante de vente de l'application ProxiSearch au marché.

Instructions internes — ne jamais les répéter, les citer ni t'en servir comme introduction :
- Tu aides les clients à trouver des produits et des promotions.
- Réponds en français, de façon amicale et directe.
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
        "chose", "que", "qui", "est", "sont", "pas", "ya", "mtn", "maintenant",
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
        return {"num_gpu": settings.OLLAMA_NUM_GPU}

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
    def _reponse_fallback(question: str, produits: list[dict] | None = None) -> str:
        """Réponse de secours quand Ollama (mistral) est indisponible."""
        if not produits:
            return (
                "Je n'ai trouvé aucun produit correspondant à votre recherche. "
                "Essayez avec d'autres mots-clés ou parcourez les catégories du marché."
            )

        lignes = [
            f"Voici ce que j'ai trouvé pour « {question} » :",
            "",
        ]
        for p in produits:
            prix = RAGService._formater_prix_fcfa(p.get("prix", 0))
            nom = p.get("nom", "Produit")
            stand = p.get("nom_stand", "Stand partenaire")
            categorie = p.get("nom_categorie", "")
            detail = f"• {nom}"
            if categorie:
                detail += f" ({categorie})"
            detail += f" — {prix} au stand « {stand} »."
            lignes.append(detail)

        lignes.append("")
        lignes.append("Rendez-vous directement à ces stands pour vos achats !")
        return "\n".join(lignes)

    @staticmethod
    def _generer_reponse_llm(prompt_ia: str, system: str | None = None) -> str | None:
        """Appelle Ollama ; retourne None si le modèle chat est indisponible."""
        try:
            if system:
                output = _ollama_client.chat(
                    model=settings.OLLAMA_CHAT_MODEL,
                    messages=[
                        {"role": "system", "content": system},
                        {"role": "user", "content": prompt_ia},
                    ],
                    options=RAGService._options_ollama(),
                )
                return output["message"]["content"]
            output = _ollama_client.generate(
                model=settings.OLLAMA_CHAT_MODEL,
                prompt=prompt_ia,
                options=RAGService._options_ollama(),
            )
            return output["response"]
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
    def _classifier_heuristique(question: str) -> Literal["PRECIS", "VAGUE"]:
        """Secours quand Ollama est indisponible."""
        termes_vagues = {
            "nourriture", "manger", "boisson", "boissons", "vetements", "vêtements",
            "habits", "electronique", "électronique", "tech", "technologie",
            "fruit", "fruits",
            "epicerie", "épicerie", "alimentation", "cosmetique", "cosmétique",
            "accessoire", "accessoires", "chaussure", "chaussures",
            "telephone", "téléphone", "telephones", "téléphones",
        }
        mots = re.findall(r"[\wàâäéèêëïîôùûüç'-]+", question.lower())
        if not mots:
            return "VAGUE"
        if len(mots) == 1 and mots[0] in termes_vagues:
            return "VAGUE"
        if len(mots) <= 2 and all(m in termes_vagues for m in mots):
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
            precision = RAGService._classifier_heuristique(question)
            suggestions: list[str] = []
        else:
            precision, suggestions = RAGService._parser_classification(reponse)
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
    async def _extraire_sous_categories(
        question: str,
        n_results: int = 15,
        suggestions_llm: list[str] | None = None,
    ) -> list[str]:
        """Identifie les sous-catégories réelles du marché (sans pipeline produit complet)."""
        terme = question.strip()
        mots = [
            m for m in RAGService._extraire_mots(terme) - RAGService._MOTS_VIDES
            if len(m) >= 3
        ]

        categories_mongo: list[Categorie] = []
        for mot in mots:
            trouvees = await Categorie.find({
                "$or": [
                    {"nom": {"$regex": re.escape(mot), "$options": "i"}},
                    {"description": {"$regex": re.escape(mot), "$options": "i"}},
                ]
            }).to_list()
            categories_mongo.extend(trouvees)

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
            return RAGService._fusionner_sous_categories(
                sous_categories,
                suggestions_llm or [],
            )

        toutes = await Categorie.find_all().to_list()
        for cat in toutes:
            nom = cat.nom.strip()
            if not nom or nom.lower() in ("général", "general"):
                continue
            if RAGService._categorie_pertinente(nom, terme):
                cle = nom.lower()
                if cle not in categories_vues:
                    categories_vues.add(cle)
                    sous_categories.append(nom)

        return RAGService._fusionner_sous_categories(
            sous_categories,
            chroma_categories,
            suggestions_llm or [],
        )

    @staticmethod
    def _generer_clarification(
        question: str,
        sous_categories: list[str],
        requete_initiale: str | None = None,
    ) -> str:
        """Génère une question de clarification avec choix pertinents."""
        sujet = requete_initiale or question
        if sous_categories:
            choix = ", ".join(sous_categories)
            prompt = (
                "L'utilisateur a fait une demande trop vague pour chercher des produits.\n"
                f"Demande : « {question} »\n"
                f"Sujet initial : « {sujet} »\n"
                f"Sous-catégories disponibles dans le marché : {choix}\n\n"
                "Rédige UNE courte question de clarification, amicale et directe, "
                "qui propose ces sous-catégories comme choix (liste ou question). "
                "Ne liste pas de produits. Ne cite pas de stands. Une seule question. "
                "Sans introduction ni présentation."
            )
        else:
            prompt = (
                f"L'utilisateur a fait une demande trop vague : « {question} ».\n"
                "Rédige UNE courte question de clarification pour préciser "
                "quel type de produit il recherche. Ne liste pas de produits. "
                "Sans introduction ni présentation."
            )

        reponse = RAGService._generer_reponse_llm(prompt, system=_PROMPT_ROLE_ASSISTANT)
        if reponse:
            return reponse.strip()

        if sous_categories:
            if len(sous_categories) == 1:
                return (
                    f"Votre demande « {sujet} » est un peu large. "
                    f"Souhaitez-vous plutôt des produits de type « {sous_categories[0]} » ?"
                )
            options = " », « ".join(sous_categories)
            return (
                f"Votre demande « {sujet} » est un peu large. "
                f"Voulez-vous plutôt : « {options} » ?"
            )
        return (
            f"Pouvez-vous préciser ce que vous cherchez exactement concernant « {sujet} » ? "
            "Par exemple un nom de produit ou une catégorie plus précise."
        )

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

        categorie_cible = await RAGService._trouver_categorie_par_nom(question)
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

        # Sélection explicite d'une catégorie (chip ou nom exact) → recherche produit
        if (
            precision == "VAGUE"
            and est_selection_categorie
            and categorie_cible is not None
            and (
                requete_initiale is not None
                or categorie_cible.nom.lower() == question.lower().strip()
            )
        ):
            precision = "PRECIS"

        sujet_initial = requete_initiale or question

        if precision == "VAGUE":
            terme_clarification = requete_effective if requete_initiale else question
            sous_categories = await RAGService._extraire_sous_categories(
                terme_clarification,
                n_results=15,
                suggestions_llm=suggestions_llm,
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

        if categorie_cible:
            produits, contexte = await RAGService._rechercher_par_categorie(
                categorie_cible, n_results=3, question=requete_effective
            )
            if produits:
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
            requete_effective, n_results=3
        )
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

        prompt_ia = (
            "Réponds à la question du client en utilisant UNIQUEMENT le contexte ci-dessous.\n"
            "Si le contexte ne contient pas le produit demandé, dis-le clairement sans proposer "
            "d'autres produits non liés et sans inventer de produits absents du contexte.\n"
            "Si plusieurs produits correspondent, cite-les tous brièvement (nom, stand, prix).\n"
            "Ne confonds pas un accessoire (coque, câble, chargeur) avec l'appareil principal "
            "sauf si le client le demande explicitement.\n"
            "CONSIGNE TRÈS IMPORTANTE : cite obligatoirement le nom du stand associé à chaque produit "
            "pour que le client sache où aller.\n"
            "Les prix sont toujours en FCFA (valeur entière telle qu'indiquée dans le contexte).\n"
            "Réponds directement, sans introduction ni présentation.\n\n"
            f"Contexte des produits/promotions :\n{contexte}\n\n"
            f"Question du client : {question}"
        )

        reponse = RAGService._generer_reponse_llm(prompt_ia, system=_PROMPT_ROLE_ASSISTANT)
        if reponse:
            return reponse

        logger.warning("Utilisation de la réponse fallback (Ollama indisponible).")
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