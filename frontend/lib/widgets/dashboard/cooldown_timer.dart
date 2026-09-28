import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// The 7-day cooldown as a progress bar, computed from the clause's `createdAt`/`expiresAt`.
class CooldownTimer extends StatelessWidget {
  const CooldownTimer(
      {super.key, required this.createdAt, required this.expiresAt});

  final DateTime createdAt;
  final DateTime expiresAt;

  @override
  Widget build(BuildContext context) {
    final totalMs = expiresAt.difference(createdAt).inMilliseconds;
    final elapsedMs = DateTime.now().difference(createdAt).inMilliseconds;
    final progress = totalMs <= 0 ? 1.0 : (elapsedMs / totalMs).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: progress,
        minHeight: 6,
        backgroundColor: AppColors.background,
        valueColor: const AlwaysStoppedAnimation(AppColors.primaryGreen),
      ),
    );
  }
}
