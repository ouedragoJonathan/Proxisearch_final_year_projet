from pydantic import BaseModel
from typing import List, Optional
from beanie import PydanticObjectId
from .produit import ProduitsResponse

class CategorieCreate(BaseModel):
    nom: str
    description: str
    icone_url: str
    #stand_id: str  # 👈 OBLIGATOIRE : Pour lier la catégorie au bon stand

class CategorieUpdate(BaseModel): # 👈 N'oublie pas d'ajouter ce modèle pour la route PUT
    nom: Optional[str] = None
    description: Optional[str] = None
    icone_url: Optional[str] = None

class CategorieResponse(BaseModel):
    id: PydanticObjectId
    nom: str
    description: str
    icone_url: str
    
    produits: List[ProduitsResponse] = []

    class Config:
        from_attributes = True