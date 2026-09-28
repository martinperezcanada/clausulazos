import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// Rounded filter chip with an inline count badge, shared by the screens that filter a list on the
/// client (Activity, Players).
class FilterPill extends StatelessWidget {
  const FilterPill(
      {super.key,
      required this.label,
      required this.selected,
      required this.onTap,
      this.count});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryGreen : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTextStyles.mono(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.black : AppColors.textSecondary,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.black.withOpacity(0.15)
                      : AppColors.surfaceHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: AppTextStyles.mono(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.black : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
