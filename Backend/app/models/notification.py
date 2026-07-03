from datetime import datetime
from beanie import Document
from pydantic import Field

class Notification(Document):
    message: str
    lue: bool = False
    date_envoi: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "notifications"