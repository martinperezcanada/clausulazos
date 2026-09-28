import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user.dart';
import '../../providers/user_provider.dart';

/// Slots per manager, derived from `UserProvider.players` (which already includes `stats`). No LALIGA
/// Fantasy dependency.
class SlotsTab extends StatelessWidget {
  const SlotsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();

    if (userProvider.isLoading && userProvider.players.isEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.all(20),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 6,
        itemBuilder: (context, index) => Container(
          height: 84,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
              color: AppColors.surface, borderRadius: BorderRadius.circular(8)),
        ),
      );
    }

    if (userProvider.players.isEmpty) {
      return const Center(
        child: Text('Todavía no hay otros managers en la liga.',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<UserProvider>().refreshAll(),
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: userProvider.players.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) =>
            SlotRow(manager: userProvider.players[index]),
      ),
    );
  }
}

class SlotRow extends StatelessWidget {
  const SlotRow({super.key, required this.manager});
  final AppUser manager;

  @override
  Widget build(BuildContext context) {
    final stats = manager.stats;
    final receivedFull = stats?.received.isComplete ?? false;
    final performedFull = stats?.performed.isComplete ?? false;

    final String statusLabel;
    final Color statusColor;
    if (stats == null) {
      statusLabel = 'SIN DATOS';
      statusColor = AppColors.textSecondary;
    } else if (receivedFull) {
      statusLabel = 'BLINDADO';
      statusColor = AppColors.primaryGreen;
    } else {
      statusLabel = 'VULNERABLE';
      statusColor = AppColors.dangerRed;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.surfaceElevated,
            child: Text(
              manager.name.isNotEmpty ? manager.name[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(manager.name, style: AppTextStyles.headline(fontSize: 15)),
                const SizedBox(height: 4),
                if (stats != null)
                  Text(
                    'Realizadas ${stats.performed.active}/${stats.performed.limit}'
                    '${performedFull ? ' · AGOTADAS' : ''}'
                    '  ·  Recibidas ${stats.received.active}/${stats.received.limit}',
                    style: AppTextStyles.mono(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4)),
            child: Text(
              statusLabel,
              style: AppTextStyles.mono(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: statusColor),
            ),
          ),
        ],
      ),
    );
  }
}
