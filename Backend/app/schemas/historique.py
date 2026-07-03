from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class HistoriqueResponse(BaseModel):
    id: str
    requete: str
    reponse_ia: Optional[str] = None
    date_recherche: datetime
    resultat_trouve: bool
