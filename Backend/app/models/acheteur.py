from beanie import Document, Indexed
from datetime import datetime, timezone  
from pydantic import Field
from typing import Annotated

class Acheteur(Document):
    device_uuid: Annotated[str, Indexed(unique=True)]
    
    # On utilise lambda pour dire à Pydantic d'exécuter datetime.now au moment de la création
    date_creation: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

    class Settings:
        name = "acheteurs"