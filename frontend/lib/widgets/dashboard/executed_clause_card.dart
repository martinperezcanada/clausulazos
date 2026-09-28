import 'package:flutter/material.dart';
import '../../core/theme/amount_formatter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/cooldown_formatter.dart';
import '../../models/clause.dart';
import 'cooldown_timer.dart';
import 'pulsing_dot.dart';
import 'slot_status.dart';

/// "Cláusulas Ejecutadas": the clausulazos this manager has triggered, each occupying one of their
/// `limit` performed slots for 7 days.
class ExecutedClauseCard extends StatelessWidget {
  const ExecutedClauseCard({
    super.key,
    required this.activeClauses,
    required this.active,
    required this.limit,
  });

  final List<Clause> activeClauses;
  final int active;
  final int limit;

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
              _CountBadge(active: active, limit: limit),
            ],
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < limit; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            if (i < activeClauses.length)
              _ExecutedItem(clause: activeClauses[i])
            else
              SlotStatus(
                  slotNumber: i + 1, hint: 'Puedes clausular otro jugador'),
          ],
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.active, required this.limit});

  final int active;
  final int limit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.infoBlue.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$active/$limit Activas',
        style: AppTextStyles.mono(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.infoBlue),
      ),
    );
  }
}

class _ExecutedItem extends StatelessWidget {
  const _ExecutedItem({required this.clause});

  final Clause clause;

  @override
  Widget build(BuildContext context) {
    final counterpart = clause.toUser?.name ?? 'un manager';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: AppColors.surfaceHighest,
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.sports_soccer_rounded,
                    color: AppColors.textSecondary, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clause.displayPlayerName,
                      style: AppTextStyles.headline(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      clause.amount != null
                          ? 'A $counterpart · ${AmountFormatter.format(clause.amount!)}'
                          : 'A $counterpart',
                      style: AppTextStyles.body(
                          fontSize: 12, color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const PulsingDot(color: AppColors.primaryGreen, size: 6),
                      const SizedBox(width: 4),
                      Text(
                        'En enfriamiento',
                        style: AppTextStyles.mono(
                            fontSize: 9,
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    CooldownFormatter.remaining(clause.expiresAt),
                    style: AppTextStyles.mono(
                        fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          CooldownTimer(
              createdAt: clause.createdAt, expiresAt: clause.expiresAt),
        ],
      ),
    );
  }
}
