from fastapi import APIRouter, HTTPException, Query, Request
from fastapi.responses import StreamingResponse
import asyncio
import json

from app.services.pathfinding import compute_path, ROOM_W, ROOM_H
from app.services.stand_service import StandService
from app.core.config import ESP_POSITIONS

router = APIRouter(prefix="/api/position", tags=["Position"])


def _normaliser_mac(mac: str) -> str:
    return mac.strip().upper()


@router.get("/latest")
async def get_latest_position(mac: str = None):
    from app.mqtt.mqtt_controller import phone_data

    if mac:
        mac = _normaliser_mac(mac)
        if mac in phone_data and phone_data[mac].get("position"):
            pos = phone_data[mac]["position"]
            return {
                "mac": mac,
                "x": pos[0],
                "y": pos[1],
                "locked": phone_data[mac].get("locked", False),
                "rssi": phone_data[mac].get("rssi", {}),
            }

    for m, data in phone_data.items():
        if data.get("position") and not data.get("locked"):
            pos = data["position"]
            return {
                "mac": m,
                "x": pos[0],
                "y": pos[1],
                "locked": False,
                "rssi": data.get("rssi", {}),
            }
    return {"mac": None, "x": 0.0, "y": 0.0, "locked": False, "rssi": {}}


@router.get("/all")
async def get_all_positions():
    from app.mqtt.mqtt_controller import phone_data
    result = []
    for mac, data in phone_data.items():
        if data.get("position"):
            result.append({
                "mac": mac,
                "x": data["position"][0],
                "y": data["position"][1],
                "locked": data.get("locked", False),
                "rssi": data.get("rssi", {}),
            })
    return result


@router.get("/navigation")
async def get_navigation(
    mac: str = Query(..., description="MAC Wi-Fi du téléphone acheteur"),
    stand_id: str = Query(..., description="ID du stand cible"),
):
    """
    Retourne la position live de l'acheteur, la position verrouillée du stand
    et le chemin à afficher sur la carte.
    """
    from app.mqtt.mqtt_controller import phone_data

    mac = _normaliser_mac(mac)
    stand = await StandService.obtenir_stand_par_id(stand_id)

    if not stand.position_verrouillee or stand.position_x is None or stand.position_y is None:
        raise HTTPException(
            status_code=400,
            detail="Ce stand n'a pas encore verrouillé sa position GPS.",
        )

    buyer_data = phone_data.get(mac)
    if not buyer_data or not buyer_data.get("position"):
        raise HTTPException(
            status_code=400,
            detail="Position acheteur indisponible. Marchez dans la salle avec le Wi-Fi actif.",
        )

    bx, by = buyer_data["position"]
    sx, sy = stand.position_x, stand.position_y
    path = compute_path((bx, by), (sx, sy))

    distance_m = round(
        sum(
            ((path[i]["x"] - path[i - 1]["x"]) ** 2 + (path[i]["y"] - path[i - 1]["y"]) ** 2) ** 0.5
            for i in range(1, len(path))
        ),
        2,
    )

    return {
        "buyer": {"mac": mac, "x": bx, "y": by},
        "stand": {
            "id": str(stand.id),
            "nom": stand.nom_du_stand,
            "x": sx,
            "y": sy,
            "position_label": stand.position,
        },
        "path": path,
        "distance_m": distance_m,
        "room": {"width": ROOM_W, "height": ROOM_H},
        "esp_positions": {k: {"x": v[0], "y": v[1]} for k, v in ESP_POSITIONS.items()},
    }


@router.get("/stream")
async def stream_positions(request: Request):
    from app.mqtt.mqtt_controller import phone_data

    async def event_generator():
        last_sent = None
        while True:
            if await request.is_disconnected():
                break

            result = []
            for mac, data in phone_data.items():
                if data.get("position"):
                    result.append({
                        "mac": mac,
                        "x": data["position"][0],
                        "y": data["position"][1],
                        "locked": data.get("locked", False),
                        "rssi": data.get("rssi", {}),
                    })

            payload = json.dumps(result)
            if payload != last_sent:
                last_sent = payload
                yield f"data: {payload}\n\n"

            await asyncio.sleep(0.5)

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",
        },
    )
