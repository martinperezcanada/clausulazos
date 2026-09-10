import 'user.dart';

enum ClauseStatus { active, expired, cancelled }

ClauseStatus _statusFromJson(String raw) {
  switch (raw) {
    case 'CANCELLED':
      return ClauseStatus.cancelled;
    case 'EXPIRED':
      return ClauseStatus.expired;
    case 'ACTIVE':
    default:
      return ClauseStatus.active;
  }
}

class Clause {
  const Clause({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.createdAt,
    required this.expiresAt,
    required this.status,
    this.fromUser,
    this.toUser,
  });

  final String id;
  final String fromUserId;
  final String toUserId;
  final DateTime createdAt;
  final DateTime expiresAt;
  final ClauseStatus status;
  final AppUser? fromUser;
  final AppUser? toUser;

  /// A clause is active only if the backend marked it ACTIVE *and* it
  /// hasn't reached its expiration instant yet. Flutter mirrors this for
  /// display purposes, but the backend remains the source of truth.
  bool isActiveAt(DateTime now) => status == ClauseStatus.active && expiresAt.isAfter(now);

  factory Clause.fromJson(Map<String, dynamic> json) {
    return Clause(
      id: json['id'] as String,
      fromUserId: json['fromUserId'] as String,
      toUserId: json['toUserId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      expiresAt: DateTime.parse(json['expiresAt'] as String).toLocal(),
      status: _statusFromJson(json['status'] as String? ?? 'ACTIVE'),
      fromUser: json['fromUser'] != null ? AppUser.fromJson(json['fromUser'] as Map<String, dynamic>) : null,
      toUser: json['toUser'] != null ? AppUser.fromJson(json['toUser'] as Map<String, dynamic>) : null,
    );
  }
}
