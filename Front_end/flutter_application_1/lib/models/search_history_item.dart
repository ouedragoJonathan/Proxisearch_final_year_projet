class SearchHistoryItem {
  SearchHistoryItem({
    required this.id,
    required this.requete,
    required this.dateRecherche,
    required this.resultatTrouve,
    this.reponseIa,
  });

  final String id;
  final String requete;
  final DateTime dateRecherche;
  final bool resultatTrouve;
  final String? reponseIa;

  factory SearchHistoryItem.fromJson(Map<String, dynamic> json) {
    return SearchHistoryItem(
      id: json['id']?.toString() ?? '',
      requete: json['requete']?.toString() ?? '',
      reponseIa: json['reponse_ia']?.toString(),
      dateRecherche: DateTime.tryParse(json['date_recherche']?.toString() ?? '') ??
          DateTime.now(),
      resultatTrouve: json['resultat_trouve'] == true,
    );
  }

  String get formattedDate {
    final now = DateTime.now();
    final local = dateRecherche.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final itemDay = DateTime(local.year, local.month, local.day);
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';

    if (itemDay == today) {
      return 'Aujourd\'hui, $time';
    }
    if (itemDay == today.subtract(const Duration(days: 1))) {
      return 'Hier, $time';
    }
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}, $time';
  }
}
