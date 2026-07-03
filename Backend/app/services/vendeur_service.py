from typing import Optional

from fastapi import HTTPException, status

from app.models.vendeur import Vendeur
from app.schemas.vendeur import VendeurCreate
from app.core.security import SecurityHelper


class VendeurService:
    """
    Couche de logique métier pour l'entité Vendeur.

    Le routeur ne fait que recevoir la requête HTTP et déléguer
    ici tout le travail réel : validation, hachage du mot de passe,
    accès à MongoDB via Beanie, etc.
    """

    # ------------------------------------------------------------------
    # INSCRIPTION
    # ------------------------------------------------------------------
    @staticmethod
    async def inscrire_vendeur(donnees: VendeurCreate) -> Vendeur:
        """
        Inscrit un nouveau vendeur :
          1. Vérifie que le numéro de téléphone n'est pas déjà utilisé.
          2. Hache le mot de passe en clair avec bcrypt.
          3. Enregistre le vendeur dans MongoDB.

        Lève une HTTPException 409 si le numéro est déjà pris.
        """

        # 1. Le numéro de téléphone doit être unique
        vendeur_existant = await Vendeur.find_one(
            Vendeur.num_telephone == donnees.num_telephone
        )
        if vendeur_existant is not None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Ce numéro de téléphone est déjà associé à un compte vendeur.",
            )

        # 2. On ne stocke JAMAIS le mot de passe en clair
        mot_de_passe_hache = SecurityHelper.hacher_mot_de_passe(donnees.mot_de_passe)

        # 3. Création + insertion en base
        nouveau_vendeur = Vendeur(
            num_telephone=donnees.num_telephone,
            mot_de_passe=mot_de_passe_hache,
        )
        await nouveau_vendeur.insert()

        return nouveau_vendeur

    # ------------------------------------------------------------------
    # AUTHENTIFICATION
    # ------------------------------------------------------------------
    @staticmethod
    async def authentifier_vendeur(
        num_telephone: str, mot_de_passe: str
    ) -> Optional[Vendeur]:
        """
        Vérifie les identifiants d'un vendeur :
          1. Cherche le vendeur par son numéro de téléphone.
          2. Compare le mot de passe en clair avec le hachage stocké.

        Retourne l'objet Vendeur si les identifiants sont valides,
        sinon None (le routeur décidera de renvoyer une 401).
        """

        vendeur = await Vendeur.find_one(Vendeur.num_telephone == num_telephone)
        if vendeur is None:
            return None

        if not SecurityHelper.verifier_mot_de_passe(mot_de_passe, vendeur.mot_de_passe):
            return None

        return vendeur
