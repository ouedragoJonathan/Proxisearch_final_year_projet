from beanie import Document

class Vendeur(Document):
    num_telephone: str
    mot_de_passe: str

    class Settings:
        name = "vendeurs"