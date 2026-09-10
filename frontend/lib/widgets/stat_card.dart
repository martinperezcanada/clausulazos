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
  });

  final String title;
  final SlotStats stats;
  final String Function(int available) availableLabelBuilder;

  @override
  Widget build(BuildContext context) {
    final isComplete = stats.isComplete;

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
                    '${stats.active} / ${stats.limit}',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
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
            ],
          ),
        ),
      ),
    );
  }
}
