from beanie import Document
from pydantic import Field
from typing import Optional
from datetime import datetime, timezone

class HistoriqueDeRecherche(Document):
    acheteur: str
    requete: str
    # On rend le produit optionnel (il peut être None)
    produit: Optional[str] = None
    # Ajoute la réponse de l'IA si tu veux la stocker
    reponse_ia: Optional[str] = None
    date_recherche: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

    class Settings:
        name = "historiques_recherches"