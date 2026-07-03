from pydantic import BaseModel
from typing import Optional
from typing import List
from beanie import PydanticObjectId
from .vendeur import VendeurResponse
from .categorie import CategorieResponse

class StandCreate(BaseModel):
    nom_du_stand: str
    description: str
    position: str


class StandUpdate(BaseModel):
    nom_du_stand: Optional[str] = None
    description: Optional[str] = None
    position: Optional[str] = None


class VerrouillerPositionRequest(BaseModel):
    phone_mac: str


class StandResponse(BaseModel):
    id: PydanticObjectId
    nom_du_stand: str
    description: str
    position: str
    position_x: Optional[float] = None
    position_y: Optional[float] = None
    position_verrouillee: bool = False
    phone_mac: Optional[str] = None
    vendeur: VendeurResponse  # Les infos du vendeur du stand
    categories: List[CategorieResponse] = []  # Les catégories présentes sur ce stand

    class Config:
        from_attributes = True

