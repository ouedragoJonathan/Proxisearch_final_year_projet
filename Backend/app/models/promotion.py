from beanie import Document, PydanticObjectId
from typing import List, Optional
from datetime import datetime

class Promotion(Document):
    titre: str
    description: Optional[str] = None
    vendeur_id: PydanticObjectId
    produits_ids: List[PydanticObjectId] = []
    
    # 👈 AJOUTE CECI : Ce champ n'est pas dans MongoDB, 
    # mais servira à stocker les produits lors de la réponse API
    

    class Settings:
        name = "promotions"