from fastapi import APIRouter
from app.schemas.acheteur_schema import AcheteurAuthRequest
from app.services.acheteur_service import AcheteurService

router = APIRouter(prefix="/acheteurs", tags=["Acheteurs"])

@router.post("/auth")
async def authentifier_appareil(payload: AcheteurAuthRequest):
    """
    Reçoit l'UUID du téléphone. 
    Si l'UUID est nouveau, crée un compte Acheteur. Sinon, le récupère.
    """
    acheteur = await AcheteurService.login_or_register(payload.device_uuid)
    
    return {
        "status": "success",
        "message": "Acheteur authentifié avec succès",
        "acheteur_id": str(acheteur.id),
        "device_uuid": acheteur.device_uuid
    }