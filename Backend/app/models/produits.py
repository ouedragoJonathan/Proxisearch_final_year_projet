from typing import List
from beanie import Document, Link, PydanticObjectId
from app.models.promotion import Promotion  # On importe le modèle Promotion

class Produit(Document):  # 👈 1. Retrait du "s" : on l'appelle Produit
    nom: str
    description: str
    prix: int
    disponibilte: bool = True
    photo_url: str
    categorie_id: PydanticObjectId
    promotions: List[Link[Promotion]] = []  # 👈 2. Remplacé par une liste pour le Many-to-Many !

    class Settings:
        name = "produits"