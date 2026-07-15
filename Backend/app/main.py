import sys
import traceback

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles 

# Imports de la base de données
from app.db.database import init_db

# Imports de tous les routeurs
from app.routes.vendeur_route import router as vendeur_router
from app.routes.stand_route import router as stand_router
from app.routes.categorie_route import router as categorie_router
from app.routes.produit_route import router as produit_router
from app.routes.promotion_route import router as promotion_router
from app.routes.Ibeacon_route import router as ibeacon_router
from app.routes.acheteur_route import router as acheteur_router
from app.routes.chat_route import router as chat_router
#from app.routes.data_route import router as data_router
from app.routes.position_route import router as position_router
from app.mqtt.mqtt_controller import start_mqtt
from app.services.rag_service import RAGService

# Création de l'application FastAPI
app = FastAPI(
    title="ProxiSearch API",
    description="API complète pour le projet ProxiSearch (Vendeurs, Stands, Catégories, Produits, Promotions)",
    version="1.0.0"
)


app.mount("/static", StaticFiles(directory="app/static"), name="static")


# -------------------------------------------------------------------
# Connexion à MongoDB au démarrage de l'application via Beanie
# -------------------------------------------------------------------
@app.on_event("startup")
async def demarrage_api():
    print("⏳ Démarrage de l'API ProxiSearch et connexion à MongoDB...", flush=True)
    await init_db()
    await start_mqtt()   # <-- lance le client MQTT
    try:
        sync_result = await RAGService.synchroniser_donnees()
        print(f"🔄 RAG synchronisé : {sync_result.get('message', sync_result)}", flush=True)
    except Exception as exc:
        print(f"⚠️ Synchronisation RAG ignorée au démarrage : {exc}", flush=True)
    await _charger_positions_verrouillees()
    print("✅ Base de données connectée avec succès !", flush=True)


async def _charger_positions_verrouillees():
    """Recharge en mémoire les positions vendeur verrouillées depuis MongoDB."""
    from app.models.stand import Stand
    from app.mqtt.mqtt_controller import lock_phone_position

    stands = await Stand.find(Stand.position_verrouillee == True).to_list()
    for stand in stands:
        if stand.phone_mac and stand.position_x is not None and stand.position_y is not None:
            lock_phone_position(stand.phone_mac, (stand.position_x, stand.position_y))
            print(
                f"🔒 Stand « {stand.nom_du_stand} » verrouillé à "
                f"({stand.position_x}, {stand.position_y}) — MAC {stand.phone_mac}",
                flush=True,
            )

# -------------------------------------------------------------------
# Middleware de log (avec flush forcé)
# -------------------------------------------------------------------
@app.middleware("http")
async def log_everything(request: Request, call_next):
    print(f"--- REQUÊTE REÇUE: {request.method} {request.url.path} ---", flush=True)
    try:
        response = await call_next(request)
        return response
    except Exception as e:
        print("!!! ERREUR CATCHÉE PAR MIDDLEWARE !!!", flush=True)
        traceback.print_exc(file=sys.stdout)
        sys.stdout.flush()
        raise e

# -------------------------------------------------------------------
# Enregistrement de tous les routeurs
# -------------------------------------------------------------------
app.include_router(vendeur_router)
app.include_router(stand_router)
app.include_router(categorie_router)
app.include_router(produit_router)
app.include_router(promotion_router)
app.include_router(ibeacon_router)
app.include_router(acheteur_router)
app.include_router(chat_router)

#testons les postions des esp32
#app.include_router(data_router)
app.include_router(position_router)

# -------------------------------------------------------------------
# Route racine et ping
# -------------------------------------------------------------------
@app.get("/", tags=["Accueil"])
async def root():
    return {
        "message": "Bienvenue sur l'API ProxiSearch !",
        "statut": "Tous les modules (Vendeurs, Stands, Catégories, Produits, Promotions) sont opérationnels."
    }

@app.get("/ping")
async def ping():
    print("ping reçu", flush=True)
    return {"ping": "ok"}

# -------------------------------------------------------------------
# Gestionnaire global d'exceptions (avec flush forcé)
# -------------------------------------------------------------------
@app.exception_handler(Exception)
async def debug_exception_handler(request, exc):
    print("--- !!! ERREUR DÉTECTÉE PAR LE HANDLER DEBUG !!! ---", flush=True)
    print(f"Exception type: {type(exc)}", flush=True)
    print(f"Exception message: {str(exc)}", flush=True)
    traceback.print_exc(file=sys.stdout)
    sys.stdout.flush()
    print("--- FIN DU TRACEBACK ---", flush=True)

    # On renvoie quand même une 500 pour ne pas casser Postman
    return JSONResponse(
        status_code=500,
        content={"detail": str(exc) or "Erreur critique. Regarde le terminal !"}
    )