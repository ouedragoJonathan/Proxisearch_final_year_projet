from pydantic import BaseModel


class ProduitRecommandeResponse(BaseModel):
    id: str
    nom: str
    description: str
    prix: int
    photo_url: str
    nom_stand: str
    nom_categorie: str
