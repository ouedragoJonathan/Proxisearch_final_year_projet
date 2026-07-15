from fastapi import HTTPException, status
from beanie import PydanticObjectId
from app.models.stand import Stand
from app.models.vendeur import Vendeur
from app.models.categories import Categorie
from app.models.produits import Produit
from app.schemas.stand import StandCreate, StandUpdate


def _normaliser_mac(mac: str) -> str:
    return mac.strip().upper()


class StandService:
    """
    Logique métier pour la gestion des stands.
    """

    @staticmethod
    async def trouver_par_categorie(categorie_id: PydanticObjectId) -> Stand | None:
        """Trouve le stand contenant une catégorie (requête MongoDB fiable)."""
        return await Stand.find_one({
            "$or": [
                {"categories.$id": categorie_id},
                {"categories": categorie_id},
            ]
        })

    @staticmethod
    async def creer_stand(donnees: StandCreate, vendeur_actuel: Vendeur) -> Stand:
        """
        Crée un nouveau stand pour le vendeur connecté.
        Lève une 409 si le vendeur possède déjà un stand.
        """
        # 1. Vérifier l'unicité du stand par vendeur
        existant = await Stand.find_one(Stand.vendeur.id == vendeur_actuel.id)
        if existant:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Vous possédez déjà un stand. Utilisez la modification."
            )

        # 2. Création du document
        nouveau_stand = Stand(
            nom_du_stand=donnees.nom_du_stand,
            description=donnees.description,
            position=donnees.position,
            vendeur=vendeur_actuel,
            categories=[]
        )

        # 3. Insertion en base
        await nouveau_stand.insert()

        # 4. Résoudre TOUS les liens (vendeur, catégories)
        await nouveau_stand.fetch_all_links()

        return nouveau_stand

    @staticmethod
    async def obtenir_stand_du_vendeur(vendeur_actuel: Vendeur) -> Stand:
        """
        Récupère le stand du vendeur connecté.
        Lève une 404 si aucun stand n'existe.
        """
        stand = await Stand.find_one(Stand.vendeur.id == vendeur_actuel.id)
        if not stand:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Aucun stand trouvé pour ce vendeur."
            )

        # Résolution complète des liens
        await stand.fetch_all_links()
        for categorie in stand.categories or []:
            await categorie.fetch_link(Categorie.produits)
            for produit in categorie.produits or []:
                await produit.fetch_link(Produit.promotions)
        return stand

    @staticmethod
    async def modifier_stand(donnees: StandUpdate, vendeur_actuel: Vendeur) -> Stand:
        stand = await Stand.find_one(Stand.vendeur.id == vendeur_actuel.id)
        if not stand:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Aucun stand trouvé pour ce vendeur."
            )

        update_data = donnees.model_dump(exclude_unset=True)
        for key, value in update_data.items():
            setattr(stand, key, value)

        await stand.save()
        return await StandService.obtenir_stand_du_vendeur(vendeur_actuel)

    @staticmethod
    async def supprimer_stand(vendeur_actuel: Vendeur) -> dict:
        stand = await Stand.find_one(Stand.vendeur.id == vendeur_actuel.id)
        if not stand:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Aucun stand trouvé pour ce vendeur."
            )

        await stand.delete()
        return {"detail": "Stand supprimé avec succès."}

    @staticmethod
    async def verrouiller_position(phone_mac: str, vendeur_actuel: Vendeur) -> Stand:
        """
        Verrouille la position GPS (x, y) du stand depuis la trilatération live.
        La position ne sera plus recalculée tant que le vendeur ne refait pas l'opération.
        """
        from app.mqtt.mqtt_controller import phone_data, lock_phone_position

        mac = _normaliser_mac(phone_mac)
        stand = await Stand.find_one(Stand.vendeur.id == vendeur_actuel.id)
        if not stand:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Aucun stand trouvé pour ce vendeur.",
            )

        data = phone_data.get(mac)
        if not data or not data.get("position"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    "Position non disponible pour ce téléphone. "
                    "Restez immobile à votre stand, connecté au Wi-Fi des ESP32, "
                    "puis réessayez."
                ),
            )

        x, y = data["position"]
        stand.position_x = round(float(x), 2)
        stand.position_y = round(float(y), 2)
        stand.position_verrouillee = True
        stand.phone_mac = mac
        await stand.save()

        lock_phone_position(mac, (stand.position_x, stand.position_y))
        return await StandService.obtenir_stand_du_vendeur(vendeur_actuel)

    @staticmethod
    async def enregistrer_clic_notification(stand_id: str) -> dict:
        """Incrémente le compteur de clics sur notification pour un stand."""
        from beanie import PydanticObjectId

        try:
            oid = PydanticObjectId(stand_id)
        except Exception:
            raise HTTPException(status_code=404, detail="Stand introuvable.")

        stand = await Stand.get(oid)
        if not stand:
            raise HTTPException(status_code=404, detail="Stand introuvable.")

        stand.clics_notif = (stand.clics_notif or 0) + 1
        await stand.save()
        return {"detail": "Clic enregistré.", "clics_notif": stand.clics_notif}

    @staticmethod
    async def obtenir_stats_dashboard(vendeur_actuel: Vendeur) -> dict:
        """Statistiques du stand pour le dashboard vendeur."""
        from app.models.promotion import Promotion

        stand = await StandService.obtenir_stand_du_vendeur(vendeur_actuel)
        total_produits = 0
        produits_disponibles = 0

        for categorie in stand.categories or []:
            await categorie.fetch_link(Categorie.produits)
            for produit in categorie.produits or []:
                total_produits += 1
                if getattr(produit, "disponibilte", True):
                    produits_disponibles += 1

        promotions = await Promotion.find(
            Promotion.vendeur_id == vendeur_actuel.id
        ).to_list()

        return {
            "nom_stand": stand.nom_du_stand,
            "clics_notif": stand.clics_notif or 0,
            "produits_disponibles": produits_disponibles,
            "total_produits": total_produits,
            "nombre_categories": len(stand.categories or []),
            "promotions_actives": len(promotions),
            "position_verrouillee": stand.position_verrouillee,
        }

    @staticmethod
    async def obtenir_stand_par_id(stand_id: str) -> Stand:
        from beanie import PydanticObjectId

        try:
            oid = PydanticObjectId(stand_id)
        except Exception:
            raise HTTPException(status_code=404, detail="Stand introuvable.")

        stand = await Stand.get(oid)
        if not stand:
            raise HTTPException(status_code=404, detail="Stand introuvable.")
        await stand.fetch_all_links()
        return stand