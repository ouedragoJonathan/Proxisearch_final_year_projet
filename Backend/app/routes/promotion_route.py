from fastapi import APIRouter, Depends, status
from beanie import PydanticObjectId
from app.schemas.promotion import PromotionCreate, PromotionResponse, PromotionUpdate
from app.services.promotion_service import PromotionService
from app.models.vendeur import Vendeur
from app.core.security import get_current_vendeur


router = APIRouter(prefix="/promotions", tags=["Promotions"])

@router.post(
    "/creation", 
    response_model=PromotionResponse, 
    status_code=status.HTTP_201_CREATED,
    summary="Créer une promotion et l'appliquer à des produits"
)
async def creation_promotion(
    donnees: PromotionCreate, 
    vendeur: Vendeur = Depends(get_current_vendeur)
):
    return await PromotionService.creer_promotion(donnees, vendeur)

@router.put(
    "/modification/{promotion_id}", 
    response_model=PromotionResponse,
    summary="Modifier une promotion"
)
async def modifier_promotion(
    promotion_id: PydanticObjectId, 
    donnees: PromotionUpdate, 
    vendeur: Vendeur = Depends(get_current_vendeur)
):
    return await PromotionService.modifier_promotion(promotion_id, donnees, vendeur)

@router.delete(
    "/suppression/{promotion_id}",
    summary="Supprimer une promotion"
)
async def supprimer_promotion(
    promotion_id: PydanticObjectId, 
    vendeur: Vendeur = Depends(get_current_vendeur)
):
    return await PromotionService.supprimer_promotion(promotion_id, vendeur)


@router.get(
    "/mes-promotions",
    response_model=list[PromotionResponse],
    summary="Lister les promotions du vendeur connecté"
)
async def lister_mes_promotions(vendeur: Vendeur = Depends(get_current_vendeur)):
    return await PromotionService.lister_promotions_vendeur(vendeur)