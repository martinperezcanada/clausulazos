import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user.dart';
import '../../providers/admin_mode_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/clause_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/filter_pill.dart';
import '../../widgets/player_card.dart';

enum _ManagerFilter { all, available, full }

extension on _ManagerFilter {
  String get label {
    switch (this) {
      case _ManagerFilter.all:
        return 'Todos';
      case _ManagerFilter.available:
        return 'Con cupo';
      case _ManagerFilter.full:
        return 'Blindados';
    }
  }

  bool matches(AppUser player) {
    final receivedFull = player.stats?.received.isComplete ?? false;
    switch (this) {
      case _ManagerFilter.all:
        return true;
      case _ManagerFilter.available:
        return !receivedFull;
      case _ManagerFilter.full:
        return receivedFull;
    }
  }
}

class PlayersScreen extends StatefulWidget {
  const PlayersScreen({super.key});

  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  _ManagerFilter _filter = _ManagerFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProvider>().refreshAll();
      context.read<ClauseProvider>().loadHistory();
      // Harmless for non-admins: the route is AdminGuard-protected and this fails silently (see
      // UserProvider.loadPendingUsers()).
      context.read<UserProvider>().loadPendingUsers();
    });
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _approve(String userId) async {
    final ok = await context.read<UserProvider>().approveUser(userId);
    if (ok && mounted) {
      await context.read<UserProvider>().refreshAll();
    }
  }

  Future<void> _reject(String userId) async {
    await context.read<UserProvider>().rejectUser(userId);
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final clauseProvider = context.watch<ClauseProvider>();
    final authProvider = context.watch<AuthProvider>();
    final isAdminMode = context.watch<AdminModeProvider>().isAdminMode;
    final myId = authProvider.currentUser?.id;
    final myName = authProvider.currentUser?.name ?? '';
    final hasPending = myId == null
        ? false
        : clauseProvider.history.any((c) => c.needsConfirmationFrom(myId));

    final filtered = userProvider.players
        .where(_filter.matches)
        .where((p) => _query.isEmpty || p.name.toLowerCase().contains(_query))
        .toList();

    // Per-filter counts, shown in the count badge of each filter chip.
    final filterCounts = {
      for (final option in _ManagerFilter.values)
        option: userProvider.players.where(option.matches).length,
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () => Future.wait([
          context.read<UserProvider>().refreshAll(),
          context.read<UserProvider>().loadPendingUsers(),
        ]),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: AppColors.background,
              elevation: 0,
              scrolledUnderElevation: 6,
              shadowColor: Colors.black,
              surfaceTintColor: Colors.transparent,
              toolbarHeight: 64,
              titleSpacing: 20,
              automaticallyImplyLeading: false,
              title: AppTopBar(userName: myName, hasPending: hasPending),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: Text('Managers',
                                style: AppTextStyles.headline(fontSize: 22))),
                        IconButton(
                          tooltip: 'Clasificación de la liga',
                          icon: const Icon(Icons.leaderboard_rounded,
                              color: AppColors.textSecondary),
                          onPressed: () => context.push('/standings'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (isAdminMode && userProvider.pendingUsers.isNotEmpty)
              SliverToBoxAdapter(
                child: _PendingApprovalsSection(
                  pendingUsers: userProvider.pendingUsers,
                  onApprove: _approve,
                  onReject: _reject,
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar manager…',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () => _searchController.clear(),
                          ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 40,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: _ManagerFilter.values.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final option = _ManagerFilter.values[index];
                    return FilterPill(
                      label: option.label,
                      count: filterCounts[option],
                      selected: option == _filter,
                      onTap: () => setState(() => _filter = option),
                    );
                  },
                ),
              ),
            ),
            if (userProvider.isLoading && userProvider.players.isEmpty)
              const SliverToBoxAdapter(child: _ManagersSkeleton())
            else if (filtered.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                  child: Center(
                    child: Text(
                      userProvider.players.isEmpty
                          ? 'Todavía no hay otros managers en la liga.'
                          : 'Ningún manager coincide con la búsqueda.',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: EdgeInsets.only(top: index == 0 ? 0 : 12),
                      child: PlayerCard(
                        player: filtered[index],
                        onTap: () =>
                            context.push('/managers/${filtered[index].id}'),
                      ),
                    ),
                    childCount: filtered.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Admin-only, between the header and the search bar; same card style as the rest of Managers. Each
/// row is an account still `PENDING` (`UserProvider.pendingUsers`, from `GET /users/pending`);
/// approving or rejecting calls the backend.
class _PendingApprovalsSection extends StatelessWidget {
  const _PendingApprovalsSection({
    required this.pendingUsers,
    required this.onApprove,
    required this.onReject,
  });

  final List<AppUser> pendingUsers;
  final void Function(String userId) onApprove;
  final void Function(String userId) onReject;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.dangerRed.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.how_to_reg_rounded,
                    size: 16, color: AppColors.dangerRed),
                const SizedBox(width: 8),
                Text(
                  'PENDIENTES DE APROBACIÓN',
                  style: AppTextStyles.mono(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.dangerRed)
                      .copyWith(letterSpacing: 0.6),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < pendingUsers.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _PendingUserRow(
                user: pendingUsers[i],
                onApprove: () => onApprove(pendingUsers[i].id),
                onReject: () => onReject(pendingUsers[i].id),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PendingUserRow extends StatelessWidget {
  const _PendingUserRow({
    required this.user,
    required this.onApprove,
    required this.onReject,
  });

  final AppUser user;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(user.name,
                style: AppTextStyles.headline(fontSize: 14),
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: AppColors.dangerRed,
              side: BorderSide(color: AppColors.dangerRed.withOpacity(0.5)),
            ),
            onPressed: onReject,
            child: const Text('Rechazar', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 6),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.black,
            ),
            onPressed: onApprove,
            child: const Text('Aprobar', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _ManagersSkeleton extends StatelessWidget {
  const _ManagersSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        children: List.generate(
          5,
          (index) => Container(
            height: 148,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}
