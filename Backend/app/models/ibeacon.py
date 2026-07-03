from beanie import Document, PydanticObjectId

class IBeacon(Document):
    uuid: str
    major: int
    minor: int
    rssi_seuil: int        # seuil de détection en dBm
    activite: bool = True   # actif par défaut
    vendeur_id: PydanticObjectId # 👈 Liaison stricte avec le vendeur


    class Settings:
        name = "ibeacons"