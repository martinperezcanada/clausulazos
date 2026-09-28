class PasskeyInfo {
  const PasskeyInfo({
    required this.id,
    required this.name,
    required this.deviceType,
    required this.backedUp,
    required this.transports,
    required this.createdAt,
    required this.lastUsedAt,
  });

  final String id;
  final String? name;
  final String? deviceType;
  final bool backedUp;
  final List<String> transports;
  final DateTime createdAt;
  final DateTime? lastUsedAt;

  /// Fallback label when the passkey has no name, inferred from its transport.
  String get displayName {
    if (name != null && name!.trim().isNotEmpty) return name!.trim();
    if (transports.contains('internal')) return 'Passkey de este dispositivo';
    return 'Passkey';
  }

  factory PasskeyInfo.fromJson(Map<String, dynamic> json) {
    return PasskeyInfo(
      id: json['id'] as String,
      name: json['name'] as String?,
      deviceType: json['deviceType'] as String?,
      backedUp: json['backedUp'] as bool? ?? false,
      transports:
          (json['transports'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      lastUsedAt: json['lastUsedAt'] != null
          ? DateTime.parse(json['lastUsedAt'] as String).toLocal()
          : null,
    );
  }
}
