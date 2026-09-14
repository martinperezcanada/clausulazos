import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
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
                        overLimitCategory: 'realizados',
                      ),
                      const SizedBox(height: 14),
                      StatCard(
                        title: 'Cláusulazos recibidos',
                        stats: stats.received,
                        availableLabelBuilder: (n) => 'Puedes recibir $n más',
                        overLimitCategory: 'recibidos',
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
