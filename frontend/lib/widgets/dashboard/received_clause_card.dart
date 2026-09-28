import 'package:flutter/material.dart';
import '../../core/theme/amount_formatter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/cooldown_formatter.dart';
import '../../models/clause.dart';
import 'pulsing_dot.dart';
import 'slot_status.dart';

/// "Cláusulas Recibidas": clauses other managers hold on this manager. When `active >= limit` the
/// roster is "blindado": nobody else can clause them until a slot frees up.
class ReceivedClauseCard extends StatelessWidget {
  const ReceivedClauseCard({
    super.key,
    required this.activeClauses,
    required this.active,
    required this.limit,
  });

  final List<Clause> activeClauses;
  final int active;
  final int limit;

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
                  : _CountBadge(active: active, limit: limit),
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
              _ReceivedItem(clause: activeClauses[i])
            else
              SlotStatus(
                  slotNumber: i + 1, hint: 'Un rival puede clausularte aquí'),
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

class _ReceivedItem extends StatelessWidget {
  const _ReceivedItem({required this.clause});

  final Clause clause;

  @override
  Widget build(BuildContext context) {
    final counterpart = clause.fromUser?.name ?? 'un manager';
    final remaining = clause.expiresAt.difference(DateTime.now());
    final isUrgent =
        !remaining.isNegative && remaining <= const Duration(hours: 24);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8)),
      child: Row(
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
                      ? 'Comprado por $counterpart · ${AmountFormatter.format(clause.amount!)}'
                      : 'Comprado por $counterpart',
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
              if (isUrgent)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const PulsingDot(color: AppColors.dangerRed, size: 6),
                    const SizedBox(width: 4),
                    Text(
                      'Libera pronto',
                      style: AppTextStyles.mono(
                          fontSize: 9,
                          color: AppColors.dangerRed,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                )
              else
                Text('Libera en',
                    style: AppTextStyles.mono(
                        fontSize: 9, color: AppColors.textSecondary)),
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
    );
  }
}
