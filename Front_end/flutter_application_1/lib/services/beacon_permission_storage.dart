import 'package:shared_preferences/shared_preferences.dart';

class BeaconPermissionStorage {
  BeaconPermissionStorage._();

  static const _grantedKey = 'beacon_permissions_granted';

  static Future<bool> hasGrantedPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_grantedKey) ?? false;
  }

  static Future<void> setGranted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_grantedKey, value);
  }
}
