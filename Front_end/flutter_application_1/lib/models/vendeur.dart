// Modèles alignés sur Backend/app/models/vendeur.py et app/schemas/vendeur.py

class Vendeur {
  const Vendeur({
    required this.id,
    required this.numTelephone,
  });

  final String id;
  final String numTelephone;

  factory Vendeur.fromJson(Map<String, dynamic> json) {
    return Vendeur(
      id: json['id']?.toString() ?? '',
      numTelephone: json['num_telephone'] as String,
    );
  }
}

/// Schéma VendeurCreate — corps de POST /vendeurs/inscription
class VendeurCreate {
  const VendeurCreate({
    required this.numTelephone,
    required this.motDePasse,
  });

  final String numTelephone;
  final String motDePasse;

  Map<String, dynamic> toJson() => {
        'num_telephone': numTelephone,
        'mot_de_passe': motDePasse,
      };
}

/// Schéma VendeurLogin — corps de POST /vendeurs/connexion
class VendeurLogin {
  const VendeurLogin({
    required this.numTelephone,
    required this.motDePasse,
  });

  final String numTelephone;
  final String motDePasse;

  Map<String, dynamic> toJson() => {
        'num_telephone': numTelephone,
        'mot_de_passe': motDePasse,
      };
}

/// Schéma VendeurConnexionResponse — réponse de POST /vendeurs/connexion
class VendeurConnexionResponse {
  const VendeurConnexionResponse({
    required this.accessToken,
    required this.tokenType,
    required this.vendeurId,
  });

  final String accessToken;
  final String tokenType;
  final String vendeurId;

  factory VendeurConnexionResponse.fromJson(Map<String, dynamic> json) {
    return VendeurConnexionResponse(
      accessToken: json['access_token'] as String,
      tokenType: json['token_type'] as String? ?? 'bearer',
      vendeurId: json['vendeur_id'] as String,
    );
  }
}
