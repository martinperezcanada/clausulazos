import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/notifications/expiration_notices.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/release_time_formatter.dart';
import '../../models/clause.dart';
import '../../providers/auth_provider.dart';
import '../../providers/clause_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/clause_card.dart';
import '../../widgets/notice_banner.dart';
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

  Future<void> _refresh() => Future.wait([
        context.read<UserProvider>().refreshAll(),
        context.read<ClauseProvider>().loadHistory(),
      ]);

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final clauseProvider = context.watch<ClauseProvider>();
    final authProvider = context.watch<AuthProvider>();
    final stats = userProvider.myStats;
    final name = authProvider.currentUser?.name ?? userProvider.me?.name ?? '';
    final myId = authProvider.currentUser?.id;

    final myClauses = myId == null
        ? const <Clause>[]
        : clauseProvider.history.where((c) => c.fromUserId == myId || c.toUserId == myId).toList();

    final notices = myId == null
        ? const <ExpirationNotice>[]
        : ExpirationNotices.build(clauses: myClauses, currentUserId: myId);

    final nextRelease = myClauses.where((c) => c.isActiveAt(DateTime.now())).toList()
      ..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));

    final recentMovements = myClauses.take(4).toList(); // history is already newest-first

    final isInitialLoading = userProvider.isLoading && stats == null;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: isInitialLoading
              ? const _HomeSkeleton()
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      'Hola, $name 👋',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    for (final notice in notices.take(3)) NoticeBanner(notice: notice),
                    if (notices.isNotEmpty) const SizedBox(height: 8),

                    if (stats != null) ...[
                      const _SectionLabel('MIS CLÁUSULAS'),
                      const SizedBox(height: 10),
                      StatCard(
                        title: 'Cláusulazos realizados',
                        stats: stats.performed,
                        availableLabelBuilder: (n) => 'Puedes hacer $n más',
                        overLimitCategory: 'realizados',
                      ),
                      const SizedBox(height: 12),
                      StatCard(
                        title: 'Cláusulazos recibidos',
                        stats: stats.received,
                        availableLabelBuilder: (n) => 'Puedes recibir $n más',
                        overLimitCategory: 'recibidos',
                      ),
                    ],

                    const SizedBox(height: 24),
                    const _SectionLabel('PRÓXIMA LIBERACIÓN'),
                    const SizedBox(height: 10),
                    if (nextRelease.isEmpty)
                      const _EmptyMiniCard(text: 'No tienes cláusulas activas ahora mismo.')
                    else
                      _NextReleaseCard(clause: nextRelease.first, myId: myId!),

                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const _SectionLabel('ÚLTIMOS MOVIMIENTOS'),
                        TextButton(
                          onPressed: () => context.go('/activity'),
                          child: const Text('Ver todo'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (clauseProvider.isLoading && myClauses.isEmpty)
                      const _EmptyMiniCard(text: 'Cargando movimientos…')
                    else if (recentMovements.isEmpty)
                      const _EmptyMiniCard(text: 'Todavía no hay movimientos.')
                    else
                      ...recentMovements.map(
                        (c) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ClauseCard(clause: c, currentUserId: myId),
                        ),
                      ),

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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.bold,
        fontSize: 12,
        letterSpacing: 1.1,
      ),
    );
  }
}

class _NextReleaseCard extends StatelessWidget {
  const _NextReleaseCard({required this.clause, required this.myId});

  final Clause clause;
  final String myId;

  @override
  Widget build(BuildContext context) {
    final isMine = clause.fromUserId == myId;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.surfaceElevated,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.sports_soccer, color: AppColors.primaryGreen),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    clause.displayPlayerName,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ReleaseTimeFormatter.dayAndTime(clause.expiresAt),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            Text(
              isMine ? 'Realizado' : 'Recibido',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyMiniCard extends StatelessWidget {
  const _EmptyMiniCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Text(text, style: const TextStyle(color: AppColors.textSecondary)),
    );
  }
}

/// Shown instead of a blank screen on first load (rule from section 10:
/// avoid empty screens while loading).
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget block(double height) => Container(
          height: height,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
        );

    return ListView(
      padding: const EdgeInsets.all(20),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        block(32),
        const SizedBox(height: 12),
        block(120),
        block(120),
        block(90),
        block(80),
        block(80),
      ],
    );
  }
}
