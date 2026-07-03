# app/core/config.py
import os
from dotenv import load_dotenv

# Charge le .env
load_dotenv()

class Settings:
    # Ici, Python prend STRICTEMENT ce qu'il y a dans ton fichier .env
    MONGO_URI: str = os.getenv("MONGO_URI")
    DATABASE_NAME: str = os.getenv("DATABASE_NAME")

    # Ollama — modèles et options (num_gpu=0 force le CPU si CUDA plante)
    OLLAMA_EMBED_MODEL: str = os.getenv("OLLAMA_EMBED_MODEL", "nomic-embed-text")
    OLLAMA_CHAT_MODEL: str = os.getenv("OLLAMA_CHAT_MODEL", "mistral")
    OLLAMA_NUM_GPU: int = int(os.getenv("OLLAMA_NUM_GPU", "0"))
    OLLAMA_TIMEOUT: float = float(os.getenv("OLLAMA_TIMEOUT", "90"))

# Instance unique
settings = Settings()


# Positions des ESP32 dans la salle (mètres)
ESP_POSITIONS = {
    "A": (0, 0),
    "B": (0, 4.60),
    "C": (5.60, 2.30)   # ou (2.80, 4.63) selon votre placement
}

# Paramètres de conversion RSSI → distance (à calibrer)
RSSI_0 = -37.0  
N_FACTOR = 6.0   # exposant d'affaiblissement