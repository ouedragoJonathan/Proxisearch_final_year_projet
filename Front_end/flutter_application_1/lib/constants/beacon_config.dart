/// UUID du marché diffusé par les ESP32 iBeacon ProxiSearch.
/// Doit correspondre à l'UUID enregistré côté vendeur dans le backend.
class BeaconConfig {
  BeaconConfig._();

  static const marketUuid = '7c09ada1-4db9-48b5-b520-107dfffe9b10';
  static const regionIdentifier = 'proxisearch-market';

  /// Durée du scan actif (major/minor) après détection de zone.
  static const activeScanSeconds = 12;

  /// Relance un scan périodique tant que l'app tourne (secours si la 1re passe rate).
  static const periodicRescanSeconds = 30;

  /// Délai minimum entre deux notifications pour le même stand.
  static const notificationCooldownMinutes = 1;
}
