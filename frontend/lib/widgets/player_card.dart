import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/release_time_formatter.dart';
import '../models/user.dart';

/// A manager row in the Managers list: boxed avatar, quota panel with pips and a status badge row.
/// Values come from `AppUser.stats`.
class PlayerCard extends StatelessWidget {
  const PlayerCard({
    super.key,
    required this.player,
    this.onTap,
  });

  final AppUser player;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final stats = player.stats;
    final receivedFull = stats?.received.isComplete ?? false;
    final performedFull = stats?.performed.isComplete ?? false;
    final initials =
        player.name.isNotEmpty ? player.name[0].toUpperCase() : '?';
    final releaseAt = stats?.received.nextReleaseAt;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: const BoxDecoration(color: AppColors.surface),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        initials,
                        style: const TextStyle(
                            fontSize: 17,
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        player.name,
                        style: AppTextStyles.headline(fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (onTap != null)
                      const Icon(Icons.chevron_right_rounded,
                          color: AppColors.textSecondary, size: 20),
                  ],
                ),
                if (stats != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _QuotaPips(
                                label: 'REALIZADAS',
                                active: stats.performed.active,
                                limit: stats.performed.limit,
                                full: performedFull,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _QuotaPips(
                                label: 'RECIBIDAS',
                                active: stats.received.active,
                                limit: stats.received.limit,
                                full: receivedFull,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                              color: AppColors.surfaceHighest,
                              borderRadius: BorderRadius.circular(6)),
                          child: Row(
                            children: [
                              Icon(
                                receivedFull
                                    ? Icons.shield_rounded
                                    : Icons.bolt_rounded,
                                size: 15,
                                color: receivedFull
                                    ? AppColors.dangerRed
                                    : AppColors.primaryGreen,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  receivedFull
                                      ? 'BLINDADO'
                                      : 'DISPONIBLE PARA CLAUSULAR',
                                  style: AppTextStyles.mono(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: receivedFull
                                              ? AppColors.dangerRed
                                              : AppColors.primaryGreen)
                                      .copyWith(letterSpacing: 0.6),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (receivedFull && releaseAt != null)
                                Text(
                                  ReleaseTimeFormatter.describe(releaseAt),
                                  style: AppTextStyles.mono(
                                      fontSize: 10,
                                      color: AppColors.textSecondary),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      'SIN DATOS',
                      style: AppTextStyles.mono(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Realizadas"/"Recibidas" quota as pip bars (one per `limit` slot, filled up to `active`) plus the
/// exact fraction.
class _QuotaPips extends StatelessWidget {
  const _QuotaPips({
    required this.label,
    required this.active,
    required this.limit,
    required this.full,
  });

  final String label;
  final int active;
  final int limit;
  final bool full;

  @override
  Widget build(BuildContext context) {
    final color = full ? AppColors.dangerRed : AppColors.primaryGreen;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label and fraction on the same line, baseline-aligned. The label
        // is the flexible part (ellipsis) so a narrow card can never overflow.
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.mono(
                        fontSize: 9, color: AppColors.textSecondary)
                    .copyWith(letterSpacing: 0.6),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$active/$limit',
              style: AppTextStyles.mono(
                  fontSize: 11, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // One wide band per `limit` slot, stacked and stretched across this half of the card (the first
        // `active` ones are filled).
        for (var i = 0; i < limit; i++) ...[
          if (i > 0) const SizedBox(height: 4),
          Container(
            width: double.infinity,
            height: 12,
            decoration: BoxDecoration(
              color: i < active ? color : AppColors.surfaceHighest,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ],
    );
  }
}
