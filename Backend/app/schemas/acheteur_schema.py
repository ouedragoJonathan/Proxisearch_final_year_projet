from pydantic import BaseModel

class AcheteurAuthRequest(BaseModel):
    device_uuid: str