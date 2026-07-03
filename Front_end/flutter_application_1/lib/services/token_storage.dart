import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  TokenStorage._();

  static const _tokenKey = 'access_token';
  static const _vendeurIdKey = 'vendeur_id';
  static const _numTelephoneKey = 'num_telephone';
  static const _rememberMeKey = 'remember_me';
  static const _acheteurIdKey = 'acheteur_id';
  static const _deviceUuidKey = 'device_uuid';
  static const _userRoleKey = 'user_role';

  static String? _sessionToken;
  static String? _sessionVendeurId;
  static String? _sessionNumTelephone;
  static String? _sessionAcheteurId;
  static String? _sessionDeviceUuid;
  static String? _sessionUserRole;

  static Future<void> saveSession({
    required String accessToken,
    required String vendeurId,
    required String numTelephone,
    required bool rememberMe,
  }) async {
    _sessionToken = accessToken;
    _sessionVendeurId = vendeurId;
    _sessionNumTelephone = numTelephone;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberMeKey, rememberMe);

    if (rememberMe) {
      await prefs.setString(_tokenKey, accessToken);
      await prefs.setString(_vendeurIdKey, vendeurId);
      await prefs.setString(_numTelephoneKey, numTelephone);
    } else {
      await prefs.remove(_tokenKey);
      await prefs.remove(_vendeurIdKey);
      await prefs.remove(_numTelephoneKey);
    }
    await prefs.setString(_userRoleKey, 'vendeur');
    await prefs.remove(_acheteurIdKey);
    _sessionUserRole = 'vendeur';
    _sessionAcheteurId = null;
  }

  static Future<String?> getAccessToken() async {
    if (_sessionToken != null) return _sessionToken;

    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<String?> getVendeurId() async {
    if (_sessionVendeurId != null) return _sessionVendeurId;

    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_vendeurIdKey);
  }

  static Future<String?> getNumTelephone() async {
    if (_sessionNumTelephone != null) return _sessionNumTelephone;

    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_numTelephoneKey);
  }

  static Future<void> clearSession() async {
    _sessionToken = null;
    _sessionVendeurId = null;
    _sessionNumTelephone = null;
    _sessionAcheteurId = null;
    _sessionDeviceUuid = null;
    _sessionUserRole = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_vendeurIdKey);
    await prefs.remove(_numTelephoneKey);
    await prefs.remove(_rememberMeKey);
    await prefs.remove(_acheteurIdKey);
    await prefs.remove(_deviceUuidKey);
    await prefs.remove(_userRoleKey);
  }

  static Future<void> saveAcheteurSession({
    required String acheteurId,
    required String deviceUuid,
  }) async {
    _sessionAcheteurId = acheteurId;
    _sessionDeviceUuid = deviceUuid;
    _sessionUserRole = 'acheteur';
    _sessionToken = null;
    _sessionVendeurId = null;
    _sessionNumTelephone = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_acheteurIdKey, acheteurId);
    await prefs.setString(_deviceUuidKey, deviceUuid);
    await prefs.setString(_userRoleKey, 'acheteur');
    await prefs.remove(_tokenKey);
    await prefs.remove(_vendeurIdKey);
    await prefs.remove(_numTelephoneKey);
  }

  static Future<String?> getAcheteurId() async {
    if (_sessionAcheteurId != null) return _sessionAcheteurId;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_acheteurIdKey);
  }

  static Future<String?> getDeviceUuid() async {
    if (_sessionDeviceUuid != null) return _sessionDeviceUuid;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_deviceUuidKey);
  }

  static Future<String?> getUserRole() async {
    if (_sessionUserRole != null) return _sessionUserRole;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userRoleKey);
  }

  static Future<String> getOrCreateDeviceUuid() async {
    final existing = await getDeviceUuid();
    if (existing != null && existing.isNotEmpty) return existing;

    final generated =
        'ps-${DateTime.now().millisecondsSinceEpoch}-${DateTime.now().microsecond}';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deviceUuidKey, generated);
    _sessionDeviceUuid = generated;
    return generated;
  }
}
