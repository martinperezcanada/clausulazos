import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/amount_formatter.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/cooldown_formatter.dart';
import '../core/theme/relative_time_formatter.dart';
import '../core/theme/release_time_formatter.dart';
import '../models/clause.dart';
import '../providers/clause_provider.dart';
import 'app_snack_bar.dart';
import 'dashboard/pulsing_dot.dart';

/// A movement in the Activity feed or a manager's history: a colored tag bar (type of movement,
/// relative time), player and route, amount, and a bottom area that depends on the state (cooldown
/// remaining, the "avisar a..." reminder, or the confirm actions when it's this user's turn).
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
      BuildContext context, String classification) async {
    final isClause = classification == 'CLAUSE';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(isClause ? 'Confirmar cláusulazo' : 'Confirmar acuerdo'),
          content: Text(
            isClause
                ? '¿Estás seguro de que quieres confirmar este movimiento como cláusulazo? Esta elección se registrará en la actividad.'
                : '¿Estás seguro de que quieres confirmar este movimiento como acuerdo? Esta elección se registrará en la actividad.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Volver'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child:
                  Text(isClause ? 'Confirmar cláusulazo' : 'Confirmar acuerdo'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) onConfirm?.call(classification);
  }

  Future<void> _remind(BuildContext context) async {
    final provider = context.read<ClauseProvider>();
    final result = await provider.remindParticipant(clause.id);
    if (!context.mounted) return;
    // Success is shown only when the backend confirms the push reached a device (`result.success`); an
    // unsent reminder (e.g. `NO_DEVICE`) or a failed request shows its own outcome.
    if (result != null && result.success) {
      AppSnackBar.show(
        context,
        message: 'Notificación enviada',
        icon: Icons.check_circle_outline_rounded,
        iconColor: AppColors.primaryGreen,
      );
    } else if (result != null && result.reason == 'NO_DEVICE') {
      AppSnackBar.show(
        context,
        message:
            'Aviso registrado, pero ese manager no tiene notificaciones activadas en su dispositivo.',
        icon: Icons.notifications_off_outlined,
        iconColor: AppColors.textSecondary,
      );
    } else {
      AppSnackBar.show(
        context,
        message: provider.errorMessage ?? 'No se ha podido enviar el aviso.',
        icon: Icons.error_outline_rounded,
        iconColor: AppColors.dangerRed,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isPending = clause.classification == ClauseClassification.pending;
    final isAgreed = clause.classification == ClauseClassification.agreed;
    final isActive = clause.isActiveAt(now);
    final isCancelled = clause.status == ClauseStatus.cancelled;

    final canConfirm = onConfirm != null &&
        currentUserId != null &&
        clause.needsConfirmationFrom(currentUserId!);

    final isParticipant = currentUserId != null &&
        (clause.fromUserId == currentUserId ||
            clause.toUserId == currentUserId);

    // Whoever's confirmation is missing, from this viewer's perspective: decides whether to show "Avisar
    // a..." and whom it names.
    String? otherParticipantId;
    String? otherParticipantName;
    if (isPending && isParticipant && !canConfirm) {
      final iAmFromUser = clause.fromUserId == currentUserId;
      otherParticipantId = iAmFromUser ? clause.toUserId : clause.fromUserId;
      otherParticipantName =
          iAmFromUser ? clause.toUser?.name : clause.fromUser?.name;
    }
    final canRemind = otherParticipantId != null &&
        clause.needsConfirmationFrom(otherParticipantId);

    final tag = _tagFor(
        isPending: isPending,
        isAgreed: isAgreed,
        isActive: isActive,
        isCancelled: isCancelled);
    final from = clause.fromUser?.name ?? 'un manager';
    final to = clause.toUser?.name ?? 'un manager';
    final isReminding = context.select<ClauseProvider, bool>(
        (p) => p.remindingIds.contains(clause.id));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: isPending
            ? Border.all(color: AppColors.dangerRed.withOpacity(0.35))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tag.neutralBg
                      ? AppColors.surfaceElevated
                      : tag.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (tag.pulsing) ...[
                      PulsingDot(color: tag.color, size: 6),
                      const SizedBox(width: 5),
                    ] else ...[
                      Icon(tag.icon, size: 13, color: tag.color),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      tag.label,
                      style: AppTextStyles.mono(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: tag.color)
                          .copyWith(letterSpacing: 0.6),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                RelativeTimeFormatter.describe(clause.createdAt),
                style: AppTextStyles.mono(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: AppColors.surfaceHighest,
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.sports_soccer_rounded,
                    color: AppColors.textSecondary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clause.displayPlayerName,
                      style: AppTextStyles.headline(fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            from,
                            style: AppTextStyles.body(
                                fontSize: 12, color: AppColors.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(Icons.arrow_forward_rounded,
                            size: 12, color: tag.color),
                        Flexible(
                          child: Text(
                            to,
                            style: AppTextStyles.body(
                                fontSize: 12, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (clause.amount != null) ...[
                const SizedBox(width: 8),
                Text(
                  AmountFormatter.format(clause.amount!),
                  style: AppTextStyles.mono(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: tag.color),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          if (canConfirm)
            isConfirming
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Center(
                        child: SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _showConfirmationDialog(context, 'CLAUSE'),
                          icon: const Icon(Icons.bolt_rounded, size: 16),
                          label: const Text('Cláusulazo'),
                          style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _showConfirmationDialog(context, 'AGREED'),
                          icon: const Icon(Icons.handshake, size: 16),
                          label: const Text('Acuerdo'),
                          style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10)),
                        ),
                      ),
                    ],
                  )
          else if (canRemind)
            _RemindRow(
              recipientName: otherParticipantName ?? 'el otro participante',
              isSending: isReminding,
              onTap: () => _remind(context),
            )
          else
            _Ribbon(
                isAgreed: isAgreed,
                isActive: isActive,
                isCancelled: isCancelled,
                isPending: isPending,
                clause: clause),
        ],
      ),
    );
  }

  _ClauseTag _tagFor({
    required bool isPending,
    required bool isAgreed,
    required bool isActive,
    required bool isCancelled,
  }) {
    if (isPending) {
      return const _ClauseTag(
        label: 'ESPERANDO CONFIRMACIÓN',
        color: AppColors.dangerRed,
        icon: Icons.error_outline_rounded,
        pulsing: true,
        neutralBg: true,
      );
    }
    if (isAgreed) {
      return const _ClauseTag(
          label: 'ACUERDO PACTADO',
          color: AppColors.infoBlue,
          icon: Icons.handshake);
    }
    if (isCancelled) {
      return const _ClauseTag(
          label: 'CANCELADO',
          color: AppColors.textSecondary,
          icon: Icons.block_rounded);
    }
    if (isActive) {
      return const _ClauseTag(
          label: 'CLÁUSULAZO CONFIRMADO',
          color: AppColors.primaryGreen,
          icon: Icons.bolt_rounded);
    }
    return const _ClauseTag(
        label: 'CLÁUSULAZO',
        color: AppColors.textSecondary,
        icon: Icons.bolt_rounded);
  }
}

class _ClauseTag {
  const _ClauseTag({
    required this.label,
    required this.color,
    required this.icon,
    this.pulsing = false,
    this.neutralBg = false,
  });
  final String label;
  final Color color;
  final IconData icon;
  final bool pulsing;

  /// True for the pending tag: neutral badge background with colored text/dot, unlike the tinted
  /// background of the resolved states.
  final bool neutralBg;
}

/// The "Avisar a..." action; the recipient name comes from the clause participants.
class _RemindRow extends StatelessWidget {
  const _RemindRow(
      {required this.recipientName,
      required this.isSending,
      required this.onTap});

  final String recipientName;
  final bool isSending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: AppColors.dangerRed.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: isSending ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isSending)
                  const SizedBox(
                    height: 14,
                    width: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.dangerRed),
                  )
                else
                  const Icon(Icons.campaign_rounded,
                      size: 16, color: AppColors.dangerRed),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'AVISAR A ${recipientName.toUpperCase()}',
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.mono(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.dangerRed)
                        .copyWith(letterSpacing: 0.6),
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

class _Ribbon extends StatelessWidget {
  const _Ribbon({
    required this.isPending,
    required this.isAgreed,
    required this.isActive,
    required this.isCancelled,
    required this.clause,
  });

  final bool isPending;
  final bool isAgreed;
  final bool isActive;
  final bool isCancelled;
  final Clause clause;

  @override
  Widget build(BuildContext context) {
    late final IconData icon;
    late final String text;
    Widget? trailing;

    if (isPending) {
      icon = Icons.hourglass_empty_rounded;
      text = 'Pendiente de confirmar por ambos participantes';
    } else if (isAgreed) {
      icon = Icons.verified_user_rounded;
      text = 'No computa para el límite de cláusulas';
    } else if (isCancelled) {
      icon = Icons.block_rounded;
      text = 'Cancelado';
    } else if (isActive) {
      icon = Icons.shield_rounded;
      text = 'Blindaje activo';
      trailing = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: AppColors.surfaceHighest,
            borderRadius: BorderRadius.circular(6)),
        child: Text(
          'Libera en ${CooldownFormatter.remaining(clause.expiresAt)}',
          style: AppTextStyles.mono(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryGreen),
        ),
      );
    } else {
      icon = Icons.history_rounded;
      text = 'Liberado: ${ReleaseTimeFormatter.fullDateTime(clause.expiresAt)}';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
          color: AppColors.background, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.body(
                  fontSize: 12, color: AppColors.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
        ],
      ),
    );
  }
}
