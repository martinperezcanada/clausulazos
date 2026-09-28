import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// The app's standard SnackBar for short status messages (same spot as Material's default: bottom,
/// floating, auto-dismiss).
///
/// One notice at a time, no queue: while one is visible, requests for another are ignored.
class AppSnackBar {
  AppSnackBar._();

  // The notice on screen and the messenger showing it; cleared when it closes for any reason (timeout,
  // swipe, navigation).
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _visible;
  static ScaffoldMessengerState? _visibleMessenger;

  static void show(
    BuildContext context, {
    required String message,
    IconData icon = Icons.info_outline_rounded,
    Color? iconColor,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    if (_visible != null && identical(_visibleMessenger, messenger)) return;

    final controller = messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceElevated,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.divider),
        ),
        content: Row(
          children: [
            Icon(icon, size: 18, color: iconColor ?? AppColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.body(
                    fontSize: 13, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
    _visible = controller;
    _visibleMessenger = messenger;
    controller.closed.whenComplete(() {
      if (identical(_visible, controller)) {
        _visible = null;
        _visibleMessenger = null;
      }
    });
  }
}
