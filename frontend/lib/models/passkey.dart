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

  /// A short, friendly label to show when the user didn't (or couldn't)
  /// give this passkey a name — inferred from the transport, which is the
  /// closest thing we get to "what kind of device is this".
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
      transports: (json['transports'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      lastUsedAt: json['lastUsedAt'] != null ? DateTime.parse(json['lastUsedAt'] as String).toLocal() : null,
    );
  }
}
