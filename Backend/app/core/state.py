from typing import Dict, Optional
import time
import math

# Derniers RSSI reçus de chaque ESP32
last_rssi: Dict[str, float] = {}

# Horodatage (time.time()) de la dernière réception pour chaque ESP32
last_rssi_ts: Dict[str, float] = {}

# Dernière position calculée (x, y)
last_position: Optional[tuple[float, float]] = None

# État interne du lissage exponentiel, indexé par phone_id.
_prev_position: Dict[str, tuple[float, float]] = {}
_prev_time: Dict[str, float] = {}

# Dernière position affichée (envoyée au front-end) et son horodatage, par téléphone.
_displayed_position: Dict[str, tuple[float, float]] = {}
_displayed_time: Dict[str, float] = {}

# Derniers RSSI utilisés pour un calcul de position accepté (fige le point si inchangés).
_last_rssi_used: Dict[str, dict[str, float]] = {}

MAX_HUMAN_SPEED_M_S = 1.5
MAX_SMOOTH_ALPHA = 0.25
RSSI_STABLE_THRESHOLD_DB = 3.0
MIN_DISPLAY_MOVE_M = 0.20


def _hold_displayed_position(phone_id: str) -> tuple[float, float]:
    pos = _displayed_position[phone_id]
    now = time.time()
    _prev_position[phone_id] = pos
    _prev_time[phone_id] = now
    _displayed_time[phone_id] = now
    return pos


def _rssi_unchanged(
    phone_id: str,
    rssi_a: float,
    rssi_b: float,
    rssi_c: float,
) -> bool:
    last = _last_rssi_used.get(phone_id)
    if not last:
        return False
    for key, val in (("A", rssi_a), ("B", rssi_b), ("C", rssi_c)):
        if abs(val - last[key]) > RSSI_STABLE_THRESHOLD_DB:
            return False
    return True


def clamp_position(
    phone_id: str,
    raw_pos: tuple[float, float],
    max_speed: float = MAX_HUMAN_SPEED_M_S,
) -> tuple[float, float]:
    """Limite le déplacement brut à une vitesse humaine plausible depuis la dernière
    position affichée. Premier calcul : pas de clamp, la position brute est acceptée."""
    if phone_id not in _displayed_position:
        return raw_pos

    now = time.time()
    last_x, last_y = _displayed_position[phone_id]
    dt = max(now - _displayed_time[phone_id], 1e-6)

    raw_x, raw_y = raw_pos
    dx = raw_x - last_x
    dy = raw_y - last_y
    distance_requested = math.hypot(dx, dy)
    max_distance = max_speed * dt

    if distance_requested <= max_distance or distance_requested == 0:
        return raw_pos

    scale = max_distance / distance_requested
    return (last_x + dx * scale, last_y + dy * scale)


def process_position(
    phone_id: str,
    raw_pos: tuple[float, float],
    rssi_a: float,
    rssi_b: float,
    rssi_c: float,
    tau: float = 4.5,
) -> tuple[float, float]:
    """Pipeline post-trilatération : stabilité RSSI → clamp → lissage → état affiché."""
    if phone_id in _displayed_position and _rssi_unchanged(phone_id, rssi_a, rssi_b, rssi_c):
        return _hold_displayed_position(phone_id)

    clamped = clamp_position(phone_id, raw_pos)
    smoothed = smooth_position(phone_id, clamped, tau=tau, max_alpha=MAX_SMOOTH_ALPHA)

    if phone_id in _displayed_position:
        last_x, last_y = _displayed_position[phone_id]
        if math.hypot(smoothed[0] - last_x, smoothed[1] - last_y) < MIN_DISPLAY_MOVE_M:
            return _hold_displayed_position(phone_id)

    _displayed_position[phone_id] = smoothed
    _displayed_time[phone_id] = time.time()
    _last_rssi_used[phone_id] = {"A": rssi_a, "B": rssi_b, "C": rssi_c}
    return smoothed


def smooth_position(
    phone_id: str,
    new_pos,
    tau: float = 4.5,
    max_alpha: float = MAX_SMOOTH_ALPHA,
):
    """Lissage exponentiel sensible au temps écoulé depuis la dernière mise à jour."""
    now = time.time()

    if phone_id not in _prev_position:
        _prev_position[phone_id] = new_pos
        _prev_time[phone_id] = now
        return new_pos

    dt = now - _prev_time[phone_id]
    alpha = min(1 - math.exp(-dt / tau), max_alpha)
    prev = _prev_position[phone_id]
    smoothed = (
        prev[0] * (1 - alpha) + new_pos[0] * alpha,
        prev[1] * (1 - alpha) + new_pos[1] * alpha,
    )
    _prev_position[phone_id] = smoothed
    _prev_time[phone_id] = now
    return smoothed
