import '../config/api_config.dart';
import '../models/produit_recommande.dart';
import '../models/search_history_item.dart';
import 'api_client.dart';

class ConversationContext {
  ConversationContext({
    this.requeteInitiale,
    this.derniereClarification,
  });

  final String? requeteInitiale;
  final String? derniereClarification;

  factory ConversationContext.fromJson(Map<String, dynamic> json) {
    return ConversationContext(
      requeteInitiale: json['requete_initiale']?.toString(),
      derniereClarification: json['derniere_clarification']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    if (requeteInitiale == null && derniereClarification == null) {
      return {};
    }
    return {
      if (requeteInitiale != null) 'requete_initiale': requeteInitiale,
      if (derniereClarification != null)
        'derniere_clarification': derniereClarification,
    };
  }
}

class ChatService {
  ChatService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<ChatResponse> interroger({
    required String question,
    required String userId,
    ConversationContext? contexteConversation,
  }) async {
    final payload = <String, dynamic>{
      'question': question,
      'user_id': userId,
    };
    final contexte = contexteConversation?.toJson();
    if (contexte != null && contexte.isNotEmpty) {
      payload['contexte_conversation'] = contexte;
    }

    final response = await _client.post(
      ApiConfig.chatInterroger,
      payload,
      auth: false,
      timeout: ApiClient.chatTimeout,
    );

    if (response.statusCode != 200) {
      throw ApiException(_client.extractError(response), statusCode: response.statusCode);
    }

    final body = _client.decodeJson(response);
    if (body is! Map<String, dynamic>) {
      throw ApiException('Réponse chat invalide.');
    }

    final produitsRaw = body['produits'];
    final produits = produitsRaw is List
        ? produitsRaw
            .whereType<Map<String, dynamic>>()
            .map(ProduitRecommande.fromJson)
            .toList()
        : <ProduitRecommande>[];

    final sousCategoriesRaw = body['sous_categories'];
    final sousCategories = sousCategoriesRaw is List
        ? sousCategoriesRaw.map((e) => e.toString()).toList()
        : <String>[];

    final typeReponse = body['type_reponse']?.toString() ?? 'produits';

    ConversationContext? contexteRetour;
    final contexteRaw = body['contexte_conversation'];
    if (contexteRaw is Map<String, dynamic>) {
      contexteRetour = ConversationContext.fromJson(contexteRaw);
    }

    return ChatResponse(
      reponse: body['reponse']?.toString() ?? '',
      produits: produits,
      resultatTrouve: body['resultat_trouve'] == true,
      typeReponse: typeReponse,
      sousCategories: sousCategories,
      estClarification: typeReponse == 'clarification',
      contexteConversation: contexteRetour,
    );
  }

  Future<List<SearchHistoryItem>> getHistorique(String acheteurId) async {
    final response = await _client.get(
      ApiConfig.chatHistorique(acheteurId),
      auth: false,
    );

    if (response.statusCode != 200) {
      throw ApiException(_client.extractError(response), statusCode: response.statusCode);
    }

    final body = _client.decodeJson(response);
    if (body is! List) return [];

    return body
        .whereType<Map<String, dynamic>>()
        .map(SearchHistoryItem.fromJson)
        .toList();
  }

  Future<void> effacerHistorique(String acheteurId) async {
    final response = await _client.delete(
      ApiConfig.chatEffacerHistorique(acheteurId),
      auth: false,
    );

    if (response.statusCode != 200) {
      throw ApiException(_client.extractError(response), statusCode: response.statusCode);
    }
  }

  Future<List<ProduitRecommande>> getRecommandations(String acheteurId) async {
    final response = await _client.get(
      ApiConfig.produitsRecommandations(acheteurId),
      auth: false,
    );

    if (response.statusCode != 200) {
      throw ApiException(_client.extractError(response), statusCode: response.statusCode);
    }

    final body = _client.decodeJson(response);
    if (body is! List) return [];

    return body
        .whereType<Map<String, dynamic>>()
        .map(ProduitRecommande.fromJson)
        .toList();
  }

  Future<List<ProduitRecommande>> getProduitsAleatoires() async {
    final response = await _client.get(
      ApiConfig.produitsAleatoires,
      auth: false,
    );

    if (response.statusCode != 200) {
      throw ApiException(_client.extractError(response), statusCode: response.statusCode);
    }

    final body = _client.decodeJson(response);
    if (body is! List) return [];

    return body
        .whereType<Map<String, dynamic>>()
        .map(ProduitRecommande.fromJson)
        .toList();
  }
}

class ChatResponse {
  ChatResponse({
    required this.reponse,
    required this.produits,
    required this.resultatTrouve,
    this.typeReponse = 'produits',
    this.sousCategories = const [],
    this.estClarification = false,
    this.contexteConversation,
  });

  final String reponse;
  final List<ProduitRecommande> produits;
  final bool resultatTrouve;
  final String typeReponse;
  final List<String> sousCategories;
  final bool estClarification;
  final ConversationContext? contexteConversation;
}
