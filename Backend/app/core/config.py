# app/core/config.py
import os
from dotenv import load_dotenv

# Charge le .env
load_dotenv()

class Settings:
    # Ici, Python prend STRICTEMENT ce qu'il y a dans ton fichier .env
    MONGO_URI: str = os.getenv("MONGO_URI")
    DATABASE_NAME: str = os.getenv("DATABASE_NAME")

    # Ollama — num_gpu = nombre de couches du modèle sur GPU (pas le nombre de cartes).
    # 999 = forcer le maximum sur GPU (recommandé) ; 0 = CPU uniquement ; 1 = quasi tout sur CPU.
    OLLAMA_EMBED_MODEL: str = os.getenv("OLLAMA_EMBED_MODEL", "nomic-embed-text")
    OLLAMA_CHAT_MODEL: str = os.getenv("OLLAMA_CHAT_MODEL", "mistral")
    OLLAMA_NUM_GPU: int = int(os.getenv("OLLAMA_NUM_GPU", "999"))
    OLLAMA_NUM_CTX: int = int(os.getenv("OLLAMA_NUM_CTX", "2048"))
    OLLAMA_TIMEOUT: float = float(os.getenv("OLLAMA_TIMEOUT", "90"))

# Instance unique
settings = Settings()


# Dimensions de la salle (mètres) — origine (0, 0) = coin inférieur gauche
ROOM_WIDTH = 5.60   # axe x
ROOM_HEIGHT = 4.60  # axe y

# Positions des ancres ESP32 dans le repère de la salle (mètres)
ESP_POSITIONS = {
    "A": (0.00, 0.00),
    "B": (0.00, 4.60),
    "C": (5.60, 2.30),
}

# Modèle log-distance : RSSI(d) = -10·n·log10(d) + C
# C = RSSI mesuré à la distance de référence d = 1 m (RSSI₀)
RSSI_0 = -61.40   # dBm — constante C calibrée
N_FACTOR = 2.52   # exposant d'affaiblissement n