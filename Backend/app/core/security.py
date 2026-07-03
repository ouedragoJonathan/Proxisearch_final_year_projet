import os
from datetime import datetime, timedelta, timezone
from typing import Optional

import bcrypt
import jwt
from dotenv import load_dotenv

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from beanie import PydanticObjectId

# ⚠️ Assure-toi que le chemin vers ton modèle Vendeur est correct
from app.models.vendeur import Vendeur 

# Charger les variables d'environnement depuis le fichier .env
load_dotenv()

# Variables de configuration JWT
SECRET_KEY = os.getenv("SECRET_KEY", "une_cle_secrete_tres_longue_et_securisee_par_defaut")
ALGORITHM = os.getenv("ALGORITHM", "HS256")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", 1440)) # 24 heures par défaut

class SecurityHelper:

    @staticmethod
    def hacher_mot_de_passe(mot: str) -> str:
        """Hache un mot de passe en clair avec bcrypt."""
        mot_bytes = mot.encode('utf-8')
        sel = bcrypt.gensalt()
        mot_hache = bcrypt.hashpw(mot_bytes, sel)
        return mot_hache.decode('utf-8')

    @staticmethod
    def verifier_mot_de_passe(mot_clair: str, mot_hache: str) -> bool:
        """Vérifie si le mot de passe en clair correspond au hash enregistré."""
        mot_clair_bytes = mot_clair.encode('utf-8')
        mot_hache_bytes = mot_hache.encode('utf-8')
        return bcrypt.checkpw(mot_clair_bytes, mot_hache_bytes)

    @staticmethod
    def creer_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
        """Crée un jeton JWT valide pour l'authentification."""
        to_encode = data.copy()
        expire = datetime.now(timezone.utc) + (
            expires_delta if expires_delta else timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
        )
        to_encode.update({"exp": expire})
        encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
        return encoded_jwt

    @staticmethod
    def decoder_token(token: str) -> Optional[dict]:
        """Décode un jeton JWT. Retourne None si invalide ou expiré."""
        try:
            return jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        except jwt.PyJWTError:
            return None


# ------------------------------------------------------------------
# DÉPENDANCE D'AUTHENTIFICATION (À utiliser dans les routes)
# ------------------------------------------------------------------

# Indique à FastAPI où se trouve la route de connexion pour Swagger (la doc interactive)
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/vendeurs/connexion")

async def get_current_vendeur(token: str = Depends(oauth2_scheme)) -> Vendeur:
    """
    Dépendance FastAPI pour récupérer le vendeur actuellement connecté.
    Vérifie la validité du token et cherche le vendeur en base de données par son ID.
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Jeton d'authentification invalide ou expiré.",
        headers={"WWW-Authenticate": "Bearer"},
    )

    # 1. On décode le token
    payload = SecurityHelper.decoder_token(token)
    if payload is None:
        raise credentials_exception

    # 2. On récupère l'ID du vendeur (stocké dans 'sub' lors de la connexion)
    vendeur_id_str = payload.get("sub")
    if not vendeur_id_str:
        raise credentials_exception

    # 3. On cherche le vendeur en base de données avec Beanie
    try:
        # PydanticObjectId permet de s'assurer que le format de l'ID est bien un format MongoDB valide
        vendeur = await Vendeur.get(PydanticObjectId(vendeur_id_str))
    except Exception:
        # Si la conversion en PydanticObjectId échoue
        raise credentials_exception

    # 4. Si le vendeur n'existe plus (supprimé entre temps)
    if vendeur is None:
        raise credentials_exception

    return vendeur