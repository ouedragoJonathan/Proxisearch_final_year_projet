from pydantic import BaseModel
from typing import Optional, List, TYPE_CHECKING
from beanie import PydanticObjectId

# 1. Utilisation de TYPE_CHECKING pour éviter l'import circulaire au démarrage
if TYPE_CHECKING:
    from .promotion import PromotionResponse

class ProduitsCreate(BaseModel):
    nom: str
    description: str
    prix: int
    disponibilte: bool
    photo_url: str
    categorie_id: PydanticObjectId

class ProduitsUpdate(BaseModel):
    nom: Optional[str] = None
    description: Optional[str] = None
    prix: Optional[int] = None
    disponibilte: Optional[bool] = None
    photo_url: Optional[str] = None

class ProduitsResponse(BaseModel):
    id: PydanticObjectId
    nom: str
    description: str
    prix: int
    disponibilte: bool
    photo_url: str
    categorie_id: PydanticObjectId
    
    # 2. Utilisation de guillemets pour une référence différée
    promotions: List['PromotionResponse'] = []

    class Config:
        from_attributes = True

# ---------------------------------------------------------
# 3. LIGNES MAGIQUES OBLIGATOIRES À LA FIN DU FICHIER
# ---------------------------------------------------------
from .promotion import PromotionResponse
ProduitsResponse.model_rebuild()