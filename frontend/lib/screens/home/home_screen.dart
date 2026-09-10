import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/release_time_formatter.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/stat_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// WidgetsBindingObserver lets us refresh data when the app comes back to
// the foreground (rule #35: a slot might have expired while backgrounded).
class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() => context.read<UserProvider>().refreshAll();

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final authProvider = context.watch<AuthProvider>();
    final stats = userProvider.myStats;
    final name = authProvider.currentUser?.name ?? userProvider.me?.name ?? '';

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: userProvider.isLoading && stats == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      'Hola, $name 👋',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    if (stats != null) ...[
                      StatCard(
                        title: 'Cláusulazos realizados',
                        stats: stats.performed,
                        availableLabelBuilder: (n) => 'Puedes hacer $n más',
                      ),
                      const SizedBox(height: 14),
                      StatCard(
                        title: 'Cláusulazos recibidos',
                        stats: stats.received,
                        availableLabelBuilder: (n) => 'Puedes recibir $n más',
                      ),
                      const SizedBox(height: 24),
                      if (stats.performed.isComplete)
                        LockedButton(
                          title: 'Has utilizado tus 2 plazas.',
                          subtitle: stats.performed.nextReleaseAt != null
                              ? 'Primera plaza disponible: ${ReleaseTimeFormatter.fullDateTime(stats.performed.nextReleaseAt!)}'
                              : null,
                        )
                      else
                        PrimaryButton(
                          label: 'HACER CLAUSULAZO',
                          icon: Icons.local_fire_department_rounded,
                          onPressed: () => context.push('/select-player'),
                        ),
                    ],
                    if (userProvider.errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(userProvider.errorMessage!, style: const TextStyle(color: AppColors.dangerRed)),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
