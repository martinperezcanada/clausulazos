import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/release_time_formatter.dart';
import '../models/user.dart';

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.title,
    required this.stats,
    required this.availableLabelBuilder,
    this.overLimitCategory,
  });

  final String title;
  final SlotStats stats;
  final String Function(int available) availableLabelBuilder;

  /// e.g. 'realizados' / 'recibidos' — used to build the over-limit warning
  /// text. Only needed when this card can ever show an excess; optional so
  /// this widget stays usable without it if ever reused elsewhere.
  final String? overLimitCategory;

  String? _overLimitMessage() {
    if (overLimitCategory == null) return null;
    final excess = stats.active - stats.limit;
    if (excess <= 0) return null;
    if (excess == 1) return 'Has superado el límite de cláusulazos $overLimitCategory.';
    return 'Has superado el límite por $excess cláusulazos.';
  }

  @override
  Widget build(BuildContext context) {
    final isComplete = stats.isComplete;
    final isExceeded = stats.isExceeded;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isExceeded ? '⚠️ ' : ''}${stats.active} / ${stats.limit}',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: isExceeded ? AppColors.dangerRed : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: List.generate(stats.limit, (i) {
                        final occupied = i < stats.active;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.only(right: 6),
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: occupied ? AppColors.dangerRed : AppColors.primaryGreen,
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (isComplete)
                Row(
                  children: const [
                    Icon(Icons.lock, size: 16, color: AppColors.dangerRed),
                    SizedBox(width: 6),
                    Text('COMPLETO', style: TextStyle(color: AppColors.dangerRed, fontWeight: FontWeight.bold)),
                  ],
                )
              else
                Text(
                  availableLabelBuilder(stats.available),
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
              if (stats.nextReleaseAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  ReleaseTimeFormatter.describe(stats.nextReleaseAt!),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
              if (isExceeded && _overLimitMessage() != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.dangerRed.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('⚠️', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _overLimitMessage()!,
                          style: const TextStyle(
                            color: AppColors.dangerRed,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
