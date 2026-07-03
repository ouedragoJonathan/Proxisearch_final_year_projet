import math
from typing import List, Tuple

from app.core.config import ESP_POSITIONS

ROOM_W = 5.60
ROOM_H = 4.60
CELL = 0.4


def _line_path(
    start: Tuple[float, float],
    end: Tuple[float, float],
    step: float = 0.35,
) -> List[Tuple[float, float]]:
    x0, y0 = start
    x1, y1 = end
    dist = math.hypot(x1 - x0, y1 - y0)
    if dist < 0.05:
        return [start, end]
    n = max(int(dist / step), 1)
    points = []
    for i in range(n + 1):
        t = i / n
        x = round(x0 + (x1 - x0) * t, 2)
        y = round(y0 + (y1 - y0) * t, 2)
        points.append((x, y))
    return points


def _grid_astar(
    start: Tuple[float, float],
    end: Tuple[float, float],
) -> List[Tuple[float, float]]:
    """A* sur une grille 0,4 m avec les ESP32 comme obstacles."""
    cols = int(ROOM_W / CELL) + 1
    rows = int(ROOM_H / CELL) + 1

    def to_cell(x: float, y: float) -> Tuple[int, int]:
        return (
            max(0, min(cols - 1, int(round(x / CELL)))),
            max(0, min(rows - 1, int(round(y / CELL)))),
        )

    def to_world(cx: int, cy: int) -> Tuple[float, float]:
        return (round(cx * CELL, 2), round(cy * CELL, 2))

    obstacles = set()
    for esp_id, (ex, ey) in ESP_POSITIONS.items():
        cx, cy = to_cell(ex, ey)
        obstacles.add((cx, cy))

    start_c = to_cell(*start)
    end_c = to_cell(*end)

    if start_c in obstacles:
        for dx, dy in [(1, 0), (-1, 0), (0, 1), (0, -1)]:
            alt = (start_c[0] + dx, start_c[1] + dy)
            if 0 <= alt[0] < cols and 0 <= alt[1] < rows and alt not in obstacles:
                start_c = alt
                break
    if end_c in obstacles:
        for dx, dy in [(1, 0), (-1, 0), (0, 1), (0, -1)]:
            alt = (end_c[0] + dx, end_c[1] + dy)
            if 0 <= alt[0] < cols and 0 <= alt[1] < rows and alt not in obstacles:
                end_c = alt
                break

    def heuristic(a, b):
        return math.hypot(a[0] - b[0], a[1] - b[1])

    open_set = {start_c}
    came_from: dict = {}
    g_score = {start_c: 0.0}
    f_score = {start_c: heuristic(start_c, end_c)}

    while open_set:
        current = min(open_set, key=lambda c: f_score.get(c, float("inf")))
        if current == end_c:
            path_cells = [current]
            while current in came_from:
                current = came_from[current]
                path_cells.append(current)
            path_cells.reverse()
            return [to_world(cx, cy) for cx, cy in path_cells]

        open_set.remove(current)
        for dx, dy in [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, 1), (1, -1), (-1, -1)]:
            neighbor = (current[0] + dx, current[1] + dy)
            if not (0 <= neighbor[0] < cols and 0 <= neighbor[1] < rows):
                continue
            if neighbor in obstacles:
                continue
            step_cost = 1.414 if dx != 0 and dy != 0 else 1.0
            tentative = g_score[current] + step_cost
            if tentative < g_score.get(neighbor, float("inf")):
                came_from[neighbor] = current
                g_score[neighbor] = tentative
                f_score[neighbor] = tentative + heuristic(neighbor, end_c)
                open_set.add(neighbor)

    return _line_path(start, end)


def compute_path(
    start: Tuple[float, float],
    end: Tuple[float, float],
) -> List[dict]:
    """Calcule un chemin du point start vers end dans la salle."""
    sx = max(0.0, min(ROOM_W, start[0]))
    sy = max(0.0, min(ROOM_H, start[1]))
    ex = max(0.0, min(ROOM_W, end[0]))
    ey = max(0.0, min(ROOM_H, end[1]))

    points = _grid_astar((sx, sy), (ex, ey))
    return [{"x": p[0], "y": p[1]} for p in points]
