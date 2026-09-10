import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/primary_button.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProvider>().refreshAll();
    });
  }

  Future<void> _logout(BuildContext context) async {
    await context.read<AuthProvider>().logout();
    if (context.mounted) context.go('/welcome');
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final userProvider = context.watch<UserProvider>();
    final user = authProvider.currentUser;
    final stats = userProvider.myStats;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.surfaceElevated,
                child: Text(
                  (user?.name.isNotEmpty ?? false) ? user!.name[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 28, color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              Text(user?.name ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(user?.email ?? '', style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 28),
              if (stats != null) ...[
                _StatRow(label: 'REALIZADOS', value: '${stats.performed.active} / ${stats.performed.limit} activos'),
                const SizedBox(height: 12),
                _StatRow(label: 'RECIBIDOS', value: '${stats.received.active} / ${stats.received.limit} activos'),
              ],
              const Spacer(),
              PrimaryButton(label: 'Cerrar sesión', onPressed: () => _logout(context)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
