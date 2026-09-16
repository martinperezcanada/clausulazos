import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/release_time_formatter.dart';
import '../models/user.dart';

class PlayerCard extends StatelessWidget {
  const PlayerCard({
    super.key,
    required this.player,
    this.onTap,
    this.showReceivedOnly = false,
  });

  final AppUser player;
  final VoidCallback? onTap;

  /// When true (player-selection screen), only the "received" slot is
  /// shown, since that's what determines whether they can be clausulado.
  final bool showReceivedOnly;

  @override
  Widget build(BuildContext context) {
    final stats = player.stats;
    final receivedFull = stats?.received.isComplete ?? false;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.surfaceElevated,
                child: Text(
                  player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
                  style: const TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(player.name,
                        style: AppTextStyles.headline(fontSize: 16)),
                    const SizedBox(height: 4),
                    if (stats != null) ...[
                      if (showReceivedOnly)
                        _buildLine('RECIBIDOS', stats.received, receivedFull)
                      else ...[
                        _buildLine('REALIZADOS', stats.performed, false),
                        _buildLine('RECIBIDOS', stats.received, receivedFull),
                      ],
                    ],
                  ],
                ),
              ),
              if (onTap != null) const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLine(String label, SlotStats slot, bool danger) {
    final text = slot.isComplete
        ? 'COMPLETO${slot.nextReleaseAt != null ? ' · ${ReleaseTimeFormatter.describe(slot.nextReleaseAt!)}' : ''}'
        : '${slot.active}/${slot.limit} · Puede ${label == 'RECIBIDOS' ? 'recibir' : 'hacer'} ${slot.available} más';

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        '$label $text',
        style: AppTextStyles.mono(
          color: slot.isComplete ? AppColors.dangerRed : AppColors.textSecondary,
          fontSize: 12,
        ),
      ),
    );
  }
}
