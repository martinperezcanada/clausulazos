import 'package:flutter/material.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../models/clause.dart';
import '../../models/user.dart';
import 'active_count_badge.dart';
import 'occupied_clause_slot.dart';
import 'slot_status.dart';

/// "Cláusulas Recibidas": clauses other managers hold on this manager. When `active >= limit` the
/// roster is "blindado": nobody else can clause them until a slot frees up.
class ReceivedClauseCard extends StatelessWidget {
  const ReceivedClauseCard({
    super.key,
    required this.activeClauses,
    required this.stats,
  });

  final List<Clause> activeClauses;

  /// The manager's received slots, the same figures Managers shows. Null only while they haven't loaded;
  /// the card then falls back to the clauses it lists.
  final SlotStats? stats;

  int get active => stats?.active ?? activeClauses.length;
  int get limit => stats?.limit ?? AppConfig.maxActiveClauses;

  bool get _isShielded => active >= limit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_rounded,
                  color: AppColors.dangerRed, size: 20),
              const SizedBox(width: 8),
              Expanded(
                  child: Text('Cláusulas Recibidas',
                      style: AppTextStyles.headline(fontSize: 16))),
              _isShielded
                  ? _ShieldedBadge(active: active, limit: limit)
                  : ActiveCountBadge(active: active, limit: limit),
            ],
          ),
          if (_isShielded) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded,
                      color: AppColors.primaryGreen, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '¡Tu plantilla está blindada! Nadie puede pagar tus cláusulas actualmente.',
                      style: AppTextStyles.body(
                          fontSize: 12, color: AppColors.primaryGreen),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          for (var i = 0; i < limit; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            if (i < activeClauses.length)
              OccupiedClauseSlot(
                clause: activeClauses[i],
                counterpartLabel:
                    'Comprado por ${activeClauses[i].fromUser?.name ?? 'un manager'}',
                // A clause made on you also shields that slot until it frees up. Cyan, like this card's
                // "Activas" badge: calm next to the red shield of the title, and distinct from the green
                // "En enfriamiento" of executed clauses.
                statusLabel: 'Protección activa',
                statusColor: AppColors.infoBlue,
              )
            else
              SlotStatus(
                  slotNumber: i + 1, hint: 'Un rival puede clausularte aquí'),
          ],
        ],
      ),
    );
  }
}

class _ShieldedBadge extends StatelessWidget {
  const _ShieldedBadge({required this.active, required this.limit});

  final int active;
  final int limit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: AppColors.primaryGreen,
          borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_rounded, size: 12, color: Colors.black),
          const SizedBox(width: 4),
          Text(
            'BLINDADO ($active/$limit)',
            style: AppTextStyles.mono(
                fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black),
          ),
        ],
      ),
    );
  }
}
