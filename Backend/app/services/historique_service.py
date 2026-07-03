from app.models import HistoriqueDeRecherche


class HistoriqueService:

    @staticmethod
    async def lister_par_acheteur(acheteur_id: str) -> list[HistoriqueDeRecherche]:
        return await (
            HistoriqueDeRecherche.find(HistoriqueDeRecherche.acheteur == acheteur_id)
            .sort(-HistoriqueDeRecherche.date_recherche)
            .to_list()
        )

    @staticmethod
    async def effacer_historique(acheteur_id: str) -> int:
        historiques = await HistoriqueDeRecherche.find(
            HistoriqueDeRecherche.acheteur == acheteur_id
        ).to_list()
        count = len(historiques)
        for item in historiques:
            await item.delete()
        return count
