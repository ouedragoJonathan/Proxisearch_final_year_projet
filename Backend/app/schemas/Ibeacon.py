from pydantic import BaseModel
from typing import Optional
from beanie import PydanticObjectId

class IBeaconCreate(BaseModel):
    uuid: str
    major: int
    minor: int
    rssi_seuil: int = -70
    activite: bool = True

class IBeaconUpdate(BaseModel):
    uuid: Optional[str] = None
    major: Optional[int] = None
    minor: Optional[int] = None
    rssi_seuil: Optional[int] = None
    activite: Optional[bool] = None

class IBeaconResponse(BaseModel):
    id: PydanticObjectId
    uuid: str
    major: int
    minor: int
    rssi_seuil: int
    activite: bool
    vendeur_id: PydanticObjectId # 👈 Ajouté dans la réponse

    class Config:
        from_attributes = True

# Reconstruction explicite pour Pydantic v2
IBeaconResponse.model_rebuild()