from pydantic import BaseModel
from beanie import PydanticObjectId
from typing import Optional

# Ce que le client ENVOIE pour s'inscrire
class VendeurCreate(BaseModel):
    num_telephone: str
    mot_de_passe: str

# Schéma pour la connexion (identique à VendeurCreate, mais sémantiquement distinct)
class VendeurLogin(BaseModel):
    num_telephone: str
    mot_de_passe: str

# Réponse renvoyée après une connexion réussie
class VendeurConnexionResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    vendeur_id: str

# Ce que l'API RENVOIE – JAMAIS le mot de passe
class VendeurResponse(BaseModel):
    id: PydanticObjectId
    num_telephone: str

    class Config:
        from_attributes = True