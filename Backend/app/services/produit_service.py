import logging
import random
from bson import ObjectId
from fastapi import HTTPException, status
from beanie import PydanticObjectId
from app.models.produits import Produit
from app.models.categories import Categorie
from app.models.promotion import Promotion
from app.models.stand import Stand
from app.models.vendeur import Vendeur
from app.schemas.produit import ProduitsCreate, ProduitsUpdate, ProduitsResponse
from app.schemas.promotion import PromotionResponse
from app.services.rag_service import RAGService
from app.services.stand_service import StandService

logger = logging.getLogger(__name__)

class ProduitService:

    @staticmethod
    async def verifier_permission_produit(categorie_id: PydanticObjectId, vendeur_actuel: Vendeur):
        """Vérifie si la catégorie appartient à un stand possédé par le vendeur connecté."""
        stand = await StandService.trouver_par_categorie(categorie_id)
        if not stand:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="La catégorie associée est introuvable."
            )

        await stand.fetch_link(Stand.vendeur)
        if stand.vendeur.id != vendeur_actuel.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Vous n'avez pas l'autorisation de modifier cette catégorie."
            )
        return stand

    @staticmethod
    async def _promotions_to_response(produit: Produit) -> list[PromotionResponse]:
        promos: list[PromotionResponse] = []
        for item in produit.promotions or []:
            if not isinstance(item, Promotion):
                continue
            promos.append(PromotionResponse(
                id=item.id,
                titre=item.titre,
                description=item.description,
            ))
        return promos

    @staticmethod
    async def _to_response(produit: Produit) -> ProduitsResponse:
        return ProduitsResponse(
            id=produit.id,
            nom=produit.nom,
            description=produit.description,
            prix=produit.prix,
            disponibilte=produit.disponibilte,
            photo_url=produit.photo_url,
            categorie_id=produit.categorie_id,
            promotions=await ProduitService._promotions_to_response(produit),
        )

    @staticmethod
    async def creer_produit(donnees: ProduitsCreate, vendeur_actuel: Vendeur) -> ProduitsResponse:
        # 1. Vérification de sécurité
        await ProduitService.verifier_permission_produit(donnees.categorie_id, vendeur_actuel)
        
        # 2. Création du produit
        nouveau_produit = Produit(
            nom=donnees.nom,
            description=donnees.description,
            prix=donnees.prix,
            disponibilte=donnees.disponibilte,
            photo_url=donnees.photo_url,
            categorie_id=donnees.categorie_id,
        )
        await nouveau_produit.insert()
        
        # 3. Ajouter le produit à la liste de la catégorie
        categorie = await Categorie.get(donnees.categorie_id)
        if categorie:
            if categorie.produits is None:
                categorie.produits = []
            categorie.produits.append(nouveau_produit)
            await categorie.save()

        try:
            await RAGService.synchroniser_produit(nouveau_produit)
        except Exception as exc:
            logger.warning("Sync RAG ignorée pour le produit %s : %s", nouveau_produit.id, exc)

        await ProduitService._enrichir_produit(nouveau_produit)
        return await ProduitService._to_response(nouveau_produit)

    @staticmethod
    async def modifier_produit(produit_id: PydanticObjectId, donnees: ProduitsUpdate, vendeur_actuel: Vendeur) -> ProduitsResponse:
        # 1. Trouver la catégorie contenant ce produit pour vérifier les droits
        categorie = await Categorie.find_one(Categorie.produits.id == produit_id)
        if not categorie:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, 
                detail="Produit introuvable dans vos catégories."
            )
            
        # 2. Vérifier que le vendeur est bien le propriétaire
        await ProduitService.verifier_permission_produit(categorie.id, vendeur_actuel)
        
        # 3. Appliquer la modification
        produit = await Produit.get(produit_id)
        if not produit:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Produit introuvable.")
            
        update_data = donnees.model_dump(exclude_unset=True)
        for key, value in update_data.items():
            setattr(produit, key, value)
            
        await produit.save()
        try:
            await RAGService.synchroniser_produit(produit)
        except Exception as exc:
            logger.warning("Sync RAG ignorée pour le produit %s : %s", produit.id, exc)
        await ProduitService._enrichir_produit(produit)
        return await ProduitService._to_response(produit)

    @staticmethod
    async def supprimer_produit(produit_id: PydanticObjectId, vendeur_actuel: Vendeur):
        # 1. Trouver la catégorie
        categorie = await Categorie.find_one(Categorie.produits.id == produit_id)
        if not categorie:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, 
                detail="Produit introuvable."
            )
            
        # 2. Vérification de sécurité
        await ProduitService.verifier_permission_produit(categorie.id, vendeur_actuel)
        
        # 3. Retirer le produit de la liste de la catégorie (Sécurité DBRef)
        if categorie.produits:
            categorie.produits = [
                p for p in categorie.produits 
                if (p.id if hasattr(p, "id") else p.ref.id) != produit_id
            ]
            await categorie.save()
        
        # 4. Supprimer le document Produit de la base de données
        produit = await Produit.get(produit_id)
        if produit:
            await produit.delete()
            RAGService.supprimer_produit_index(str(produit_id))
            
        return {"detail": "Produit supprimé avec succès."}

    @staticmethod
    async def _enrichir_produit(produit: Produit) -> Produit:
        if produit.promotions:
            await produit.fetch_link(Produit.promotions)
        return produit

    @staticmethod
    async def lister_produits_par_categorie(
        categorie_id: PydanticObjectId,
        vendeur_actuel: Vendeur
    ) -> list[ProduitsResponse]:
        await ProduitService.verifier_permission_produit(categorie_id, vendeur_actuel)
        categorie = await Categorie.get(categorie_id)
        if not categorie:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Catégorie introuvable."
            )

        await categorie.fetch_link(Categorie.produits)
        resultats: list[ProduitsResponse] = []
        for produit in categorie.produits or []:
            if hasattr(produit, "fetch_link"):
                await produit.fetch_link(Produit.promotions)
            resultats.append(await ProduitService._to_response(produit))
        return resultats

    @staticmethod
    async def rechercher_produits(query: str) -> list[Produit]:
        terme = query.strip()
        if not terme:
            return []

        regex = {"$regex": terme, "$options": "i"}
        produits = await Produit.find(
            {"$or": [{"nom": regex}, {"description": regex}]}
        ).to_list()

        for produit in produits:
            await ProduitService._enrichir_produit(produit)
        return produits

    @staticmethod
    async def _produit_vers_recommandation(produit: Produit) -> dict:
        nom_categorie = "Général"
        nom_stand = "Stand partenaire"
        stand_id = None
        position_x = None
        position_y = None
        position_verrouillee = False

        if produit.categorie_id:
            categorie = await Categorie.get(produit.categorie_id)
            if categorie:
                nom_categorie = categorie.nom
            stand = await Stand.find_one({
                "$or": [
                    {"categories.$id": produit.categorie_id},
                    {"categories": produit.categorie_id},
                ]
            })
            if stand:
                nom_stand = stand.nom_du_stand
                stand_id = str(stand.id)
                position_x = stand.position_x
                position_y = stand.position_y
                position_verrouillee = bool(stand.position_verrouillee)

        return {
            "id": str(produit.id),
            "nom": produit.nom,
            "description": produit.description,
            "prix": produit.prix,
            "photo_url": produit.photo_url,
            "nom_stand": nom_stand,
            "nom_categorie": nom_categorie,
            "stand_id": stand_id,
            "position_x": position_x,
            "position_y": position_y,
            "position_verrouillee": position_verrouillee,
        }

    @staticmethod
    async def produits_aleatoires(limit: int | None = None) -> list[dict]:
        """Retourne 2 à 3 produits choisis aléatoirement pour l'accueil du bot."""
        tous = await Produit.find_all().to_list()
        if not tous:
            return []

        count = limit if limit is not None else random.randint(2, 3)
        count = min(count, len(tous))
        selection = random.sample(tous, count)

        return [await ProduitService._produit_vers_recommandation(p) for p in selection]

    @staticmethod
    async def recommander_produits(acheteur_id: str, limit: int = 10) -> list[dict]:
        """Recommandations de produits de la même catégorie que l'historique de recherche."""
        from app.models import HistoriqueDeRecherche

        historiques = await (
            HistoriqueDeRecherche.find(HistoriqueDeRecherche.acheteur == acheteur_id)
            .sort(-HistoriqueDeRecherche.date_recherche)
            .limit(10)
            .to_list()
        )

        categorie_ids: set[PydanticObjectId] = set()
        produits_ids_vus: set[str] = set()

        for hist in historiques:
            if hist.produit:
                try:
                    produit_hist = await Produit.get(ObjectId(hist.produit))
                except Exception:
                    produit_hist = None
                if produit_hist:
                    produits_ids_vus.add(str(produit_hist.id))
                    if produit_hist.categorie_id:
                        categorie_ids.add(produit_hist.categorie_id)

            termes = hist.requete.strip()
            if termes:
                produits_trouves, _ = await RAGService.rechercher_produits(termes, n_results=3)
                for p in produits_trouves:
                    produits_ids_vus.add(p["id"])
                    produit = await Produit.get(ObjectId(p["id"]))
                    if produit and produit.categorie_id:
                        categorie_ids.add(produit.categorie_id)

        recommandations: list[dict] = []
        categories_shuffled = list(categorie_ids)
        random.shuffle(categories_shuffled)

        for categorie_id in categories_shuffled:
            produits_meme_categorie = await Produit.find(
                Produit.categorie_id == categorie_id
            ).to_list()

            candidats = [
                p for p in produits_meme_categorie
                if str(p.id) not in produits_ids_vus
            ]
            random.shuffle(candidats)

            for produit in candidats:
                pid = str(produit.id)
                produits_ids_vus.add(pid)
                recommandations.append(
                    await ProduitService._produit_vers_recommandation(produit)
                )
                if len(recommandations) >= limit:
                    return recommandations

        if len(recommandations) < limit:
            restants = await Produit.find_all().to_list()
            random.shuffle(restants)
            for produit in restants:
                pid = str(produit.id)
                if pid in produits_ids_vus:
                    continue
                produits_ids_vus.add(pid)
                recommandations.append(
                    await ProduitService._produit_vers_recommandation(produit)
                )
                if len(recommandations) >= limit:
                    break

        return recommandations