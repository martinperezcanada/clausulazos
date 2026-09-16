import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/clause.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/clause_provider.dart';
import '../../repositories/user_repository.dart';
import '../../widgets/clause_card.dart';
import '../../widgets/stat_card.dart';

/// Public profile for a league manager — reachable by tapping a card in
/// the Managers list. Deliberately never shows email, password, or any
/// other private/sensitive field: name + clause stats + relevant history
/// only.
class ManagerDetailScreen extends StatefulWidget {
  const ManagerDetailScreen({super.key, required this.managerId});

  final String managerId;

  @override
  State<ManagerDetailScreen> createState() => _ManagerDetailScreenState();
}

class _ManagerDetailScreenState extends State<ManagerDetailScreen> {
  AppUser? _manager;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = context.read<UserRepository>();
      final manager = await repo.fetchUser(widget.managerId);
      if (!mounted) return;
      setState(() => _manager = manager);
      // eslint-ish: also make sure the history is loaded so we can filter
      // it below — most of the time it's already cached from Home/Activity.
      await context.read<ClauseProvider>().loadHistory();
    } catch (e) {
      if (mounted) setState(() => _error = 'No se ha podido cargar este manager.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clauseProvider = context.watch<ClauseProvider>();
    final myId = context.watch<AuthProvider>().currentUser?.id;
    final manager = _manager;

    final relevantHistory = manager == null
        ? const []
        : clauseProvider.history
            .where((c) => c.fromUserId == manager.id || c.toUserId == manager.id)
            .take(10)
            .toList();

    return Scaffold(
      appBar: AppBar(title: Text(manager?.name ?? 'Manager')),
      body: _isLoading && manager == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && manager == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 12),
                      OutlinedButton(onPressed: _load, child: const Text('Reintentar')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: AppColors.surfaceElevated,
                            child: Text(
                              manager!.name.isNotEmpty ? manager.name[0].toUpperCase() : '?',
                              style: const TextStyle(fontSize: 24, color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              manager.name,
                              style: AppTextStyles.headline(fontSize: 22),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (manager.stats != null) ...[
                        StatCard(
                          title: 'Cláusulazos realizados',
                          stats: manager.stats!.performed,
                          availableLabelBuilder: (n) => 'Puede hacer $n más',
                          overLimitCategory: 'realizados',
                        ),
                        const SizedBox(height: 12),
                        StatCard(
                          title: 'Cláusulazos recibidos',
                          stats: manager.stats!.received,
                          availableLabelBuilder: (n) => 'Puede recibir $n más',
                          overLimitCategory: 'recibidos',
                        ),
                      ],
                      const SizedBox(height: 24),
                      Text(
                        'HISTORIAL RELEVANTE',
                        style: AppTextStyles.mono(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ).copyWith(letterSpacing: 1.4),
                      ),
                      const SizedBox(height: 10),
                      if (relevantHistory.isEmpty)
                        const Text('Sin movimientos todavía.', style: TextStyle(color: AppColors.textSecondary))
                      else
                        ...relevantHistory.map(
                          (c) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: ClauseCard(clause: c, currentUserId: myId),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}
