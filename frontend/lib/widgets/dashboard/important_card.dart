import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/amount_formatter.dart';
import '../../core/theme/app_theme.dart';
import '../../models/clause.dart';
import '../player_avatar.dart';
import 'pulsing_dot.dart';

/// The red "IMPORTANTE" card. Shows either a PENDING clause awaiting this user's classification, with
/// the same "Fue Cláusulazo" / "Acuerdo Pactado" actions as Activity (`PATCH
/// /clauses/:id/classification`), or a plain alert (limit exceeded, expiration notice). Never shown
/// when there is nothing important.
class ImportantCard extends StatelessWidget {
  const ImportantCard({
    super.key,
    this.pendingClause,
    this.pendingCount = 0,
    this.fallbackMessage,
    this.fallbackActionable = false,
    this.isConfirming = false,
    this.onConfirm,
  });

  final Clause? pendingClause;
  final int pendingCount;
  final String? fallbackMessage;
  final bool fallbackActionable;
  final bool isConfirming;
  final void Function(String classification)? onConfirm;

  Future<void> _confirm(BuildContext context, String classification) async {
    final isClause = classification == 'CLAUSE';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isClause ? 'Confirmar cláusulazo' : 'Confirmar acuerdo'),
        content: Text(
          isClause
              ? '¿Confirmas que este movimiento fue un cláusulazo? Se registrará en la actividad y activará el enfriamiento de 7 días.'
              : '¿Confirmas que fue un acuerdo pactado entre managers? No ocupará ninguna plaza.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Volver'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmed == true) onConfirm?.call(classification);
  }

  @override
  Widget build(BuildContext context) {
    final clause = pendingClause;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PulsingDot(color: AppColors.dangerRed, size: 10),
              const SizedBox(width: 8),
              Text(
                'IMPORTANTE',
                style: AppTextStyles.mono(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.dangerRed)
                    .copyWith(letterSpacing: 1.4),
              ),
              const Spacer(),
              if (pendingCount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(4)),
                  child: Text(
                    pendingCount == 1
                        ? '1 pendiente'
                        : '$pendingCount pendientes',
                    style: AppTextStyles.mono(
                        fontSize: 10, color: AppColors.dangerRed),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (clause != null)
            _PendingClausePanel(
              clause: clause,
              isConfirming: isConfirming,
              onClause: () => _confirm(context, 'CLAUSE'),
              onAgreed: () => _confirm(context, 'AGREED'),
            )
          else
            InkWell(
              onTap: fallbackActionable ? () => context.go('/activity') : null,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        fallbackMessage ?? '',
                        style: AppTextStyles.body(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (fallbackActionable)
                      const Icon(Icons.chevron_right_rounded,
                          color: AppColors.dangerRed),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PendingClausePanel extends StatelessWidget {
  const _PendingClausePanel({
    required this.clause,
    required this.isConfirming,
    required this.onClause,
    required this.onAgreed,
  });

  final Clause clause;
  final bool isConfirming;
  final VoidCallback onClause;
  final VoidCallback onAgreed;

  @override
  Widget build(BuildContext context) {
    final from = clause.fromUser?.name ?? 'un manager';
    final to = clause.toUser?.name ?? 'un manager';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PlayerAvatar(
                imageUrl: clause.playerImageUrl,
                size: 48,
                iconSize: 22,
                backgroundColor: AppColors.surfaceElevated,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clause.displayPlayerName,
                      style: AppTextStyles.headline(fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Traspaso: $from → $to',
                      style: AppTextStyles.body(
                          fontSize: 12, color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (clause.amount != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        AmountFormatter.format(clause.amount!),
                        style: AppTextStyles.mono(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryGreen),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isConfirming)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onClause,
                    icon: const Icon(Icons.bolt_rounded, size: 16),
                    label: const Text('FUE CLAUSULAZO'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      textStyle: AppTextStyles.headline(fontSize: 11)
                          .copyWith(letterSpacing: 0.4),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onAgreed,
                    icon: const Icon(Icons.handshake, size: 16),
                    label: const Text('ACUERDO PACTADO'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      textStyle: AppTextStyles.headline(fontSize: 11)
                          .copyWith(letterSpacing: 0.4),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
