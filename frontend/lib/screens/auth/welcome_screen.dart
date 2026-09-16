import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/primary_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 3),
              const Text('🔥', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 16),
              Text(
                'CLAUSULAZOS',
                style: AppTextStyles.headline(fontSize: 34).copyWith(letterSpacing: 1.5),
              ),
              const SizedBox(height: 10),
              const Text(
                'Gestiona los cláusulazos de tu liga.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
              ),
              const Spacer(flex: 4),
              PrimaryButton(
                label: 'Iniciar sesión',
                onPressed: () => context.push('/login'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.push('/register'),
                child: const SizedBox(
                  width: double.infinity,
                  child: Text('Crear cuenta', textAlign: TextAlign.center),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
