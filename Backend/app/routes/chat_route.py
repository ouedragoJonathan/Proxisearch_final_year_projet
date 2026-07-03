from fastapi import APIRouter, HTTPException
from app.services.rag_service import RAGService
from app.services.historique_service import HistoriqueService
from app.models import HistoriqueDeRecherche
from app.schemas.historique import HistoriqueResponse
from app.schemas.chat import ChatRequest, ChatResponse
from datetime import datetime, timezone

router = APIRouter(prefix="/chat", tags=["Intelligence Artificielle (RAG)"])

@router.post("/synchroniser")
async def synchroniser_rag():
    """Route pour synchroniser le RAG (plus besoin de db en paramètre !)"""
    res = await RAGService.synchroniser_donnees()
    if res["status"] == "error":
        raise HTTPException(status_code=404, detail=res["message"])
    return res

@router.post("/interroger", response_model=ChatResponse)
async def interroger_rag(payload: ChatRequest):
    """Pose une question au bot avec classification d'intention et clarification multi-tours."""
    question = payload.question.strip()
    user_id = payload.user_id

    if not question:
        raise HTTPException(status_code=400, detail="La question ne peut pas être vide.")

    contexte = payload.contexte_conversation
    requete_initiale = contexte.requete_initiale if contexte else None
    derniere_clarification = contexte.derniere_clarification if contexte else None

    resultat = await RAGService.traiter_question(
        question,
        requete_initiale=requete_initiale,
        derniere_clarification=derniere_clarification,
    )

    historique = HistoriqueDeRecherche(
        acheteur=user_id,
        requete=question,
        reponse_ia=resultat["reponse"],
        produit=resultat["produits"][0]["id"] if resultat["produits"] else None,
        date_recherche=datetime.now(timezone.utc)
    )
    await historique.insert()

    return ChatResponse(**resultat)


@router.get("/historique/{acheteur_id}", response_model=list[HistoriqueResponse])
async def lister_historique(acheteur_id: str):
    """Liste l'historique de recherche d'un acheteur."""
    items = await HistoriqueService.lister_par_acheteur(acheteur_id)
    return [
        HistoriqueResponse(
            id=str(item.id),
            requete=item.requete,
            reponse_ia=item.reponse_ia,
            date_recherche=item.date_recherche,
            resultat_trouve=item.produit is not None
            or (
                item.reponse_ia is not None
                and "aucun produit" not in item.reponse_ia.lower()
            ),
        )
        for item in items
    ]


@router.delete("/historique/{acheteur_id}")
async def effacer_historique(acheteur_id: str):
    """Supprime tout l'historique de recherche d'un acheteur."""
    count = await HistoriqueService.effacer_historique(acheteur_id)
    return {"detail": f"{count} entrée(s) supprimée(s).", "count": count}
