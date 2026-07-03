import math
from typing import Tuple

import numpy as np
from scipy.optimize import least_squares

from app.core.config import ESP_POSITIONS, RSSI_0, N_FACTOR


def weighted_position(rssi_a: float, rssi_b: float, rssi_c: float) -> Tuple[float, float]:
    """
    Calcule la position comme une moyenne pondérée par l'inverse de la puissance.
    Retourne (x, y) dans les limites de la salle.

    Limitation connue : le résultat est mathématiquement contraint à l'intérieur
    du triangle formé par A, B, C (c'est un centroïde pondéré). Les coins de la
    salle éloignés des balises sont donc géométriquement inaccessibles avec cette
    méthode, peu importe l'ajustement des poids. Voir rssi_to_distance /
    multilateration ci-dessous pour une méthode qui ne souffre pas de cette
    limitation.
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

    x = max(0.0, min(5.60, round(x, 2)))
    y = max(0.0, min(4.60, round(y, 2)))

    return x, y


def rssi_to_distance(rssi: float, rssi_0: float = RSSI_0, n_factor: float = N_FACTOR) -> float:
    """
    Convertit un RSSI en distance estimée (mètres) via le modèle log-distance :
        d = 10^((RSSI_0 - RSSI) / (10 * N_FACTOR))

    rssi_0 et n_factor sont actuellement les valeurs globales définies dans
    config.py (non calibrées par balise). Quand une calibration par balise sera
    disponible (RSSI mesuré à 1m exact pour chaque ESP32), il suffira de passer
    des valeurs différentes ici par balise plutôt que les constantes globales —
    aucune autre partie du code n'a besoin de changer.
    """
    return 10 ** ((rssi_0 - rssi) / (10 * n_factor))


def multilateration_position(
    rssi_a: float,
    rssi_b: float,
    rssi_c: float,
    initial_guess: Tuple[float, float] = None,
) -> Tuple[float, float]:
    """
    Calcule la position (x, y) par multilatération : convertit chaque RSSI en
    distance estimée, puis résout par moindres avec scipy.optimize.least_squares
    le point (x, y) qui minimise l'écart entre distances estimées et distances
    réelles aux trois balises.

    Contrairement à weighted_position, le résultat n'est PAS contraint à
    l'intérieur du triangle A-B-C : il peut extrapoler vers les coins de la
    salle. En contrepartie, le résultat est plus sensible au bruit RSSI tant
    que RSSI_0 / N_FACTOR ne sont pas calibrés par balise.

    initial_guess : point de départ pour l'optimisation. Si non fourni, on
    utilise weighted_position comme estimation initiale raisonnable (un bon
    point de départ accélère la convergence et évite de tomber sur un minimum
    local aberrant).
    """
    xa, ya = ESP_POSITIONS["A"]
    xb, yb = ESP_POSITIONS["B"]
    xc, yc = ESP_POSITIONS["C"]

    d_a = rssi_to_distance(rssi_a)
    d_b = rssi_to_distance(rssi_b)
    d_c = rssi_to_distance(rssi_c)

    if initial_guess is None:
        initial_guess = weighted_position(rssi_a, rssi_b, rssi_c)

    def residuals(point):
        x, y = point
        return [
            math.hypot(x - xa, y - ya) - d_a,
            math.hypot(x - xb, y - yb) - d_b,
            math.hypot(x - xc, y - yc) - d_c,
        ]

    result = least_squares(residuals, x0=np.array(initial_guess))
    x, y = result.x

    # On contraint quand même le résultat aux limites physiques de la salle :
    # le modèle peut extrapoler en dehors du triangle A-B-C (c'est le but),
    # mais pas en dehors des murs réels.
    x = max(0.0, min(5.60, round(float(x), 2)))
    y = max(0.0, min(4.60, round(float(y), 2)))

    return x, y