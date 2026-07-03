from fastapi import APIRouter, Depends, status
from beanie import PydanticObjectId  # 👈 Import nécessaire pour typer {categorie_id}
from app.schemas.categorie import (
    CategorieCreate, 
    CategorieResponse, 
    CategorieUpdate # 👈 Import nécessaire pour la route de modification
)
from app.services.categorie_service import CategorieService
from app.models.vendeur import Vendeur
from app.core.security import get_current_vendeur

router = APIRouter(prefix="/categories", tags=["Catégories"])

@router.post(
    "/creation", 
    response_model=CategorieResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Ajouter une catégorie à un stand"
)
async def creation_categorie(
    donnees: CategorieCreate,
    vendeur_actuel: Vendeur = Depends(get_current_vendeur)
):
    return await CategorieService.creer_categorie(donnees, vendeur_actuel)

@router.put("/modification/{categorie_id}", response_model=CategorieResponse)
async def modifier_categorie(
    categorie_id: PydanticObjectId,
    donnees: CategorieUpdate,
    vendeur: Vendeur = Depends(get_current_vendeur)
):
    return await CategorieService.modifier_categorie(categorie_id, donnees, vendeur)

@router.delete("/suppression/{categorie_id}")
async def supprimer_categorie(
    categorie_id: PydanticObjectId,
    vendeur: Vendeur = Depends(get_current_vendeur)
):
    # On renvoie le résultat du service
    return await CategorieService.supprimer_categorie(categorie_id, vendeur)