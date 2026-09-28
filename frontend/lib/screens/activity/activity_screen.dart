import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/clause.dart';
import '../../models/fantasy_debt.dart';
import '../../providers/admin_mode_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/clause_provider.dart';
import '../../providers/user_provider.dart';
import '../../repositories/fantasy_repository.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/clause_card.dart';
import '../../widgets/filter_pill.dart';

enum _ActivityFilter { all, pending, clause, agreed }

extension on _ActivityFilter {
  String get label {
    switch (this) {
      case _ActivityFilter.all:
        return 'Todos';
      case _ActivityFilter.clause:
        return 'Cláusulazos';
      case _ActivityFilter.agreed:
        return 'Acuerdos';
      case _ActivityFilter.pending:
        return 'Pendientes';
    }
  }

  bool matches(Clause clause) {
    switch (this) {
      case _ActivityFilter.all:
        return true;
      case _ActivityFilter.clause:
        return clause.classification == ClauseClassification.clause;
      case _ActivityFilter.agreed:
        return clause.classification == ClauseClassification.agreed;
      case _ActivityFilter.pending:
        return clause.classification == ClauseClassification.pending;
    }
  }
}

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  _ActivityFilter _filter = _ActivityFilter.all;

  // "Jx · EN VIVO" / "Jx · PRÓXIMA" indicator, from the same `/fantasy/debts` data as Standings (see
  // `_WeekStatus.fromSnapshot`). Null until it loads; seeded with the last known value so it doesn't
  // vanish while re-fetching when the screen is re-entered.
  static _WeekStatus? _lastWeekStatus;
  _WeekStatus? _weekStatus = _lastWeekStatus;

  // True once the first `loadHistory()` of this visit has finished (successfully or not). Until then an
  // empty history means "still loading", not "no activity".
  bool _hasLoadedHistory = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHistory();
      _loadWeekStatus();
    });
  }

  Future<void> _loadHistory() async {
    await context.read<ClauseProvider>().loadHistory();
    if (mounted) setState(() => _hasLoadedHistory = true);
  }

  Future<void> _loadWeekStatus() async {
    try {
      final snapshot = await context.read<FantasyRepository>().fetchDebts();
      if (!mounted) return;
      final status = _WeekStatus.fromSnapshot(snapshot);
      _lastWeekStatus = status;
      setState(() => _weekStatus = status);
    } catch (_) {
      // Best effort: without it the indicator isn't shown (or keeps the last known value).
    }
  }

  Future<void> _confirm(String clauseId, String classification) async {
    final ok = await context
        .read<ClauseProvider>()
        .confirmClassification(clauseId, classification);
    if (ok && mounted) {
      await context.read<UserProvider>().refreshStatsOnly();
    }
  }

  // Admin-only: confirms first (never deletes on the swipe alone), then deletes before Dismissible
  // removes the widget, so a failed request snaps the card back instead of leaving an empty gap.
  Future<bool> _confirmAndDeleteAsAdmin(String clauseId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Eliminar movimiento?'),
        content: const Text(
            'Esta acción eliminará este movimiento de la actividad.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return false;

    final provider = context.read<ClauseProvider>();
    final ok = await provider.adminDeleteClause(clauseId);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(provider.errorMessage ??
                'No se ha podido eliminar el movimiento.')),
      );
    }
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    final clauseProvider = context.watch<ClauseProvider>();
    final isAdminMode = context.watch<AdminModeProvider>().isAdminMode;
    final myId = context.watch<AuthProvider>().currentUser?.id;
    final myName = context.watch<AuthProvider>().currentUser?.name ?? '';
    final filtered = clauseProvider.history.where(_filter.matches).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final hasPending = myId == null
        ? false
        : clauseProvider.history.any((c) => c.needsConfirmationFrom(myId));

    // "Historial Confirmado" divider only makes sense when the feed mixes
    // pending and resolved movements (the "Todos" filter).
    final firstConfirmedIndex = _filter == _ActivityFilter.all
        ? filtered
            .indexWhere((c) => c.classification != ClauseClassification.pending)
        : -1;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () => Future.wait([_loadHistory(), _loadWeekStatus()]),
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
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Actividad de Liga',
                        style: AppTextStyles.headline(fontSize: 20),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_weekStatus != null) ...[
                      const SizedBox(width: 8),
                      _WeekBadge(status: _weekStatus!),
                    ],
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 40,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: _ActivityFilter.values.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final option = _ActivityFilter.values[index];
                    final selected = option == _filter;
                    final count =
                        clauseProvider.history.where(option.matches).length;
                    return FilterPill(
                      label: option.label,
                      count: count,
                      selected: selected,
                      onTap: () => setState(() => _filter = option),
                    );
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 14)),
            // With nothing cached, an empty history means "still loading" (including the first frame, before
            // `loadHistory()` starts), not "no activity". With cached data the list stays visible while it
            // refreshes.
            if (clauseProvider.history.isEmpty &&
                (clauseProvider.isLoading || !_hasLoadedHistory))
              const SliverToBoxAdapter(child: _ActivitySkeleton())
            else if (filtered.isEmpty)
              SliverToBoxAdapter(
                child: _EmptyFeedCard(
                  hasAnyHistory: clauseProvider.history.isNotEmpty,
                  filterLabel: _filter.label,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final clause = filtered[index];
                      Widget card = ClauseCard(
                        clause: clause,
                        currentUserId: myId,
                        onConfirm: (classification) =>
                            _confirm(clause.id, classification),
                        isConfirming:
                            clauseProvider.confirmingIds.contains(clause.id),
                      );

                      // Admin-only swipe to delete; normal users get the plain card.
                      if (isAdminMode) {
                        card = Dismissible(
                          key: ValueKey('admin-delete-${clause.id}'),
                          direction: DismissDirection.endToStart,
                          background: const _DeleteSwipeBackground(),
                          confirmDismiss: (_) =>
                              _confirmAndDeleteAsAdmin(clause.id),
                          child: card,
                        );
                      }

                      if (index == firstConfirmedIndex && index > 0) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SectionDivider(label: 'HISTORIAL'),
                              const SizedBox(height: 10),
                              card,
                            ],
                          ),
                        );
                      }
                      return Padding(
                        padding: EdgeInsets.only(top: index == 0 ? 0 : 10),
                        child: card,
                      );
                    },
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

/// Which jornada Actividad points at and whether it's live or upcoming, derived from the
/// `/fantasy/debts` snapshot.
///
/// - `weeksEvaluated` is the highest jornada that has kicked off; `pendingWeeks` are started jornadas
///   still missing a finished match.
/// - EN VIVO: the latest started jornada is still pending. An older pending one (e.g. a postponed match)
///   is ignored once a later one has started.
/// - PRÓXIMA: otherwise, the jornada after the latest started one. It flips to EN VIVO once the backend
///   reports it started.
class _WeekStatus {
  const _WeekStatus({required this.week, required this.isLive});

  final int week;
  final bool isLive;

  // A LALIGA season has 38 jornadas; past the last one there is no "next".
  static const _lastSeasonWeek = 38;

  static _WeekStatus? fromSnapshot(FantasyDebtsSnapshot snapshot) {
    final started = snapshot.weeksEvaluated;
    // 0 = nothing known (empty or unusable response): show nothing.
    if (started <= 0) return null;
    if (snapshot.pendingWeeks.contains(started)) {
      return _WeekStatus(week: started, isLive: true);
    }
    final next = started + 1;
    if (next > _lastSeasonWeek) return null;
    return _WeekStatus(week: next, isLive: false);
  }
}

/// Jornada indicator next to "Actividad de Liga": green "EN VIVO" while a jornada is in progress, grey
/// "PRÓXIMA" otherwise.
class _WeekBadge extends StatelessWidget {
  const _WeekBadge({required this.status});

  final _WeekStatus status;

  @override
  Widget build(BuildContext context) {
    final live = status.isLive;
    final color = live ? AppColors.primaryGreen : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: live
            ? AppColors.primaryGreen.withOpacity(0.12)
            : AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'J${status.week} · ${live ? 'EN VIVO' : 'PRÓXIMA'}',
        style: AppTextStyles.mono(
                fontSize: 10, fontWeight: FontWeight.w700, color: color)
            .copyWith(letterSpacing: 0.5),
      ),
    );
  }
}

/// Revealed behind a `ClauseCard` while an admin drags it left; same radius and proportions as the card.
class _DeleteSwipeBackground extends StatelessWidget {
  const _DeleteSwipeBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
        color: AppColors.dangerRed.withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.delete_rounded, color: Colors.white, size: 24),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: AppTextStyles.mono(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)
              .copyWith(letterSpacing: 1.2),
        ),
        const SizedBox(width: 10),
        const Expanded(child: Divider(color: AppColors.divider, height: 1)),
      ],
    );
  }
}

class _EmptyFeedCard extends StatelessWidget {
  const _EmptyFeedCard(
      {required this.hasAnyHistory, required this.filterLabel});

  final bool hasAnyHistory;
  final String filterLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                  color: AppColors.surfaceElevated, shape: BoxShape.circle),
              child: const Icon(Icons.radar_rounded,
                  color: AppColors.primaryGreen, size: 22),
            ),
            const SizedBox(height: 12),
            Text(
              hasAnyHistory
                  ? 'Sin movimientos en "$filterLabel"'
                  : 'Mercado hipervigilado',
              style: AppTextStyles.headline(fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              hasAnyHistory
                  ? 'No hay cláusulazos en esta categoría todavía.'
                  : 'Te avisaremos aquí en cuanto se detecte un nuevo movimiento en tu liga.',
              style: AppTextStyles.body(
                  fontSize: 12, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivitySkeleton extends StatelessWidget {
  const _ActivitySkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        children: List.generate(
          5,
          (index) => Container(
            height: 110,
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
