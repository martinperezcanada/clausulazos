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

// PENDING: detected automatically from LALIGA, awaiting confirmation from
//          both participants — never counts toward the 2-slot limits.
// clause:  confirmed as a real clausulazo — counts toward the limits.
// agreed:  confirmed by BOTH participants as a pacted transfer — never
//          counts, no matter how recent.
enum ClauseClassification { pending, clause, agreed }

ClauseClassification _classificationFromJson(String? raw) {
  switch (raw) {
    case 'AGREED':
      return ClauseClassification.agreed;
    case 'PENDING':
      return ClauseClassification.pending;
    case 'CLAUSE':
    default:
      // Older cached data or manually-created clauses default to CLAUSE,
      // matching the backend's own default.
      return ClauseClassification.clause;
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
  // Best-effort — LALIGA's sync payload doesn't always resolve a name for
  // every movement type, so this can be null even for a real clause.
  final String? playerName;
  final int? amount;

  /// Never leaves the UI showing a raw `null` where a player should be.
  String get displayPlayerName => (playerName != null && playerName!.trim().isNotEmpty) ? playerName! : 'un jugador';

  /// A clause is active only if the backend marked it ACTIVE, it hasn't
  /// reached its expiration instant yet, AND it's classified as a real
  /// CLAUSE (PENDING/AGREED movements never occupy a slot). Flutter
  /// mirrors this for display purposes, but the backend remains the
  /// source of truth.
  bool isActiveAt(DateTime now) =>
      status == ClauseStatus.active &&
      classification == ClauseClassification.clause &&
      expiresAt.isAfter(now);

  /// Whether `userId` still needs to confirm this movement (i.e. they're
  /// a participant, the movement is still pending, and they haven't voted
  /// yet).
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
      classification: _classificationFromJson(json['classification'] as String?),
      fromConfirmation: _confirmationFromJson(json['fromConfirmation'] as String?),
      toConfirmation: _confirmationFromJson(json['toConfirmation'] as String?),
      fromUser: json['fromUser'] != null ? AppUser.fromJson(json['fromUser'] as Map<String, dynamic>) : null,
      toUser: json['toUser'] != null ? AppUser.fromJson(json['toUser'] as Map<String, dynamic>) : null,
      playerName: json['playerName'] as String?,
      amount: json['amount'] as int?,
    );
  }
}
