import 'dart:io';

import 'package:flutter_beacon/flutter_beacon.dart';
import 'package:permission_handler/permission_handler.dart';

/// Demande les permissions nécessaires à la détection iBeacon.
class BeaconPermissionHelper {
  static Future<bool> requestAll() async {
    if (Platform.isAndroid) {
      final results = await [
        Permission.locationWhenInUse,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.notification,
      ].request();

      final locationOk =
          results[Permission.locationWhenInUse]?.isGranted == true;
      final bluetoothOk = results[Permission.bluetoothScan]?.isGranted == true ||
          results[Permission.bluetoothConnect]?.isGranted == true;
      final notifStatus = results[Permission.notification];
      final notifOk =
          notifStatus == null || notifStatus.isGranted || notifStatus.isLimited;

      return locationOk && bluetoothOk && notifOk;
    }

    if (Platform.isIOS) {
      await flutterBeacon.setLocationAuthorizationTypeDefault(
        AuthorizationStatus.always,
      );
      await flutterBeacon.requestAuthorization;
      final status = await flutterBeacon.authorizationStatus;
      return status == AuthorizationStatus.always ||
          status == AuthorizationStatus.whenInUse ||
          status == AuthorizationStatus.allowed;
    }

    return false;
  }

  static Future<bool> hasMinimumPermissions() async {
    if (Platform.isAndroid) {
      final location = await Permission.locationWhenInUse.status;
      return location.isGranted;
    }
    final status = await flutterBeacon.authorizationStatus;
    return status == AuthorizationStatus.always ||
        status == AuthorizationStatus.whenInUse ||
        status == AuthorizationStatus.allowed;
  }
}
