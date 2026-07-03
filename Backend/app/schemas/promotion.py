from pydantic import BaseModel
from typing import Optional, List, TYPE_CHECKING
from beanie import PydanticObjectId

# 1. Utilisation de TYPE_CHECKING pour éviter la boucle avec produit
if TYPE_CHECKING:
    from .produit import ProduitsResponse

class PromotionCreate(BaseModel):
    titre: str
    description: Optional[str] 
    produits_ids: List[PydanticObjectId] = [] # 👈 Accepte 1 ou plusieurs produits

class PromotionUpdate(BaseModel):
    titre: Optional[str] = None
    description: Optional[str] = None
    produits_ids: Optional[List[PydanticObjectId]] = None

class PromotionResponse(BaseModel):
    id: PydanticObjectId
    titre: str
    description: Optional[str] = None
    
    # 2. On veut afficher les produits complets dans la réponse !
    #produits: List['ProduitsResponse'] = []

    class Config:
        from_attributes = True

# ---------------------------------------------------------
# 3. LIGNES MAGIQUES OBLIGATOIRES À LA FIN DU FICHIER
# ---------------------------------------------------------
from .produit import ProduitsResponse
PromotionResponse.model_rebuild()