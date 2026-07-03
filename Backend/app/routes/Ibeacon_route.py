from fastapi import APIRouter, Depends, status,Query
from beanie import PydanticObjectId
from app.schemas.Ibeacon import IBeaconCreate, IBeaconUpdate, IBeaconResponse
from app.services.Ibeacon_service import IBeaconService
from app.models.vendeur import Vendeur
from app.services.promotion_service import PromotionService # 👈 Ajout de PromotionService

# 👈 CORRECTION DE L'IMPORT : On cible le bon fichier et la bonne fonction
from app.core.security import get_current_vendeur 

router = APIRouter(prefix="/ibeacons", tags=["iBeacons"])

@router.get("/detecter/promotions", tags=["Client App - Détection"])
async def detecter_promotions_beacon(
    uuid: str = Query(..., description="UUID de l'iBeacon détecté par le téléphone"),
    major: int = Query(..., description="Major de l'iBeacon"),
    minor: int = Query(..., description="Minor de l'iBeacon")
):
    """
    Le smartphone du client appelle cette route dès qu'il capte un iBeacon en Bluetooth.
    """
    return await PromotionService.obtenir_promotions_par_ibeacon(uuid, major, minor)


@router.post("/", response_model=IBeaconResponse, status_code=status.HTTP_201_CREATED)
async def creer_ibeacon(
    data: IBeaconCreate, 
    vendeur_actuel: Vendeur = Depends(get_current_vendeur) # 👈 Changé ici
):
    return await IBeaconService.creer_ibeacon(data, vendeur_actuel)


# Route pour que le vendeur récupère sa propre balise directement
@router.get("/mon-ibeacon", response_model=IBeaconResponse)
async def obtenir_mon_ibeacon(vendeur_actuel: Vendeur = Depends(get_current_vendeur)): # 👈 Changé ici
    return await IBeaconService.obtenir_ibeacon_du_vendeur(vendeur_actuel)


@router.get("/{ibeacon_id}", response_model=IBeaconResponse)
async def obtenir_ibeacon(
    ibeacon_id: PydanticObjectId, 
    vendeur_actuel: Vendeur = Depends(get_current_vendeur) # 👈 Changé ici
):
    return await IBeaconService.obtenir_ibeacon(ibeacon_id, vendeur_actuel)


@router.get("/", response_model=list[IBeaconResponse])
async def lister_ibeacons(actif_seulement: bool = False):
    """Route globale pour l'application mobile client (sans auth requis)"""
    return await IBeaconService.lister_ibeacons(actif_seulement)


@router.put("/{ibeacon_id}", response_model=IBeaconResponse)
async def modifier_ibeacon(
    ibeacon_id: PydanticObjectId, 
    data: IBeaconUpdate, 
    vendeur_actuel: Vendeur = Depends(get_current_vendeur) # 👈 Changé ici
):
    return await IBeaconService.modifier_ibeacon(ibeacon_id, data, vendeur_actuel)


@router.delete("/{ibeacon_id}", status_code=status.HTTP_204_NO_CONTENT)
async def supprimer_ibeacon(
    ibeacon_id: PydanticObjectId, 
    vendeur_actuel: Vendeur = Depends(get_current_vendeur) # 👈 Changé ici
):
    await IBeaconService.supprimer_ibeacon(ibeacon_id, vendeur_actuel)