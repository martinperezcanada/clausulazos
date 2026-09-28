import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_theme.dart';
import 'app_snack_bar.dart';
import 'dashboard/pulsing_dot.dart';

/// The app's top bar. On a bottom-nav tab root it shows the brand, a notifications bell (its dot
/// reflects pending confirmations) and the user's avatar; on a pushed detail screen (`showBack: true`) a
/// back button and a title. Meant to sit inside a pinned `SliverAppBar`.
class AppTopBar extends StatelessWidget {
  const AppTopBar({
    super.key,
    this.userName = '',
    this.hasPending = false,
    this.title,
    this.showBack = false,
    this.onBack,
  });

  final String userName;
  final bool hasPending;
  final String? title;
  final bool showBack;

  /// Where the back arrow goes (only used when [showBack] is true). Uses `context.go(...)` instead of
  /// `pop()` because every screen route is wrapped in `PopScope(canPop: false)` (see `app_router.dart`),
  /// which would block `pop()` too.
  final VoidCallback? onBack;

  String get _initials {
    final trimmed = userName.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    final first = parts.first.isNotEmpty ? parts.first[0] : '';
    final second =
        parts.length > 1 && parts.last.isNotEmpty ? parts.last[0] : '';
    final initials = (first + second).toUpperCase();
    return initials.isEmpty ? '?' : initials;
  }

  @override
  Widget build(BuildContext context) {
    if (showBack) {
      return Row(
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            onPressed: onBack ?? () => context.go('/home'),
            icon: const Icon(Icons.arrow_back_rounded,
                color: AppColors.textPrimary),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title ?? '',
              style: AppTextStyles.headline(fontSize: 17),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Text(
          title ?? 'CLAUSULAZOS',
          style: AppTextStyles.headline(
                  fontSize: 20, color: AppColors.primaryGreen)
              .copyWith(letterSpacing: 0.4),
        ),
        const Spacer(),
        _NotificationBell(hasPending: hasPending),
        const SizedBox(width: 2),
        _ProfileAvatar(initials: _initials),
      ],
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.hasPending});

  final bool hasPending;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.notifications_none_rounded,
                color: AppColors.textSecondary, size: 22),
            onPressed: () {
              if (hasPending) {
                context.go('/activity');
              } else {
                AppSnackBar.show(
                  context,
                  message: 'No tienes notificaciones nuevas.',
                  icon: Icons.notifications_off_outlined,
                );
              }
            },
          ),
          if (hasPending)
            const Positioned(
              top: 9,
              right: 9,
              child: PulsingDot(color: AppColors.primaryGreen, size: 8),
            ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Center(
        child: InkWell(
          onTap: () => context.go('/profile'),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
                color: AppColors.surfaceElevated, shape: BoxShape.circle),
            child: Text(initials,
                style: AppTextStyles.mono(
                    fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}
