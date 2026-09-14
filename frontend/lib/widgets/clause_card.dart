import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/release_time_formatter.dart';
import '../models/clause.dart';

class ClauseCard extends StatelessWidget {
  const ClauseCard({
    super.key,
    required this.clause,
    this.currentUserId,
    this.onCancel,
    this.onConfirm,
    this.isConfirming = false,
  });

  final Clause clause;
  final String? currentUserId;
  final VoidCallback? onCancel;

  /// Called with 'CLAUSE' or 'AGREED' when the current user taps one of
  /// the confirmation options on a PENDING movement.
  final void Function(String classification)? onConfirm;

  /// Shows a small inline spinner instead of the confirm buttons while a
  /// confirmation request for this specific card is in flight.
  final bool isConfirming;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isPending = clause.classification == ClauseClassification.pending;
    final isAgreed = clause.classification == ClauseClassification.agreed;
    final isActive = clause.isActiveAt(now);
    final isCancelled = clause.status == ClauseStatus.cancelled;
    final canCancel = onCancel != null && isActive && clause.fromUserId == currentUserId;

    final String headerEmoji;
    final String statusLabel;
    final Color statusColor;

    if (isPending) {
      headerEmoji = '⏳';
      statusLabel = 'PENDIENTE';
      statusColor = AppColors.textSecondary;
    } else if (isAgreed) {
      headerEmoji = '🤝';
      statusLabel = 'ACUERDO';
      statusColor = AppColors.primaryGreen;
    } else {
      headerEmoji = '⚡';
      statusLabel = isCancelled ? 'CANCELADO' : (isActive ? 'ACTIVO' : 'EXPIRADO');
      statusColor = isCancelled
          ? AppColors.textSecondary
          : (isActive ? AppColors.primaryGreen : AppColors.dangerRed);
    }

    final canConfirm = onConfirm != null &&
        currentUserId != null &&
        clause.needsConfirmationFrom(currentUserId!);
    final awaitingOther = isPending &&
        !canConfirm &&
        currentUserId != null &&
        (clause.fromUserId == currentUserId || clause.toUserId == currentUserId);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(headerEmoji, style: const TextStyle(fontSize: 18)),
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
            if (!isPending && !isAgreed) ...[
              const SizedBox(height: 4),
              Text(
                isActive
                    ? 'Se libera: ${ReleaseTimeFormatter.fullDateTime(clause.expiresAt)}'
                    : 'Liberado: ${ReleaseTimeFormatter.fullDateTime(clause.expiresAt)}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
            if (isPending) ...[
              const SizedBox(height: 4),
              const Text(
                'Pendiente de confirmar',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
            if (canConfirm) ...[
              const SizedBox(height: 12),
              if (isConfirming)
                const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => onConfirm!('CLAUSE'),
                        child: const Text('⚡ Cláusulazo'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => onConfirm!('AGREED'),
                        child: const Text('🤝 Acuerdo'),
                      ),
                    ),
                  ],
                ),
            ] else if (awaitingOther) ...[
              const SizedBox(height: 8),
              const Text(
                'Esperando confirmación del otro participante.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
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
