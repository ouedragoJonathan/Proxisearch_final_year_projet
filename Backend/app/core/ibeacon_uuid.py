import uuid as uuid_lib


def normaliser_uuid(uuid: str) -> str:
    """Forme canonique stockée en base (minuscules)."""
    return uuid.strip().lower()


def variantes_uuid(uuid: str) -> list[str]:
    """
    Formes équivalentes d'un UUID iBeacon pour la recherche.
    Couvre la casse et l'inversion d'octets (ESP32 / Android).
    """
    cleaned = uuid.strip()
    variantes = {cleaned, cleaned.lower(), cleaned.upper()}
    try:
        parsed = uuid_lib.UUID(cleaned)
        for candidate in (
            parsed,
            uuid_lib.UUID(bytes=parsed.bytes[::-1]),
        ):
            variantes.add(str(candidate).lower())
            variantes.add(str(candidate).upper())
    except ValueError:
        pass
    return list(variantes)
