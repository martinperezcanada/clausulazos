import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/app_top_bar.dart';

/// Placeholder admin screen; it has no functionality yet.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: AppTopBar(
          showBack: true,
          title: 'Panel de Administración',
          onBack: () => context.go('/home'),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.admin_panel_settings_rounded,
                    color: AppColors.primaryGreen, size: 28),
              ),
              const SizedBox(height: 16),
              Text('Panel de Administración',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headline(fontSize: 18)),
              const SizedBox(height: 8),
              Text(
                'Próximamente',
                textAlign: TextAlign.center,
                style: AppTextStyles.mono(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
