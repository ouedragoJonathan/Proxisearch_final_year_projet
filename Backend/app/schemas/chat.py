from typing import Literal, Optional

from pydantic import BaseModel, Field


class ContexteConversation(BaseModel):
    """Contexte minimal pour interpréter une réponse à une clarification."""

    requete_initiale: Optional[str] = None
    derniere_clarification: Optional[str] = None


class ChatRequest(BaseModel):
    question: str
    user_id: str = "anonyme"
    contexte_conversation: Optional[ContexteConversation] = None


class ChatResponse(BaseModel):
    reponse: str
    produits: list[dict] = Field(default_factory=list)
    resultat_trouve: bool = False
    type_reponse: Literal["produits", "clarification"] = "produits"
    sous_categories: list[str] = Field(default_factory=list)
    precision: Optional[Literal["PRECIS", "VAGUE"]] = None
    contexte_conversation: Optional[ContexteConversation] = None
