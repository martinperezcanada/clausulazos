import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// The "x/y Activas" pill at the top of Inicio's "Cláusulas Ejecutadas" and "Cláusulas Recibidas" cards.
/// `active`/`limit` come from the same `SlotStats` Managers shows (backend `getStatsForUser`), so both
/// screens always agree. The count reads first and slightly stronger than the label. With every slot
/// taken (`active >= limit`) it turns red.
class ActiveCountBadge extends StatelessWidget {
  const ActiveCountBadge(
      {super.key, required this.active, required this.limit});

  final int active;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final isFull = active >= limit;
    final textColor = isFull ? AppColors.dangerRed : AppColors.textPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (isFull ? AppColors.dangerRed : AppColors.infoBlue)
            .withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text.rich(
        TextSpan(
          text: '$active/$limit',
          style: AppTextStyles.mono(
              fontSize: 12, fontWeight: FontWeight.w800, color: textColor),
          children: [
            TextSpan(
              text: ' Activas',
              style: AppTextStyles.mono(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: textColor.withValues(alpha: 0.75)),
            ),
          ],
        ),
        textAlign: TextAlign.center,
        textHeightBehavior: const TextHeightBehavior(
            applyHeightToFirstAscent: false, applyHeightToLastDescent: false),
      ),
    );
  }
}
