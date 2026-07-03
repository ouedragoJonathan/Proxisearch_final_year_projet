import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_beacon/flutter_beacon.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/beacon_config.dart';
import '../models/beacon_promo_response.dart';
import 'beacon_permission_storage.dart';
import 'notification_service.dart';
import 'proximity_service.dart';

class BeaconProximityService {
  BeaconProximityService._();

  static final BeaconProximityService instance = BeaconProximityService._();
  static final _random = Random();

  final _proximityService = ProximityService();
  final _region = Region(identifier: BeaconConfig.regionIdentifier);

  StreamSubscription<MonitoringResult>? _monitoringSub;
  StreamSubscription<RangingResult>? _rangingSub;
  Timer? _rangingTimer;
  Timer? _periodicScanTimer;
  bool _started = false;
  bool _isRanging = false;
  bool _processingBeacon = false;

  Future<void> start() async {
    if (_started) return;
    if (!await BeaconPermissionStorage.hasGrantedPermissions()) return;

    try {
      final ready = await flutterBeacon.initializeAndCheckScanning;
      if (!ready) {
        debugPrint('[Beacon] initializeAndCheckScanning a échoué');
        return;
      }

      _monitoringSub?.cancel();
      _monitoringSub = flutterBeacon.monitoring([_region]).listen(
        _onMonitoring,
        onError: (Object e) => debugPrint('[Beacon] monitoring error: $e'),
      );

      _periodicScanTimer?.cancel();
      _periodicScanTimer = Timer.periodic(
        const Duration(seconds: BeaconConfig.periodicRescanSeconds),
        (_) {
          if (!_isRanging) _startActiveScan();
        },
      );

      _started = true;
      debugPrint('[Beacon] Surveillance iBeacon active (tous UUID)');
      _startActiveScan();
    } catch (e) {
      debugPrint('[Beacon] start failed: $e');
    }
  }

  Future<void> stop() async {
    _periodicScanTimer?.cancel();
    _periodicScanTimer = null;
    await _stopRanging();
    await _monitoringSub?.cancel();
    _monitoringSub = null;
    _started = false;
  }

  void _onMonitoring(MonitoringResult result) {
    final isEnter = result.monitoringEventType == MonitoringEventType.didEnterRegion;
    final isInside = result.monitoringEventType ==
            MonitoringEventType.didDetermineStateForRegion &&
        result.monitoringState == MonitoringState.inside;

    if (isEnter || isInside) {
      _startActiveScan();
    }
  }

  void _startActiveScan() {
    if (_isRanging) return;
    _isRanging = true;

    _rangingSub?.cancel();
    _rangingSub = flutterBeacon.ranging([_region]).listen(
      _onRanging,
      onError: (Object e) => debugPrint('[Beacon] ranging error: $e'),
    );

    _rangingTimer?.cancel();
    _rangingTimer = Timer(
      const Duration(seconds: BeaconConfig.activeScanSeconds),
      () {
        unawaited(_stopRanging());
      },
    );

    debugPrint('[Beacon] Scan actif démarré (${BeaconConfig.activeScanSeconds}s)');
  }

  Future<void> _stopRanging() async {
    _rangingTimer?.cancel();
    _rangingTimer = null;
    await _rangingSub?.cancel();
    _rangingSub = null;
    _isRanging = false;
    debugPrint('[Beacon] Scan actif arrêté');
  }

  Future<void> _onRanging(RangingResult result) async {
    if (_processingBeacon || result.beacons.isEmpty) return;

    final beacon = _pickClosestBeacon(result.beacons);
    if (beacon == null) return;

    _processingBeacon = true;
    try {
      await _handleDetectedBeacon(beacon);
    } finally {
      _processingBeacon = false;
    }
  }

  Beacon? _pickClosestBeacon(List<Beacon> beacons) {
    if (beacons.isEmpty) return null;
    beacons.sort((a, b) => b.rssi.compareTo(a.rssi));
    return beacons.first;
  }

  Future<void> _handleDetectedBeacon(Beacon beacon) async {
    final uuid = _normalizeUuid(beacon.proximityUUID);
    final cacheKey = 'beacon_notif_${beacon.major}_${beacon.minor}';

    if (await _isInCooldown(cacheKey)) {
      debugPrint('[Beacon] Cooldown actif pour $cacheKey');
      return;
    }

    debugPrint(
      '[Beacon] Détecté major=${beacon.major} minor=${beacon.minor} rssi=${beacon.rssi}',
    );

    try {
      BeaconPromoResponse? response;
      for (final candidate in _uuidLookupCandidates(uuid)) {
        response = await _proximityService.detecterPromotions(
          uuid: candidate,
          major: beacon.major,
          minor: beacon.minor,
        );
        if (response != null) break;
      }

      if (response == null) {
        debugPrint('[Beacon] Aucune promo trouvée pour ce beacon');
        return;
      }

      if (!response.hasActivePromo) {
        debugPrint('[Beacon] Stand ${response.nomStand} sans promo active');
        return;
      }

      final promo = response.promotions[
          _random.nextInt(response.promotions.length)];
      final body = _buildNotificationBody(promo.titre, promo.description);

      final shown = await NotificationService.instance.showPromoNotification(
        title: 'PROMO À PROXIMITÉ • ${response.nomStand}',
        body: body,
      );

      if (shown) {
        await _setCooldown(cacheKey);
        debugPrint('[Beacon] Promo aléatoire notifiée: ${promo.titre}');
      }
    } catch (e) {
      debugPrint('[Beacon] API promo error: $e');
    }
  }

  String _buildNotificationBody(String titre, String? description) {
    if (description != null && description.trim().isNotEmpty) {
      return '$titre : $description ! Appuyez pour découvrir l\'offre.';
    }
    return '$titre ! Appuyez pour découvrir l\'offre.';
  }

  String _normalizeUuid(String uuid) {
    return uuid.trim().toLowerCase();
  }

  List<String> _uuidLookupCandidates(String uuid) {
    final normalized = _normalizeUuid(uuid);
    final candidates = <String>{normalized, normalized.toUpperCase()};

    final canonical = BeaconConfig.marketUuid.toLowerCase();
    const reversed = '0bfcdcdd-08b7-4759-ba88-4d44b5a5bdf6';
    if (normalized == canonical) candidates.add(reversed);
    if (normalized == reversed) candidates.add(canonical);

    final parts = normalized.replaceAll('-', '');
    if (parts.length == 32) {
      final bytes = List<int>.generate(
        16,
        (i) => int.parse(parts.substring(i * 2, i * 2 + 2), radix: 16),
      );
      final reversedBytes = bytes.reversed
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      final reversedUuid =
          '${reversedBytes.substring(0, 8)}-${reversedBytes.substring(8, 12)}-'
          '${reversedBytes.substring(12, 16)}-${reversedBytes.substring(16, 20)}-'
          '${reversedBytes.substring(20)}';
      candidates.add(reversedUuid);
      candidates.add(reversedUuid.toUpperCase());
    }

    return candidates.toList();
  }

  Future<bool> _isInCooldown(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt(key);
    if (lastMs == null) return false;
    final elapsed = DateTime.now().millisecondsSinceEpoch - lastMs;
    return elapsed <
        BeaconConfig.notificationCooldownMinutes * 60 * 1000;
  }

  Future<void> _setCooldown(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, DateTime.now().millisecondsSinceEpoch);
  }
}
