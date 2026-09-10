import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/release_time_formatter.dart';
import '../models/clause.dart';

class ClauseCard extends StatelessWidget {
  const ClauseCard({super.key, required this.clause, this.currentUserId, this.onCancel});

  final Clause clause;
  final String? currentUserId;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isActive = clause.isActiveAt(now);
    final isCancelled = clause.status == ClauseStatus.cancelled;
    final canCancel = onCancel != null && isActive && clause.fromUserId == currentUserId;

    final statusLabel = isCancelled ? 'CANCELADO' : (isActive ? 'ACTIVO' : 'EXPIRADO');
    final statusColor = isCancelled
        ? AppColors.textSecondary
        : (isActive ? AppColors.primaryGreen : AppColors.dangerRed);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🔥', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${clause.fromUser?.name ?? clause.fromUserId} → ${clause.toUser?.name ?? clause.toUserId}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              ReleaseTimeFormatter.fullDateTime(clause.createdAt),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              isActive
                  ? 'Se libera: ${ReleaseTimeFormatter.fullDateTime(clause.expiresAt)}'
                  : 'Liberado: ${ReleaseTimeFormatter.fullDateTime(clause.expiresAt)}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            if (canCancel) ...[
              const SizedBox(height: 10),
              TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(foregroundColor: AppColors.dangerRed),
                child: const Text('Cancelar cláusulazo'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
