from pymongo import AsyncMongoClient  # <-- Le grand changement est ici ! Fini Motor.
from beanie import init_beanie

# On importe ton gestionnaire de configuration centralisé

from app.core.config import settings

# On importe tous les modèles Beanie depuis le dossier models
from app.models import (
    Promotion, Produit, Categorie, Vendeur, 
    Stand, Notification, Acheteur, HistoriqueDeRecherche,IBeacon
)

async def init_db():
    """
    Initialise la connexion à MongoDB et lie Beanie aux modèles de documents.
    """
    # On utilise maintenant le client natif de pymongo
    client = AsyncMongoClient(settings.MONGO_URI)
    
    # On sélectionne la base de données
    database = client[settings.DATABASE_NAME]
    
    # Initialisation de Beanie
    await init_beanie(
        database=database,
        document_models=[
            Promotion,
            Produit,
            Categorie,
            Vendeur,
            Stand,
            Notification,
            Acheteur,
            HistoriqueDeRecherche,
            IBeacon
            
        ]
    )
    print(f"🚀 Connexion réussie à MongoDB ! Base de données active : {settings.DATABASE_NAME}")