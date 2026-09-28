import '../../models/clause.dart';

class ExpirationNotice {
  const ExpirationNotice({
    required this.clause,
    required this.message,
    required this.isJustReleased,
  });

  final Clause clause;
  final String message;
  final bool isJustReleased;
}

/// Builds "your clause is about to release / just released" notices from a clause list the app already
/// has (`/clauses/me` or `/clauses`). Only clauses that count (CLAUSE, not PENDING/AGREED/cancelled) and
/// involve the current user are considered, using `expiresAt`.
class ExpirationNotices {
  ExpirationNotices._();

  static List<ExpirationNotice> build({
    required List<Clause> clauses,
    required String currentUserId,
    DateTime? now,
  }) {
    final nowTime = now ?? DateTime.now();
    final notices = <ExpirationNotice>[];

    for (final clause in clauses) {
      final isMine = clause.fromUserId == currentUserId ||
          clause.toUserId == currentUserId;
      if (!isMine) continue;
      if (clause.classification != ClauseClassification.clause) continue;

      final diff = clause.expiresAt.difference(nowTime);

      if (diff.isNegative) {
        // "Just released" is only shown for a day; after that it's history.
        if (diff.inHours.abs() <= 24) {
          notices.add(ExpirationNotice(
            clause: clause,
            message:
                'Tu cláusulazo sobre ${clause.displayPlayerName} se ha liberado.',
            isJustReleased: true,
          ));
        }
        continue;
      }

      // Only within a 2-day horizon; further out it isn't actionable yet.
      if (diff.inDays >= 2) continue;

      notices.add(ExpirationNotice(
        clause: clause,
        message:
            'Tu cláusulazo sobre ${clause.displayPlayerName} ${_phraseFor(diff)}',
        isJustReleased: false,
      ));
    }

    // Soonest first: released ones, then whichever expires next.
    notices.sort((a, b) {
      if (a.isJustReleased != b.isJustReleased)
        return a.isJustReleased ? -1 : 1;
      return a.clause.expiresAt.compareTo(b.clause.expiresAt);
    });

    return notices;
  }

  static String _phraseFor(Duration diff) {
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return 'se libera en $m minuto${m == 1 ? '' : 's'}.';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return 'se libera en $h hora${h == 1 ? '' : 's'}.';
    }
    return 'se libera mañana.';
  }
}
