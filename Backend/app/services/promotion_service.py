from fastapi import HTTPException, status
from beanie import PydanticObjectId
from typing import List
from app.models.promotion import Promotion
from app.models.produits import Produit
from app.models.stand import Stand
from app.models.vendeur import Vendeur
from app.schemas.promotion import PromotionCreate, PromotionUpdate
from app.models.ibeacon import IBeacon
from app.core.ibeacon_uuid import variantes_uuid
from beanie.operators import In

class PromotionService:

    @staticmethod
    async def verifier_produits_vendeur(produits_ids: List[PydanticObjectId], vendeur_actuel: Vendeur) -> List[Produit]:
        """Vérifie que chaque produit d'une liste appartient bien au vendeur connecté."""
        produits_valides = []
        for pid in produits_ids:
            produit = await Produit.get(pid)
            if not produit:
                raise HTTPException(status_code=404, detail=f"Produit {pid} introuvable.")
            
            stand = await Stand.find_one(Stand.categories.id == produit.categorie_id)
            if not stand:
                raise HTTPException(status_code=404, detail=f"Stand introuvable pour le produit {pid}.")
                
            await stand.fetch_link(Stand.vendeur)
            if stand.vendeur.id != vendeur_actuel.id:
                raise HTTPException(status_code=403, detail="Non autorisé sur un des produits.")
                
            produits_valides.append(produit)
        return produits_valides

    @staticmethod
    async def creer_promotion(donnees: PromotionCreate, vendeur_actuel: Vendeur) -> Promotion:
        # 1. Vérifier tous les produits ciblés
        produits = await PromotionService.verifier_produits_vendeur(donnees.produits_ids, vendeur_actuel)
        
        # 2. Créer la promotion
        nouvelle_promo = Promotion(
            titre=donnees.titre,
            description=donnees.description,
            vendeur_id=vendeur_actuel.id,
            produits_ids=donnees.produits_ids
        )
        await nouvelle_promo.insert()
        
        # 3. Ajouter la promo dans la liste de chaque produit
        for produit in produits:
            if produit.promotions is None:
                produit.promotions = []
            produit.promotions.append(nouvelle_promo)
            await produit.save()
            
        return nouvelle_promo

    @staticmethod
    async def modifier_promotion(promotion_id: PydanticObjectId, donnees: PromotionUpdate, vendeur_actuel: Vendeur) -> Promotion:
        # 1. Vérification directe grâce au vendeur_id
        promotion = await Promotion.find_one(Promotion.id == promotion_id, Promotion.vendeur_id == vendeur_actuel.id)
        if not promotion:
            raise HTTPException(status_code=404, detail="Promotion introuvable ou non autorisée.")

        # 2. Si on modifie la liste des produits concernés
        if donnees.produits_ids is not None:
            nouveaux_produits = await PromotionService.verifier_produits_vendeur(donnees.produits_ids, vendeur_actuel)
            
            # Retirer la promotion des *anciens* produits (Sécurité DBRef via produits_ids)
            for pid in promotion.produits_ids:
                if pid not in donnees.produits_ids:
                    p = await Produit.get(pid)
                    if p and p.promotions:
                        p.promotions = [
                            promo for promo in p.promotions 
                            if (promo.id if hasattr(promo, "id") else promo.ref.id) != promotion.id
                        ]
                        await p.save()

            # Ajouter la promotion aux *nouveaux* produits
            for p in nouveaux_produits:
                if p.promotions is None: 
                    p.promotions = []
                # Éviter les doublons de DBRef
                deja_present = any(
                    (promo.id if hasattr(promo, "id") else promo.ref.id) == promotion.id 
                    for promo in p.promotions
                )
                if not deja_present:
                    p.promotions.append(promotion)
                    await p.save()

            promotion.produits_ids = donnees.produits_ids

        # 3. Mise à jour des textes
        if donnees.titre is not None: promotion.titre = donnees.titre
        if donnees.description is not None: promotion.description = donnees.description
        await promotion.save()
        return promotion

    @staticmethod
    async def supprimer_promotion(promotion_id: PydanticObjectId, vendeur_actuel: Vendeur):
        promotion = await Promotion.find_one(Promotion.id == promotion_id, Promotion.vendeur_id == vendeur_actuel.id)
        if not promotion:
            raise HTTPException(status_code=404, detail="Promotion introuvable ou non autorisée.")

        # Retirer cette promotion des produits (Sécurité DBRef via produits_ids)
        for pid in promotion.produits_ids:
            produit = await Produit.get(pid)
            if produit and produit.promotions:
                produit.promotions = [
                    promo for promo in produit.promotions 
                    if (promo.id if hasattr(promo, "id") else promo.ref.id) != promotion.id
                ]
                await produit.save()

        # Supprimer définitivement la promotion
        await promotion.delete()
        
        return {"detail": "Promotion supprimée et retirée de tous les produits."}
    

    @staticmethod
    async def obtenir_promotions_par_ibeacon(uuid: str, major: int, minor: int):
        """
        Fonction appelée par le téléphone du client quand il détecte un iBeacon.
        Retourne toutes les promotions actives du vendeur propriétaire du beacon.
        """
        # 1. Identifier à qui appartient l'iBeacon actif
        # Casse + ordre d'octets : le téléphone peut envoyer un UUID différent de celui en base.
        ibeacon = await IBeacon.find_one(
            In(IBeacon.uuid, variantes_uuid(uuid)),
            IBeacon.major == major,
            IBeacon.minor == minor,
            IBeacon.activite == True,
        )
        
        if not ibeacon:
            raise HTTPException(status_code=404, detail="iBeacon inconnu ou inactif.")

        # 2. Récupérer toutes les promotions du vendeur qui possède ce iBeacon
        promotions = await Promotion.find(Promotion.vendeur_id == ibeacon.vendeur_id).to_list()
        
        # 3. Récupérer les infos du stand pour affichage client
        stand = await Stand.find_one(Stand.vendeur.id == ibeacon.vendeur_id)
        nom_stand = stand.nom_du_stand if stand else "Stand inconnu"
        
        if not promotions:
            return {
                "message": f"Bienvenue chez {nom_stand} ! Aucune promotion en cours.", 
                "nom_stand": nom_stand,
                "promotions": []
            }

        # 4. Retourner les informations structurées au téléphone du client
        return {
            "vendeur_id": str(ibeacon.vendeur_id),
            "nom_stand": nom_stand,
            "promotions": [
                {
                    "id": str(p.id),
                    "titre": p.titre,
                    "description": p.description,
                }
                for p in promotions
            ],
        }

    @staticmethod
    async def lister_promotions_vendeur(vendeur_actuel: Vendeur) -> list[Promotion]:
        return await Promotion.find(Promotion.vendeur_id == vendeur_actuel.id).to_list()