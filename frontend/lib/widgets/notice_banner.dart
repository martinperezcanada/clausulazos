import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/notifications/expiration_notices.dart';

class NoticeBanner extends StatelessWidget {
  const NoticeBanner({super.key, required this.notice});

  final ExpirationNotice notice;

  @override
  Widget build(BuildContext context) {
    final color = notice.isJustReleased ? AppColors.primaryGreen : AppColors.textPrimary;
    final icon = notice.isJustReleased ? Icons.lock_open_rounded : Icons.notifications_active_rounded;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: notice.isJustReleased ? AppColors.primaryGreen.withOpacity(0.4) : AppColors.divider,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              notice.message,
              style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
