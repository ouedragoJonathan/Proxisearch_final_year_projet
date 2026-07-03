from fastapi import APIRouter, HTTPException, status
from app.schemas.vendeur import (
    VendeurCreate,
    VendeurLogin,
    VendeurResponse,
    VendeurConnexionResponse,
)
from app.services.vendeur_service import VendeurService
from app.core.security import SecurityHelper

router = APIRouter(prefix="/vendeurs", tags=["Vendeurs"])

# ------------------------------------------------------------------
# INSCRIPTION
# ------------------------------------------------------------------
@router.post(
    "/inscription",
    response_model=VendeurResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Inscrire un nouveau vendeur"
)
async def inscription(donnees: VendeurCreate):
    """Crée un compte vendeur. Vérifie que le numéro de téléphone est unique."""
    nouveau_vendeur = await VendeurService.inscrire_vendeur(donnees)
    return VendeurResponse.model_validate(nouveau_vendeur)

# ------------------------------------------------------------------
# CONNEXION
# ------------------------------------------------------------------
@router.post(
    "/connexion",
    response_model=VendeurConnexionResponse,
    status_code=status.HTTP_200_OK,
    summary="Connecter un vendeur et obtenir un token"
)
async def connexion(donnees: VendeurLogin):
    """
    Authentifie un vendeur avec son numéro de téléphone et son mot de passe.
    Retourne un token JWT contenant l'ID du vendeur.
    """
    vendeur_valide = await VendeurService.authentifier_vendeur(
        num_telephone=donnees.num_telephone,
        mot_de_passe=donnees.mot_de_passe
    )

    if vendeur_valide is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Numéro de téléphone ou mot de passe incorrect."
        )

    # Le token doit contenir l'ID du vendeur, pas son numéro de téléphone
    access_token = SecurityHelper.creer_access_token(
        data={"sub": str(vendeur_valide.id)}   # ← CORRECTION CRITIQUE
    )

    return VendeurConnexionResponse(
        access_token=access_token,
        token_type="bearer",
        vendeur_id=str(vendeur_valide.id),
    )