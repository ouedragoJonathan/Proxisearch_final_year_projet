from typing import List
from beanie import Document, Link
from .produits import Produit

class Categorie(Document):
    nom: str
    description: str
    icone_url: str = ""
    produits: List[Link[Produit]] = []

    class Settings:
        name = "categories"