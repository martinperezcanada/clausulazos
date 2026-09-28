import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/sync_time_formatter.dart';
import 'pulsing_dot.dart';

/// Pill showing Fantasy Sync health next to the greeting (`GET /fantasy/sync/status`).
///
/// Optionally tappable, only wired up in Modo Admin (see `HomeScreen`): while `isSyncing` it shows a
/// loading indicator instead of the dot and reads "Sincronizando...", never "Sincronizado" before the
/// request finishes.
class SyncStatusPill extends StatelessWidget {
  const SyncStatusPill({
    super.key,
    required this.lastSuccessfulSyncAt,
    this.isSyncing = false,
    this.onTap,
  });

  final DateTime? lastSuccessfulSyncAt;
  final bool isSyncing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final synced = lastSuccessfulSyncAt != null;
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSyncing)
            const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                  strokeWidth: 1.5, color: AppColors.primaryGreen),
            )
          else
            PulsingDot(
                color:
                    synced ? AppColors.primaryGreen : AppColors.textSecondary,
                size: 6),
          const SizedBox(width: 6),
          Text(
            isSyncing
                ? 'Sincronizando...'
                : SyncTimeFormatter.describe(lastSuccessfulSyncAt),
            style:
                AppTextStyles.mono(fontSize: 11, color: AppColors.textPrimary),
          ),
        ],
      ),
    );

    if (onTap == null) return pill;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: isSyncing ? null : onTap,
      child: pill,
    );
  }
}
