from typing import List, Optional
from beanie import Document, Link
from .vendeur import Vendeur
from .categories import Categorie

class Stand(Document):
    nom_du_stand: str
    description: str
    position: str
    position_x: Optional[float] = None
    position_y: Optional[float] = None
    position_verrouillee: bool = False
    phone_mac: Optional[str] = None
    clics_notif: int = 0
    vendeur: Link[Vendeur]
    categories: List[Link[Categorie]] = []

    class Settings:
        name = "stands"