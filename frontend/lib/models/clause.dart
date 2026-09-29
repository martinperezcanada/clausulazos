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

// PENDING: detected from LALIGA, awaiting both participants; never counts toward the limits.
// clause:  confirmed as a real clausulazo; counts toward the limits.
// agreed:  confirmed by both participants as an agreed transfer; never counts.
enum ClauseClassification { pending, clause, agreed }

ClauseClassification _classificationFromJson(String? raw) {
  switch (raw) {
    case 'AGREED':
      return ClauseClassification.agreed;
    case 'PENDING':
      return ClauseClassification.pending;
    case 'CLAUSE':
      return ClauseClassification.clause;
    case null:
      return ClauseClassification.pending;
    default:
      return ClauseClassification.pending;
  }
}

ClauseClassification? _confirmationFromJson(String? raw) {
  if (raw == null) return null;
  return _classificationFromJson(raw);
}

class Clause {
  const Clause({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.createdAt,
    required this.expiresAt,
    required this.status,
    this.classification = ClauseClassification.clause,
    this.fromConfirmation,
    this.toConfirmation,
    this.fromUser,
    this.toUser,
    this.playerName,
    this.playerImageUrl,
    this.amount,
  });

  final String id;
  final String fromUserId;
  final String toUserId;
  final DateTime createdAt;
  final DateTime expiresAt;
  final ClauseStatus status;
  final ClauseClassification classification;
  final ClauseClassification? fromConfirmation;
  final ClauseClassification? toConfirmation;
  final AppUser? fromUser;
  final AppUser? toUser;
  // Best effort: LALIGA's sync payload doesn't always resolve a name, so this can be null.
  final String? playerName;
  // Official LALIGA picture of the player, filled by the Fantasy sync; null when unknown.
  final String? playerImageUrl;
  final int? amount;

  /// Falls back to "un jugador" when the name is unknown.
  String get displayPlayerName =>
      (playerName != null && playerName!.trim().isNotEmpty)
          ? playerName!
          : 'un jugador';

  /// Active if the backend marked it ACTIVE, it hasn't expired and it's classified as CLAUSE (PENDING and
  /// AGREED never occupy a slot). Mirrors the backend for display; the backend is the source of truth.
  bool isActiveAt(DateTime now) =>
      status == ClauseStatus.active &&
      classification == ClauseClassification.clause &&
      expiresAt.isAfter(now);

  /// Whether `userId` still has to confirm this movement: they take part in it, it's pending and they
  /// haven't voted yet.
  bool needsConfirmationFrom(String userId) {
    if (classification != ClauseClassification.pending) return false;
    if (userId == fromUserId) return fromConfirmation == null;
    if (userId == toUserId) return toConfirmation == null;
    return false;
  }

  factory Clause.fromJson(Map<String, dynamic> json) {
    return Clause(
      id: json['id'] as String,
      fromUserId: json['fromUserId'] as String,
      toUserId: json['toUserId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      expiresAt: DateTime.parse(json['expiresAt'] as String).toLocal(),
      status: _statusFromJson(json['status'] as String? ?? 'ACTIVE'),
      classification:
          _classificationFromJson(json['classification'] as String?),
      fromConfirmation:
          _confirmationFromJson(json['fromConfirmation'] as String?),
      toConfirmation: _confirmationFromJson(json['toConfirmation'] as String?),
      fromUser: json['fromUser'] != null
          ? AppUser.fromJson(json['fromUser'] as Map<String, dynamic>)
          : null,
      toUser: json['toUser'] != null
          ? AppUser.fromJson(json['toUser'] as Map<String, dynamic>)
          : null,
      playerName: json['playerName'] as String?,
      playerImageUrl: json['playerImageUrl'] as String?,
      amount: json['amount'] as int?,
    );
  }
}
