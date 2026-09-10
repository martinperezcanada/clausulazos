class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.createdAt,
    this.stats,
  });

  final String id;
  final String name;
  final String email;
  final DateTime? createdAt;
  final UserStats? stats;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : null,
      stats: json['stats'] != null ? UserStats.fromJson(json['stats'] as Map<String, dynamic>) : null,
    );
  }
}

class SlotStats {
  const SlotStats({
    required this.active,
    required this.limit,
    required this.available,
    this.nextReleaseAt,
  });

  final int active;
  final int limit;
  final int available;
  final DateTime? nextReleaseAt;

  bool get isComplete => available <= 0;

  factory SlotStats.fromJson(Map<String, dynamic> json) {
    return SlotStats(
      active: json['active'] as int,
      limit: json['limit'] as int,
      available: json['available'] as int,
      nextReleaseAt: json['nextReleaseAt'] != null
          ? DateTime.parse(json['nextReleaseAt'] as String)
          : null,
    );
  }
}

class UserStats {
  const UserStats({required this.performed, required this.received});

  final SlotStats performed;
  final SlotStats received;

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      performed: SlotStats.fromJson(json['performed'] as Map<String, dynamic>),
      received: SlotStats.fromJson(json['received'] as Map<String, dynamic>),
    );
  }
}
