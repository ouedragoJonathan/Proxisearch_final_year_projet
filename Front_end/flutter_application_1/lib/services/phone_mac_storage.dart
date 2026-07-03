import 'package:shared_preferences/shared_preferences.dart';

/// Stocke la MAC Wi-Fi sélectionnée pour la navigation acheteur.
class PhoneMacStorage {
  static const _key = 'buyer_phone_mac';

  static Future<String?> getMac() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  static Future<void> saveMac(String mac) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mac.trim().toUpperCase());
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
