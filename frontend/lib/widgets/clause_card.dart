import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/release_time_formatter.dart';
import '../models/clause.dart';

final _amountFormat = NumberFormat.currency(
  locale: 'es_ES',
  symbol: '€',
  decimalDigits: 0,
);

class ClauseCard extends StatelessWidget {
  const ClauseCard({
    super.key,
    required this.clause,
    this.currentUserId,
    this.onConfirm,
    this.isConfirming = false,
  });

  final Clause clause;
  final String? currentUserId;

  /// Called with 'CLAUSE' or 'AGREED' after the user confirms the choice.
  final void Function(String classification)? onConfirm;

  final bool isConfirming;

  Future<void> _showConfirmationDialog(
    BuildContext context,
    String classification,
  ) async {
    final isClause = classification == 'CLAUSE';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            isClause ? 'Confirmar cláusulazo' : 'Confirmar acuerdo',
          ),
          content: Text(
            isClause
                ? '¿Estás seguro de que quieres confirmar este movimiento como cláusulazo? Esta elección se registrará en la actividad.'
                : '¿Estás seguro de que quieres confirmar este movimiento como acuerdo? Esta elección se registrará en la actividad.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Volver'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(
                isClause ? 'Confirmar cláusulazo' : 'Confirmar acuerdo',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      onConfirm?.call(classification);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    final isPending = clause.classification == ClauseClassification.pending;

    final isAgreed = clause.classification == ClauseClassification.agreed;

    final isActive = clause.isActiveAt(now);

    final isCancelled = clause.status == ClauseStatus.cancelled;

    final String dot;
    final String typeLabel;
    final Color typeColor;

    if (isPending) {
      dot = '🟡';
      typeLabel = 'PENDIENTE';
      typeColor = AppColors.pendingYellow;
    } else if (isAgreed) {
      dot = '🔵';
      typeLabel = 'ACUERDO';
      typeColor = AppColors.infoBlue;
    } else {
      dot = '🟢';
      typeLabel = 'CLAUSULAZO';
      typeColor = AppColors.primaryGreen;
    }

    final canConfirm = onConfirm != null &&
        currentUserId != null &&
        clause.needsConfirmationFrom(currentUserId!);

    final awaitingOther = isPending &&
        !canConfirm &&
        currentUserId != null &&
        (clause.fromUserId == currentUserId ||
            clause.toUserId == currentUserId);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  dot,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${clause.fromUser?.name ?? clause.fromUserId} → ${clause.toUser?.name ?? clause.toUserId}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    typeLabel,
                    style: TextStyle(
                      color: typeColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.sports_soccer,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    clause.displayPlayerName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (clause.amount != null)
                  Text(
                    _amountFormat.format(clause.amount),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              ReleaseTimeFormatter.fullDateTime(clause.createdAt),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            if (!isPending && !isAgreed) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    isCancelled
                        ? 'Cancelado'
                        : (isActive ? 'Activo' : 'Expirado'),
                    style: TextStyle(
                      color: isCancelled
                          ? AppColors.textSecondary
                          : (isActive
                              ? AppColors.primaryGreen
                              : AppColors.textSecondary),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    ' · ',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    isActive
                        ? 'Se libera: ${ReleaseTimeFormatter.fullDateTime(clause.expiresAt)}'
                        : 'Liberado: ${ReleaseTimeFormatter.fullDateTime(clause.expiresAt)}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
            if (isPending) ...[
              const SizedBox(height: 4),
              const Text(
                'Pendiente de confirmar por ambos participantes',
                style: TextStyle(
                  color: AppColors.pendingYellow,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (canConfirm) ...[
              const SizedBox(height: 12),
              if (isConfirming)
                const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          _showConfirmationDialog(
                            context,
                            'CLAUSE',
                          );
                        },
                        child: const Text('🟢 Cláusulazo'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          _showConfirmationDialog(
                            context,
                            'AGREED',
                          );
                        },
                        child: const Text('🔵 Acuerdo'),
                      ),
                    ),
                  ],
                ),
            ] else if (awaitingOther) ...[
              const SizedBox(height: 8),
              const Text(
                'Esperando confirmación del otro participante.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
