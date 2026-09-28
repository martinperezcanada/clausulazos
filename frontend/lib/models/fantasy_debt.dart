/// One manager's accumulated debt under the league money rule (last place of a jornada owes 1,00€,
/// penultimate 0,75€, antepenultimate 0,50€, summed over the jornadas played), from
/// `GET /fantasy/debts`. `managerId`/`managerName` are LALIGA's own manager identity.
class FantasyDebt {
  const FantasyDebt({
    required this.managerId,
    required this.managerName,
    required this.debtCents,
  });

  final String managerId;
  final String managerName;
  final int debtCents;

  factory FantasyDebt.fromJson(Map<String, dynamic> json) {
    return FantasyDebt(
      managerId: json['managerId']?.toString() ?? '',
      managerName: json['managerName']?.toString() ?? 'Manager',
      debtCents: (json['debtCents'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Full `GET /fantasy/debts` response: the debt per manager plus the jornadas still missing a finished
/// match, which are excluded from the calculation (numbers come from LALIGA's calendar).
class FantasyDebtsSnapshot {
  const FantasyDebtsSnapshot({
    required this.managers,
    required this.pendingWeeks,
    this.weeksEvaluated = 0,
  });

  final List<FantasyDebt> managers;
  final List<int> pendingWeeks;

  /// Highest jornada that has started, finished or still pending: the season's current one. Also used
  /// by Actividad's "Jx EN VIVO" indicator together with [pendingWeeks].
  final int weeksEvaluated;

  factory FantasyDebtsSnapshot.fromJson(Map<String, dynamic> json) {
    final managersJson = json['managers'] as List? ?? const [];
    final pendingJson = json['pendingWeeks'] as List? ?? const [];
    return FantasyDebtsSnapshot(
      managers: managersJson
          .whereType<Map>()
          .map((e) => FantasyDebt.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      pendingWeeks: pendingJson.whereType<num>().map((n) => n.toInt()).toList(),
      weeksEvaluated: (json['weeksEvaluated'] as num?)?.toInt() ?? 0,
    );
  }
}

/// One finished jornada in the "Tabla general" chart: each manager's accumulated debt right after it
/// (`GET /fantasy/debts/history`). A pending or unstarted jornada never produces one.
class FantasyDebtHistoryPoint {
  const FantasyDebtHistoryPoint({required this.week, required this.managers});

  final int week;
  final List<FantasyDebt> managers;

  factory FantasyDebtHistoryPoint.fromJson(Map<String, dynamic> json) {
    final managersJson = json['managers'] as List? ?? const [];
    return FantasyDebtHistoryPoint(
      week: (json['week'] as num?)?.toInt() ?? 0,
      managers: managersJson
          .whereType<Map>()
          .map((e) => FantasyDebt.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

/// Full `GET /fantasy/debts/history` response.
class FantasyDebtHistory {
  const FantasyDebtHistory({required this.pendingWeeks, required this.points});

  final List<int> pendingWeeks;
  final List<FantasyDebtHistoryPoint> points;

  factory FantasyDebtHistory.fromJson(Map<String, dynamic> json) {
    final pendingJson = json['pendingWeeks'] as List? ?? const [];
    final pointsJson = json['points'] as List? ?? const [];
    return FantasyDebtHistory(
      pendingWeeks: pendingJson.whereType<num>().map((n) => n.toInt()).toList(),
      points: pointsJson
          .whereType<Map>()
          .map((e) =>
              FantasyDebtHistoryPoint.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
