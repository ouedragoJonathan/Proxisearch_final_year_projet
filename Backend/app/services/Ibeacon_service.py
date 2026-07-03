from fastapi import HTTPException, status
from beanie import PydanticObjectId
from app.models.ibeacon import IBeacon
from app.models.vendeur import Vendeur
from app.schemas.Ibeacon import IBeaconCreate, IBeaconUpdate
from app.core.ibeacon_uuid import normaliser_uuid, variantes_uuid
from beanie.operators import In

class IBeaconService:

    @staticmethod
    async def creer_ibeacon(data: IBeaconCreate, vendeur_actuel: Vendeur) -> IBeacon:
        # 1. RÈGLE : Vérifier si le vendeur possède déjà un iBeacon
        deja_un_beacon = await IBeacon.find_one(IBeacon.vendeur_id == vendeur_actuel.id)
        if deja_un_beacon:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Vous possédez déjà un iBeacon. Utilisez la modification."
            )

        uuid_normalise = normaliser_uuid(data.uuid)

        # 2. Vérifier l'unicité globale du triplet UUID / major / minor
        existant = await IBeacon.find_one(
            In(IBeacon.uuid, variantes_uuid(uuid_normalise)),
            IBeacon.major == data.major,
            IBeacon.minor == data.minor,
        )
        if existant:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Un iBeacon avec cet UUID, major et minor existe déjà."
            )
            
        # 3. Création sécurisée rattachée au vendeur connecté
        ibeacon = IBeacon(
            uuid=uuid_normalise,
            major=data.major,
            minor=data.minor,
            rssi_seuil=data.rssi_seuil,
            activite=data.activite,
            vendeur_id=vendeur_actuel.id
        )
        await ibeacon.insert()
        return ibeacon

    @staticmethod
    async def obtenir_ibeacon_du_vendeur(vendeur_actuel: Vendeur) -> IBeacon:
        """Permet au vendeur de récupérer directement SON iBeacon sans connaître son ID"""
        ibeacon = await IBeacon.find_one(IBeacon.vendeur_id == vendeur_actuel.id)
        if not ibeacon:
            raise HTTPException(status_code=404, detail="Aucun iBeacon trouvé pour votre compte.")
        return ibeacon

    @staticmethod
    async def obtenir_ibeacon(ibeacon_id: PydanticObjectId, vendeur_actuel: Vendeur) -> IBeacon:
        # Sécurité : On s'assure que l'iBeacon demandé appartient bien au vendeur connecté
        ibeacon = await IBeacon.find_one(IBeacon.id == ibeacon_id, IBeacon.vendeur_id == vendeur_actuel.id)
        if not ibeacon:
            raise HTTPException(status_code=404, detail="iBeacon non trouvé ou accès non autorisé.")
        return ibeacon

    @staticmethod
    async def lister_ibeacons(actif_seulement: bool = False) -> list[IBeacon]:
        """Utile pour l'application mobile client qui doit scanner toutes les balises actives"""
        if actif_seulement:
            return await IBeacon.find(IBeacon.activite == True).to_list()
        return await IBeacon.find_all().to_list()

    @staticmethod
    async def modifier_ibeacon(ibeacon_id: PydanticObjectId, data: IBeaconUpdate, vendeur_actuel: Vendeur) -> IBeacon:
        # Sécurité : Seul le propriétaire peut modifier son iBeacon
        ibeacon = await IBeacon.find_one(IBeacon.id == ibeacon_id, IBeacon.vendeur_id == vendeur_actuel.id)
        if not ibeacon:
            raise HTTPException(status_code=404, detail="iBeacon non trouvé ou accès non autorisé.")
            
        update_dict = data.model_dump(exclude_unset=True)
        
        # Si le triplet est modifié, on revérifie qu'il n'entre pas en conflit avec un AUTRE beacon
        if any(k in update_dict for k in ["uuid", "major", "minor"]):
            nouveau_uuid = normaliser_uuid(update_dict.get("uuid", ibeacon.uuid))
            nouveau_major = update_dict.get("major", ibeacon.major)
            nouveau_minor = update_dict.get("minor", ibeacon.minor)
            if "uuid" in update_dict:
                update_dict["uuid"] = nouveau_uuid

            doublon = await IBeacon.find_one(
                In(IBeacon.uuid, variantes_uuid(nouveau_uuid)),
                IBeacon.major == nouveau_major,
                IBeacon.minor == nouveau_minor,
                IBeacon.id != ibeacon_id,
            )
            if doublon:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="Ces coordonnées (UUID, major, minor) sont déjà attribuées à un autre appareil."
                )

        for key, value in update_dict.items():
            setattr(ibeacon, key, value)
            
        await ibeacon.save()
        return ibeacon

    @staticmethod
    async def supprimer_ibeacon(ibeacon_id: PydanticObjectId, vendeur_actuel: Vendeur) -> dict:
        # Sécurité : Seul le propriétaire peut supprimer son iBeacon
        ibeacon = await IBeacon.find_one(IBeacon.id == ibeacon_id, IBeacon.vendeur_id == vendeur_actuel.id)
        if not ibeacon:
            raise HTTPException(status_code=404, detail="iBeacon non trouvé ou accès non autorisé.")
            
        await ibeacon.delete()
        return {"detail": "iBeacon supprimé avec succès."}