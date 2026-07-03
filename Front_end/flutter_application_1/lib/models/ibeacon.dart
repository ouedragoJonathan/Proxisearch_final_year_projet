class IBeacon {
  IBeacon({
    required this.id,
    required this.uuid,
    required this.major,
    required this.minor,
    required this.rssiSeuil,
    required this.activite,
    required this.vendeurId,
  });

  final String id;
  final String uuid;
  final int major;
  final int minor;
  final int rssiSeuil;
  final bool activite;
  final String vendeurId;

  factory IBeacon.fromJson(Map<String, dynamic> json) {
    return IBeacon(
      id: json['id']?.toString() ?? '',
      uuid: json['uuid']?.toString() ?? '',
      major: (json['major'] as num?)?.toInt() ?? 0,
      minor: (json['minor'] as num?)?.toInt() ?? 0,
      rssiSeuil: (json['rssi_seuil'] as num?)?.toInt() ?? -70,
      activite: json['activite'] == true,
      vendeurId: json['vendeur_id']?.toString() ?? '',
    );
  }
}
