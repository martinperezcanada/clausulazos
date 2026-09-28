import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: constraints.maxHeight),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'REGLAMENTO',
                                style: AppTextStyles.mono(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary)
                                    .copyWith(letterSpacing: 1.4),
                              ),
                              const SizedBox(height: 10),
                              const _RuleCard(
                                icon: Icons.gavel_rounded,
                                title: 'Límite 2 / 2 Cláusulas',
                                subtitle:
                                    'Máximo ${AppConfig.maxActiveClauses} realizadas y ${AppConfig.maxActiveClauses} recibidas activas a la vez.',
                              ),
                              const SizedBox(height: 10),
                              const _RuleCard(
                                icon: Icons.timer_outlined,
                                title: 'Cuenta atrás',
                                subtitle:
                                    'Cada cláusulazo mantiene ocupado su hueco hasta que se libera automáticamente.',
                                badge: 'SIETE DÍAS',
                              ),
                              const SizedBox(height: 10),
                              const _RuleCard(
                                icon: Icons.sync_alt_rounded,
                                title: 'Sincronización automática',
                                subtitle:
                                    'Movimientos de LaLiga Fantasy pendientes de confirmar.',
                                badge: 'ACTIVO',
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => context.push('/register'),
                icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 2),
                  child: Text('Crear cuenta'),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => context.push('/login'),
                icon: const Icon(Icons.lock_open_rounded, size: 18),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 2),
                  child: Text('Iniciar sesión'),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.verified_user_rounded,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'Reglas de VICIO LF.',
                    style: AppTextStyles.mono(
                        fontSize: 10, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard(
      {required this.icon,
      required this.title,
      required this.subtitle,
      this.badge});

  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;

  static const double _height = 92;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _height,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: AppColors.primaryGreen, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTextStyles.headline(fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.body(
                          fontSize: 12, color: AppColors.textSecondary)
                      .copyWith(height: 1.15),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(4)),
              child: Text(
                badge!,
                style: AppTextStyles.mono(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryGreen),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
