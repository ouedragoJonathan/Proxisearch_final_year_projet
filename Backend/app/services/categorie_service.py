import traceback
from fastapi import HTTPException, status
from beanie import PydanticObjectId
from app.models.categories import Categorie
from app.models.stand import Stand
from app.models.vendeur import Vendeur
from app.schemas.categorie import CategorieCreate, CategorieUpdate, CategorieResponse

class CategorieService:

    @staticmethod
    def _to_response(categorie: Categorie) -> CategorieResponse:
        return CategorieResponse(
            id=categorie.id,
            nom=categorie.nom,
            description=categorie.description,
            icone_url=categorie.icone_url,
            produits=[],
        )

    @staticmethod
    async def creer_categorie(donnees: CategorieCreate, vendeur_actuel: Vendeur) -> CategorieResponse:
        try:
            # 1. Trouver le stand du vendeur connecté
            stand = await Stand.find_one(Stand.vendeur.id == vendeur_actuel.id)
            if not stand:
                raise HTTPException(status_code=404, detail="Stand introuvable. Veuillez d'abord créer un stand.")

            # 2. Créer la catégorie
            nouvelle_categorie = Categorie(
                nom=donnees.nom,
                description=donnees.description,
                icone_url=donnees.icone_url
            )
            await nouvelle_categorie.insert()

            # 3. L'ajouter au stand
            if stand.categories is None:
                stand.categories = []
                
            stand.categories.append(nouvelle_categorie)
            await stand.save()

            return CategorieService._to_response(nouvelle_categorie)

        except HTTPException as he:
            raise he
        except Exception as e:
            print("!!! ERREUR 500 DANS CREER_CATEGORIE !!!")
            traceback.print_exc()
            raise HTTPException(status_code=500, detail="Erreur interne. Regardez le terminal.")

    @staticmethod
    async def modifier_categorie(categorie_id: PydanticObjectId, donnees: CategorieUpdate, vendeur_actuel: Vendeur) -> CategorieResponse:
        try:
            # 1. Trouver le stand du vendeur
            stand = await Stand.find_one(Stand.vendeur.id == vendeur_actuel.id)
            if not stand:
                raise HTTPException(status_code=404, detail="Stand introuvable.")
            
            # 2. Sécurité : vérifier que la catégorie est dans ce stand
            await stand.fetch_link(Stand.categories)
            appartient_au_stand = any(
                (c.id if hasattr(c, "id") else c.ref.id) == categorie_id 
                for c in stand.categories
            ) if stand.categories else False
            
            if not appartient_au_stand:
                raise HTTPException(status_code=403, detail="Non autorisé à modifier cette catégorie.")

            # 3. Trouver la catégorie
            categorie = await Categorie.get(categorie_id)
            if not categorie:
                raise HTTPException(status_code=404, detail="Catégorie introuvable.")
            
            # 4. Mise à jour
            update_data = donnees.model_dump(exclude_unset=True)
            for key, value in update_data.items():
                setattr(categorie, key, value)
                
            await categorie.save()
            return CategorieService._to_response(categorie)

        except HTTPException as he:
            raise he
        except Exception as e:
            print("!!! ERREUR 500 DANS MODIFIER_CATEGORIE !!!")
            traceback.print_exc()
            raise HTTPException(status_code=500, detail="Erreur interne. Regardez le terminal.")

    @staticmethod
    async def supprimer_categorie(categorie_id: PydanticObjectId, vendeur_actuel: Vendeur):
        try:
            # 1. Trouver le stand du vendeur
            stand = await Stand.find_one(Stand.vendeur.id == vendeur_actuel.id)
            if not stand:
                raise HTTPException(status_code=404, detail="Stand introuvable.")
                
            # 2. Sécurité
            await stand.fetch_link(Stand.categories)
            appartient_au_stand = any(
                (c.id if hasattr(c, "id") else c.ref.id) == categorie_id 
                for c in stand.categories
            ) if stand.categories else False
            
            if not appartient_au_stand:
                raise HTTPException(status_code=403, detail="Non autorisé à supprimer cette catégorie.")

            # 3. Retirer de la liste du stand (Sécurité DBRef)
            if stand.categories:
                stand.categories = [
                    c for c in stand.categories 
                    if (c.id if hasattr(c, "id") else c.ref.id) != categorie_id
                ]
                await stand.save()
            
            # 4. Supprimer de la base de données
            categorie = await Categorie.get(categorie_id)
            if categorie:
                await categorie.delete()
            
            return {"detail": "Catégorie supprimée avec succès."}

        except HTTPException as he:
            raise he
        except Exception as e:
            print("!!! ERREUR 500 DANS SUPPRIMER_CATEGORIE !!!")
            traceback.print_exc()
            raise HTTPException(status_code=500, detail="Erreur interne. Regardez le terminal.")