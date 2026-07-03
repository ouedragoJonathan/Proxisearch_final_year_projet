from fastapi import APIRouter, Depends, status, Query
from beanie import PydanticObjectId
from app.schemas.produit import ProduitsCreate, ProduitsResponse, ProduitsUpdate
from app.services.produit_service import ProduitService
from app.models.vendeur import Vendeur
from app.core.security import get_current_vendeur

router = APIRouter(prefix="/produits", tags=["Produits"])

@router.post(
    "/creation", 
    response_model=ProduitsResponse, 
    status_code=status.HTTP_201_CREATED,
    summary="Ajouter un nouveau produit à une catégorie"
)
async def creation_produit(
    donnees: ProduitsCreate, 
    vendeur: Vendeur = Depends(get_current_vendeur)
):
    """
    Crée un produit. Nécessite un Token JWT (Bearer) d'un vendeur valide.
    Le categorie_id fourni dans le JSON doit appartenir au vendeur connecté.
    """
    return await ProduitService.creer_produit(donnees, vendeur)

@router.put(
    "/modification/{produit_id}", 
    response_model=ProduitsResponse,
    summary="Modifier un produit existant"
)
async def modifier_produit(
    produit_id: PydanticObjectId, 
    donnees: ProduitsUpdate, 
    vendeur: Vendeur = Depends(get_current_vendeur)
):
    """
    Met à jour partiellement les informations d'un produit.
    """
    return await ProduitService.modifier_produit(produit_id, donnees, vendeur)

@router.delete(
    "/suppression/{produit_id}",
    summary="Supprimer un produit"
)
async def supprimer_produit(
    produit_id: PydanticObjectId, 
    vendeur: Vendeur = Depends(get_current_vendeur)
):
    """
    Supprime un produit de sa catégorie et de la base de données.
    """
    return await ProduitService.supprimer_produit(produit_id, vendeur)


@router.get(
    "/par-categorie/{categorie_id}",
    response_model=list[ProduitsResponse],
    summary="Lister les produits d'une catégorie"
)
async def lister_produits_par_categorie(
    categorie_id: PydanticObjectId,
    vendeur: Vendeur = Depends(get_current_vendeur)
):
    return await ProduitService.lister_produits_par_categorie(categorie_id, vendeur)


@router.get(
    "/recherche",
    response_model=list[ProduitsResponse],
    summary="Rechercher des produits par nom ou description"
)
async def rechercher_produits(q: str = Query(..., min_length=1)):
    return await ProduitService.rechercher_produits(q)


@router.get(
    "/aleatoires",
    summary="Produits aléatoires pour l'accueil du bot (2 à 3)"
)
async def produits_aleatoires(
    limit: int | None = Query(None, ge=2, le=3),
):
    return await ProduitService.produits_aleatoires(limit)


@router.get(
    "/recommandations",
    summary="Recommandations de produits pour un acheteur"
)
async def recommander_produits(
    acheteur_id: str = Query(..., min_length=1),
    limit: int = Query(10, ge=1, le=30),
):
    return await ProduitService.recommander_produits(acheteur_id, limit)