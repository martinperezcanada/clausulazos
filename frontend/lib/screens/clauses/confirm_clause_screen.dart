import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/release_time_formatter.dart';
import '../../providers/auth_provider.dart';
import '../../providers/clause_provider.dart';
import '../../providers/user_provider.dart';
import '../../models/user.dart';
import '../../widgets/primary_button.dart';

class ConfirmClauseScreen extends StatelessWidget {
  const ConfirmClauseScreen({super.key, required this.player});

  final AppUser player;

  Future<void> _confirm(BuildContext context) async {
    final clauseProvider = context.read<ClauseProvider>();
    final clause = await clauseProvider.makeClause(player.id);
    if (!context.mounted) return;

    if (clause == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(clauseProvider.errorMessage ?? 'No se ha podido realizar el cláusulazo')),
      );
      return;
    }

    await context.read<UserProvider>().refreshAll();
    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔥', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            const Text('¡CLÁUSULAZO REALIZADO!',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Text('${context.read<AuthProvider>().currentUser?.name ?? ''} → ${player.name}'),
            const SizedBox(height: 8),
            Text(
              'Tu plaza se liberará el ${ReleaseTimeFormatter.fullDateTime(clause.expiresAt)}.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (context.mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final clauseProvider = context.watch<ClauseProvider>();
    final myName = context.watch<AuthProvider>().currentUser?.name ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Confirmar cláusulazo')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🔥', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 16),
            Text(myName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Icon(Icons.arrow_downward_rounded, color: AppColors.textSecondary),
            Text(player.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Text('Vas a realizar un cláusulazo a ${player.name}.', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            const Text(
              'El cláusulazo ocupará tu plaza de realizados y la plaza de recibidos de tu rival, durante 7 días.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const Spacer(),
            if (clauseProvider.errorMessage != null) ...[
              Text(clauseProvider.errorMessage!, style: const TextStyle(color: AppColors.dangerRed)),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.pop(),
                    child: const Text('CANCELAR'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: PrimaryButton(
                    label: 'CONFIRMAR CLAUSULAZO',
                    isLoading: clauseProvider.isSubmitting,
                    onPressed: () => _confirm(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
