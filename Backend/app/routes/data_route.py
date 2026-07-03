import time
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
import app.core.state as state          # ← import du module entier
from app.services.trilateration import weighted_position, multilateration_position
# Pour revenir à l'ancienne méthode (centroïde pondéré), il suffit de
# remplacer multilateration_position par weighted_position dans l'appel
# ci-dessous : la signature est identique (rssi_a, rssi_b, rssi_c) -> (x, y).

router = APIRouter(prefix="/api/data", tags=["ESP32 Data"])

MAX_AGE = 15  # secondes : âge maximal toléré pour une mesure avant de la considérer obsolète

class ESPData(BaseModel):
    esp_id: str
    rssi: float

@router.post("/", include_in_schema=False)
@router.post("")
async def receive_data(data: ESPData):
    if data.esp_id not in ("A", "B", "C"):
        raise HTTPException(400, detail="esp_id doit être A, B ou C")

    # Met à jour le dictionnaire global, avec l'horodatage de réception
    state.last_rssi[data.esp_id] = data.rssi
    state.last_rssi_ts[data.esp_id] = time.time()
    print(f"📡 Reçu ESP_{data.esp_id} : {data.rssi} dBm")

    # Si les trois mesures sont disponibles ET toutes fraîches (< MAX_AGE), calcule la position
    now = time.time()
    all_present = all(k in state.last_rssi for k in ["A", "B", "C"])
    all_fresh = all_present and all(now - state.last_rssi_ts[k] < MAX_AGE for k in ["A", "B", "C"])

    if all_fresh:
        x, y = multilateration_position(state.last_rssi["A"], state.last_rssi["B"], state.last_rssi["C"])
        # Lissage et mise à jour de la variable globale
        state.last_position = state.smooth_position((x, y))
        print(f"✅ Position calculée (multilatération) : x={state.last_position[0]:.2f}, y={state.last_position[1]:.2f}")
    elif all_present and not all_fresh:
        ages = {k: round(now - state.last_rssi_ts[k], 1) for k in ["A", "B", "C"]}
        print(f"⏳ Position non recalculée : données obsolètes détectées. Âges (s) = {ages}")

    return {"status": "ok"}