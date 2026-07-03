from fastapi import APIRouter, Depends, status
from app.schemas.stand import StandCreate, StandUpdate, StandResponse, VerrouillerPositionRequest
from app.services.stand_service import StandService
from app.models.vendeur import Vendeur
from app.core.security import get_current_vendeur

router = APIRouter(prefix="/stands", tags=["Stands"])

@router.post(
    "/creation",
    response_model=StandResponse,
    status_code=status.HTTP_201_CREATED
)
async def creation_stand(
    donnees: StandCreate,
    vendeur_actuel: Vendeur = Depends(get_current_vendeur)
):
    nouveau_stand = await StandService.creer_stand(donnees, vendeur_actuel)
    return nouveau_stand


@router.get("/mon-stand", response_model=StandResponse)
async def obtenir_mon_stand(vendeur_actuel: Vendeur = Depends(get_current_vendeur)):
    return await StandService.obtenir_stand_du_vendeur(vendeur_actuel)


@router.put("/modification", response_model=StandResponse)
async def modifier_stand(
    donnees: StandUpdate,
    vendeur_actuel: Vendeur = Depends(get_current_vendeur)
):
    return await StandService.modifier_stand(donnees, vendeur_actuel)


@router.delete("/suppression")
async def supprimer_stand(vendeur_actuel: Vendeur = Depends(get_current_vendeur)):
    return await StandService.supprimer_stand(vendeur_actuel)


@router.post("/verrouiller-position", response_model=StandResponse)
async def verrouiller_position_stand(
    donnees: VerrouillerPositionRequest,
    vendeur_actuel: Vendeur = Depends(get_current_vendeur),
):
    """Verrouille la position x/y du stand depuis la trilatération Wi-Fi live."""
    return await StandService.verrouiller_position(donnees.phone_mac, vendeur_actuel)
