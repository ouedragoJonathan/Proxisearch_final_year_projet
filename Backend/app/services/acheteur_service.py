from app.models import Acheteur

class AcheteurService:
    
    @staticmethod
    async def login_or_register(device_uuid: str) -> Acheteur:
        """
        Cherche un acheteur par son UUID de téléphone.
        S'il n'existe pas encore, le crée dans la base de données.
        """
        # 1. On cherche si l'appareil est déjà connu
        acheteur = await Acheteur.find_one(Acheteur.device_uuid == device_uuid)
        
        # 2. S'il n'existe pas, c'est un nouvel utilisateur, on l'inscrit
        if not acheteur:
            acheteur = Acheteur(device_uuid=device_uuid)
            await acheteur.insert()
            
        return acheteur