import 'dart:async';
import 'dart:io';

import 'package:flutter_beacon/flutter_beacon.dart';

import 'beacon_permission_helper.dart';
import 'beacon_permission_storage.dart';

class ScannedBeaconInfo {
  const ScannedBeaconInfo({
    required this.uuid,
    required this.major,
    required this.minor,
    required this.rssi,
  });

  final String uuid;
  final int major;
  final int minor;
  final int rssi;

  String get label =>
      'UUID ${uuid.substring(0, 8)}… · Major $major · Minor $minor · $rssi dBm';
}

class BeaconScanService {
  static const _scanDuration = Duration(seconds: 8);

  static Future<List<ScannedBeaconInfo>> scanNearbyBeacons() async {
    if (!Platform.isAndroid) {
      throw UnsupportedError(
        'Le scan iBeacon vendeur est disponible sur Android uniquement.',
      );
    }

    final permitted = await BeaconPermissionHelper.requestAll();
    if (!permitted) {
      throw Exception(
        'Activez Bluetooth, localisation et notifications pour scanner.',
      );
    }
    await BeaconPermissionStorage.setGranted(true);

    final ready = await flutterBeacon.initializeAndCheckScanning;
    if (!ready) {
      throw Exception('Activez le Bluetooth et la localisation.');
    }

    final region = Region(identifier: 'seller-beacon-scan');
    final beacons = <String, ScannedBeaconInfo>{};
    StreamSubscription<RangingResult>? subscription;

    subscription = flutterBeacon.ranging([region]).listen((result) {
      for (final beacon in result.beacons) {
        final key = '${beacon.proximityUUID}|${beacon.major}|${beacon.minor}';
        beacons[key] = ScannedBeaconInfo(
          uuid: beacon.proximityUUID.toUpperCase(),
          major: beacon.major,
          minor: beacon.minor,
          rssi: beacon.rssi,
        );
      }
    });

    await Future<void>.delayed(_scanDuration);
    await subscription.cancel();
    await flutterBeacon.close;

    final list = beacons.values.toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
    return list;
  }
}
