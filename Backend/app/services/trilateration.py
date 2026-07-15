"""
Trilatération Wi-Fi indoor — salle 5,60 m × 4,60 m.

Modèle log-distance (référence à 1 m) :
    RSSI(d) = -10 · n · log10(d) + C

Inversion RSSI → distance :
    d = 10^((C - RSSI) / (10 · n))

Trilatération : pour chaque ancre i (A, B, C),
    (x - x_i)² + (y - y_i)² = d_i²
Les cercles ne se coupent pas exactement (bruit RSSI) : résolution par moindres carrés.
"""

import math
from typing import Tuple

import numpy as np
from scipy.optimize import least_squares

from app.core.config import ESP_POSITIONS, N_FACTOR, ROOM_HEIGHT, ROOM_WIDTH, RSSI_0


def rssi_at_distance(
    distance_m: float,
    rssi_0: float = RSSI_0,
    n_factor: float = N_FACTOR,
) -> float:
    """RSSI(d) = -10·n·log10(d) + C  (d > 0, d en mètres)."""
    if distance_m <= 0:
        raise ValueError("La distance doit être strictement positive.")
    return -10.0 * n_factor * math.log10(distance_m) + rssi_0


def rssi_to_distance(
    rssi: float,
    rssi_0: float = RSSI_0,
    n_factor: float = N_FACTOR,
) -> float:
    """
    Inverse du modèle log-distance :
        d = 10^((C - RSSI) / (10 · n))

    Paramètres calibrés : C = -61,40 dBm, n = 2,52.
    """
    return 10 ** ((rssi_0 - rssi) / (10.0 * n_factor))


def distances_from_rssi(
    rssi_a: float,
    rssi_b: float,
    rssi_c: float,
    rssi_0: float = RSSI_0,
    n_factor: float = N_FACTOR,
) -> tuple[float, float, float]:
    """Convertit les trois mesures RSSI en distances estimées d_A, d_B, d_C."""
    return (
        rssi_to_distance(rssi_a, rssi_0, n_factor),
        rssi_to_distance(rssi_b, rssi_0, n_factor),
        rssi_to_distance(rssi_c, rssi_0, n_factor),
    )


def clamp_to_room(x: float, y: float) -> Tuple[float, float]:
    """Ramène (x, y) dans la salle : x ∈ [0 ; 5,60], y ∈ [0 ; 4,60]."""
    x = max(0.0, min(ROOM_WIDTH, x))
    y = max(0.0, min(ROOM_HEIGHT, y))
    return round(x, 2), round(y, 2)


def weighted_position(rssi_a: float, rssi_b: float, rssi_c: float) -> Tuple[float, float]:
    """
    Estimation grossière (centroïde pondéré) — sert uniquement de point de départ
    pour l'optimiseur. Le résultat reste contraint au triangle A-B-C.
    """
    w_a = 10 ** (rssi_a / 10.0)
    w_b = 10 ** (rssi_b / 10.0)
    w_c = 10 ** (rssi_c / 10.0)
    total_w = w_a + w_b + w_c

    xa, ya = ESP_POSITIONS["A"]
    xb, yb = ESP_POSITIONS["B"]
    xc, yc = ESP_POSITIONS["C"]

    x = (w_a * xa + w_b * xb + w_c * xc) / total_w
    y = (w_a * ya + w_b * yb + w_c * yc) / total_w
    return clamp_to_room(x, y)


def multilateration_position(
    rssi_a: float,
    rssi_b: float,
    rssi_c: float,
    initial_guess: Tuple[float, float] | None = None,
    rssi_0: float = RSSI_0,
    n_factor: float = N_FACTOR,
) -> Tuple[float, float]:
    """
    Trilatération par moindres carrés.

    1. RSSI → d_i via le modèle log-distance (C = -61,40 dBm, n = 2,52).
    2. Minimise les résidus ||(x,y) - ancre_i|| - d_i pour i ∈ {A, B, C}.
    3. Contraint le résultat aux limites physiques de la salle.
    """
    xa, ya = ESP_POSITIONS["A"]
    xb, yb = ESP_POSITIONS["B"]
    xc, yc = ESP_POSITIONS["C"]

    d_a, d_b, d_c = distances_from_rssi(rssi_a, rssi_b, rssi_c, rssi_0, n_factor)

    if initial_guess is None:
        initial_guess = weighted_position(rssi_a, rssi_b, rssi_c)

    def residuals(point: np.ndarray) -> list[float]:
        x, y = point
        return [
            math.hypot(x - xa, y - ya) - d_a,
            math.hypot(x - xb, y - yb) - d_b,
            math.hypot(x - xc, y - yc) - d_c,
        ]

    result = least_squares(
        residuals,
        x0=np.array(initial_guess, dtype=float),
        bounds=([0.0, 0.0], [ROOM_WIDTH, ROOM_HEIGHT]),
    )
    return clamp_to_room(float(result.x[0]), float(result.x[1]))
