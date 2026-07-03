import '../config/api_config.dart';
import 'api_client.dart';

class PositionService {
  PositionService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<PhonePosition>> getAllPositions() async {
    final response = await _client.get(ApiConfig.positionAll, auth: false);
    if (response.statusCode != 200) {
      throw ApiException(_client.extractError(response));
    }
    final body = _client.decodeJson(response);
    if (body is! List) return [];
    return body
        .whereType<Map<String, dynamic>>()
        .map(PhonePosition.fromJson)
        .toList();
  }

  Future<PhonePosition?> getLatestPosition({String? mac}) async {
    final response = await _client.get(
      ApiConfig.positionLatest,
      query: mac != null ? {'mac': mac} : null,
      auth: false,
    );
    if (response.statusCode != 200) {
      throw ApiException(_client.extractError(response));
    }
    final body = _client.decodeJson(response);
    if (body is! Map<String, dynamic>) return null;
    if (body['x'] == 0.0 && body['y'] == 0.0 && body['mac'] == null) {
      return null;
    }
    return PhonePosition.fromJson(body);
  }

  Future<NavigationData> getNavigation({
    required String mac,
    required String standId,
  }) async {
    final response = await _client.get(
      ApiConfig.positionNavigation,
      query: {'mac': mac, 'stand_id': standId},
      auth: false,
    );
    if (response.statusCode != 200) {
      throw ApiException(_client.extractError(response));
    }
    final body = _client.decodeJson(response);
    if (body is! Map<String, dynamic>) {
      throw ApiException('Réponse navigation invalide.');
    }
    return NavigationData.fromJson(body);
  }
}

class PhonePosition {
  PhonePosition({
    required this.mac,
    required this.x,
    required this.y,
    this.locked = false,
  });

  final String mac;
  final double x;
  final double y;
  final bool locked;

  factory PhonePosition.fromJson(Map<String, dynamic> json) {
    return PhonePosition(
      mac: json['mac']?.toString() ?? '',
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      locked: json['locked'] == true,
    );
  }
}

class NavigationData {
  NavigationData({
    required this.buyer,
    required this.stand,
    required this.path,
    required this.distanceM,
    required this.roomWidth,
    required this.roomHeight,
    required this.espPositions,
  });

  final MapPoint buyer;
  final StandPoint stand;
  final List<MapPoint> path;
  final double distanceM;
  final double roomWidth;
  final double roomHeight;
  final Map<String, MapPoint> espPositions;

  factory NavigationData.fromJson(Map<String, dynamic> json) {
    final buyerJson = json['buyer'] as Map<String, dynamic>? ?? {};
    final standJson = json['stand'] as Map<String, dynamic>? ?? {};
    final roomJson = json['room'] as Map<String, dynamic>? ?? {};
    final pathRaw = json['path'];
    final espRaw = json['esp_positions'] as Map<String, dynamic>? ?? {};

    final espMap = <String, MapPoint>{};
    for (final entry in espRaw.entries) {
      final v = entry.value;
      if (v is Map<String, dynamic>) {
        espMap[entry.key] = MapPoint.fromJson(v);
      }
    }

    return NavigationData(
      buyer: MapPoint.fromJson(buyerJson),
      stand: StandPoint.fromJson(standJson),
      path: pathRaw is List
          ? pathRaw
              .whereType<Map<String, dynamic>>()
              .map(MapPoint.fromJson)
              .toList()
          : [],
      distanceM: (json['distance_m'] as num?)?.toDouble() ?? 0,
      roomWidth: (roomJson['width'] as num?)?.toDouble() ?? 5.60,
      roomHeight: (roomJson['height'] as num?)?.toDouble() ?? 4.60,
      espPositions: espMap,
    );
  }
}

class MapPoint {
  MapPoint({required this.x, required this.y});

  final double x;
  final double y;

  factory MapPoint.fromJson(Map<String, dynamic> json) {
    return MapPoint(
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
    );
  }
}

class StandPoint {
  StandPoint({
    required this.id,
    required this.nom,
    required this.x,
    required this.y,
    required this.positionLabel,
  });

  final String id;
  final String nom;
  final double x;
  final double y;
  final String positionLabel;

  factory StandPoint.fromJson(Map<String, dynamic> json) {
    return StandPoint(
      id: json['id']?.toString() ?? '',
      nom: json['nom']?.toString() ?? '',
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      positionLabel: json['position_label']?.toString() ?? '',
    );
  }
}
