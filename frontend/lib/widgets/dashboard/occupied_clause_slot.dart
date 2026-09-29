import 'package:flutter/material.dart';
import '../../core/theme/amount_formatter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/cooldown_formatter.dart';
import '../../models/clause.dart';
import '../player_avatar.dart';
import 'cooldown_timer.dart';
import 'pulsing_dot.dart';

/// An occupied slot in Inicio's "Cláusulas Ejecutadas" and "Cláusulas Recibidas" cards: player, the other
/// manager and amount, cooldown status and remaining time, and the cooldown bar. Both cards use it, so an
/// occupied slot looks the same in either; only the text (`counterpartLabel`, `statusLabel`) and the
/// status accent (`statusColor`) differ.
class OccupiedClauseSlot extends StatelessWidget {
  const OccupiedClauseSlot({
    super.key,
    required this.clause,
    required this.counterpartLabel,
    this.statusLabel = 'En enfriamiento',
    this.statusColor = AppColors.primaryGreen,
  });

  final Clause clause;

  /// Who is on the other side, e.g. "A Alex" (executed) or "Comprado por Alex" (received).
  final String counterpartLabel;

  /// Short state shown above the remaining time, with its pulsing dot in `statusColor`.
  final String statusLabel;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
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
              PlayerAvatar(
                  imageUrl: clause.playerImageUrl, size: 40, iconSize: 18),
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
                          ? '$counterpartLabel · ${AmountFormatter.format(clause.amount!)}'
                          : counterpartLabel,
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
                      PulsingDot(color: statusColor, size: 6),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: AppTextStyles.mono(
                            fontSize: 9,
                            color: statusColor,
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
