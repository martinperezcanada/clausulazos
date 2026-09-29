import 'package:flutter/material.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../models/clause.dart';
import '../../models/user.dart';
import 'active_count_badge.dart';
import 'occupied_clause_slot.dart';
import 'slot_status.dart';

/// "Cláusulas Ejecutadas": the clausulazos this manager has triggered, each occupying one of their
/// `limit` performed slots for 7 days.
class ExecutedClauseCard extends StatelessWidget {
  const ExecutedClauseCard({
    super.key,
    required this.activeClauses,
    required this.stats,
  });

  final List<Clause> activeClauses;

  /// The manager's performed slots, the same figures Managers shows. Null only while they haven't loaded;
  /// the card then falls back to the clauses it lists.
  final SlotStats? stats;

  int get active => stats?.active ?? activeClauses.length;
  int get limit => stats?.limit ?? AppConfig.maxActiveClauses;

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
              const Icon(Icons.trending_up_rounded,
                  color: AppColors.primaryGreen, size: 20),
              const SizedBox(width: 8),
              Expanded(
                  child: Text('Cláusulas Ejecutadas',
                      style: AppTextStyles.headline(fontSize: 16))),
              ActiveCountBadge(active: active, limit: limit),
            ],
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < limit; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            if (i < activeClauses.length)
              OccupiedClauseSlot(
                clause: activeClauses[i],
                counterpartLabel:
                    'A ${activeClauses[i].toUser?.name ?? 'un manager'}',
              )
            else
              SlotStatus(
                  slotNumber: i + 1, hint: 'Puedes clausular otro jugador'),
          ],
        ],
      ),
    );
  }
}
