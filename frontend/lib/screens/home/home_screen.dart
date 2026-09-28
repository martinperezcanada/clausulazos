import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/config/app_config.dart';
import '../../core/notifications/expiration_notices.dart';
import '../../core/theme/app_theme.dart';
import '../../models/clause.dart';
import '../../models/user.dart';
import '../../providers/admin_mode_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/clause_provider.dart';
import '../../providers/fantasy_sync_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/dashboard/executed_clause_card.dart';
import '../../widgets/dashboard/important_card.dart';
import '../../widgets/dashboard/received_clause_card.dart';
import '../../widgets/dashboard/sync_status_pill.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// WidgetsBindingObserver refreshes data when the app returns to the foreground (a slot may have
// expired in the meantime).
class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  // Alerts swiped away this session (`'<userId>|<alertId>'`). Static so it survives Inicio being rebuilt
  // on tab switches; cleared on the next app start.
  static final Set<String> _dismissedAlerts = <String>{};

  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    // Keeps the cooldown countdowns moving and re-fetches the sync status, so "Sincronizado hace X"
    // catches up with syncs done elsewhere (cron, another device, a manual /fantasy/sync) while this
    // screen is open.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) context.read<FantasySyncProvider>().load();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
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
        context.read<FantasySyncProvider>().load(),
      ]);

  Future<void> _confirmPending(String clauseId, String classification) async {
    final ok = await context
        .read<ClauseProvider>()
        .confirmClassification(clauseId, classification);
    if (ok && mounted) {
      await context.read<UserProvider>().refreshStatsOnly();
    }
  }

  // Mode switch on the signed-in account; never touches AuthProvider. Real authorization for admin
  // actions is the backend's `AdminGuard`; the confirmation dialog is only friction against an
  // accidental tap.
  Future<void> _handleAdminModeChanged(bool value) async {
    final provider = context.read<AdminModeProvider>();
    // Anyone but the admin account: nothing is unlocked and the switch stays on USUARIO, with a notice.
    // The check itself is `isAllowedAdmin`.
    if (value && !provider.isAllowedAdmin) {
      AppSnackBar.show(
        context,
        message: 'No estás autorizado para activar el modo Admin.',
        icon: Icons.admin_panel_settings_rounded,
        iconColor: AppColors.dangerRed,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(value ? 'Cambiar a administrador' : 'Cambiar a usuario'),
        content: Text(value
            ? '¿Quieres cambiar del modo usuario al modo administrador?'
            : '¿Quieres cambiar del modo administrador al modo usuario?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cambiar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Mode switch only; no navigation.
    provider.setAdminMode(value);
  }

  // Admin-only (see `SyncStatusPill.onTap`, wired up only in admin mode). Runs the same
  // `FantasySyncProvider.forceSync()` -> `GET /fantasy/sync` the cron calls.
  Future<void> _handleForceSync() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Forzar sincronización'),
        content: const Text('¿Quieres forzar la sincronización ahora?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sincronizar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final provider = context.read<FantasySyncProvider>();
    final ok = await provider.forceSync();
    if (!mounted) return;
    if (!ok) {
      AppSnackBar.show(
        context,
        message: provider.forceSyncError ?? 'La sincronización ha fallado.',
        icon: Icons.sync_problem_rounded,
        iconColor: AppColors.dangerRed,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final clauseProvider = context.watch<ClauseProvider>();
    final authProvider = context.watch<AuthProvider>();
    final syncProvider = context.watch<FantasySyncProvider>();
    final adminModeProvider = context.watch<AdminModeProvider>();
    final stats = userProvider.myStats;
    final name = authProvider.currentUser?.name ?? userProvider.me?.name ?? '';
    final myId = authProvider.currentUser?.id;
    final now = DateTime.now();

    final myClauses = myId == null
        ? const <Clause>[]
        : clauseProvider.history
            .where((c) => c.fromUserId == myId || c.toUserId == myId)
            .toList();

    final notices = myId == null
        ? const <ExpirationNotice>[]
        : ExpirationNotices.build(clauses: myClauses, currentUserId: myId);

    final pendingForMe = myId == null
        ? const <Clause>[]
        : (myClauses.where((c) => c.needsConfirmationFrom(myId)).toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt)));

    final activePerformed = myId == null
        ? const <Clause>[]
        : (myClauses
            .where((c) => c.fromUserId == myId && c.isActiveAt(now))
            .toList()
          ..sort((a, b) => a.expiresAt.compareTo(b.expiresAt)));

    final activeReceived = myId == null
        ? const <Clause>[]
        : (myClauses
            .where((c) => c.toUserId == myId && c.isActiveAt(now))
            .toList()
          ..sort((a, b) => a.expiresAt.compareTo(b.expiresAt)));

    // Alerts swiped away this session stay hidden (see `_dismissedAlerts`), so rebuilding or re-entering
    // Inicio doesn't bring them back.
    bool isDismissed(String alertId) =>
        _dismissedAlerts.contains('${myId ?? ''}|$alertId');
    final visiblePending =
        pendingForMe.where((c) => !isDismissed('pending:${c.id}')).toList();

    final importantClause =
        visiblePending.isEmpty ? null : visiblePending.first;
    final fallbackAlerts = _buildFallbackAlerts(stats, notices, isDismissed);
    final fallbackMessage = importantClause == null && fallbackAlerts.isNotEmpty
        ? fallbackAlerts.first
        : null;
    final importantAlertId = importantClause != null
        ? 'pending:${importantClause.id}'
        : fallbackMessage?.$3;
    // Alerts still waiting, the visible one included: more than one means a second card sits behind.
    final alertCount = visiblePending.length + fallbackAlerts.length;

    // The alert behind the main one, which becomes the main one when the current one is dismissed (same
    // order: pending clauses first, then fallback alerts).
    Clause? nextClause;
    (String, bool, String)? nextFallback;
    if (alertCount > 1) {
      if (visiblePending.length >= 2) {
        nextClause = visiblePending[1];
      } else if (visiblePending.length == 1) {
        nextFallback = fallbackAlerts.first;
      } else {
        nextFallback = fallbackAlerts[1];
      }
    }
    final nextAlertId =
        nextClause != null ? 'pending:${nextClause.id}' : nextFallback?.$3;

    final isInitialLoading = userProvider.isLoading && stats == null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: isInitialLoading
            ? const _HomeSkeleton()
            : CustomScrollView(
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
                    title: AppTopBar(
                        userName: name, hasPending: pendingForMe.isNotEmpty),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _AdminModeSwitch(
                              isAdminMode: adminModeProvider.isAdminMode,
                              onChanged: _handleAdminModeChanged,
                            ),
                          ),
                        ),
                        // IMPORTANTE alerts: the main card plus, when more wait, one card behind it. Swiping the main one
                        // away hands its slot to the card behind.
                        _ImportantAlertsDeck(
                          mainId: importantAlertId,
                          mainCard: importantAlertId == null
                              ? null
                              : ImportantCard(
                                  pendingClause: importantClause,
                                  pendingCount: visiblePending.length,
                                  fallbackMessage: fallbackMessage?.$1,
                                  fallbackActionable:
                                      fallbackMessage?.$2 ?? false,
                                  isConfirming: importantClause != null &&
                                      clauseProvider.confirmingIds
                                          .contains(importantClause.id),
                                  onConfirm: importantClause == null
                                      ? null
                                      : (classification) => _confirmPending(
                                          importantClause.id, classification),
                                ),
                          nextId: nextAlertId,
                          nextCard: nextAlertId == null
                              ? null
                              : ImportantCard(
                                  pendingClause: nextClause,
                                  // What the counter reads once this one is the main card.
                                  pendingCount: nextClause != null
                                      ? visiblePending.length - 1
                                      : 0,
                                  fallbackMessage: nextFallback?.$1,
                                  fallbackActionable: nextFallback?.$2 ?? false,
                                ),
                          onDismissed: (alertId) => setState(() =>
                              _dismissedAlerts.add('${myId ?? ''}|$alertId')),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text('Mis Cláusulas',
                                  style: AppTextStyles.headline(fontSize: 20)),
                            ),
                            SyncStatusPill(
                              lastSuccessfulSyncAt:
                                  syncProvider.status?.lastSuccessfulSyncAt,
                              isSyncing: syncProvider.isForcingSync,
                              onTap: adminModeProvider.isAdminMode
                                  ? _handleForceSync
                                  : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        ExecutedClauseCard(
                          activeClauses: activePerformed,
                          active: activePerformed.length,
                          limit: stats?.performed.limit ??
                              AppConfig.maxActiveClauses,
                        ),
                        if (stats != null && stats.performed.isExceeded) ...[
                          const SizedBox(height: 8),
                          _ExcessWarning(
                              active: stats.performed.active,
                              limit: stats.performed.limit,
                              category: 'realizados'),
                        ],
                        const SizedBox(height: 16),
                        ReceivedClauseCard(
                          activeClauses: activeReceived,
                          active:
                              stats?.received.active ?? activeReceived.length,
                          limit: stats?.received.limit ??
                              AppConfig.maxActiveClauses,
                        ),
                        if (stats != null && stats.received.isExceeded) ...[
                          const SizedBox(height: 8),
                          _ExcessWarning(
                              active: stats.received.active,
                              limit: stats.received.limit,
                              category: 'recibidos'),
                        ],
                        if (userProvider.errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Text(userProvider.errorMessage!,
                              style:
                                  const TextStyle(color: AppColors.dangerRed)),
                        ],
                      ]),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// Fallback alerts for the IMPORTANTE card when there is no PENDING clause to classify (limit exceeded,
  /// expiration notices). Returns `(message, isActionable, alertId)` in priority order, the first being
  /// the one shown. `isActionable` means tapping routes to Activity, and `alertId` is a stable id used to
  /// remember dismissals. Dismissed alerts are skipped, and the length tells the card stack whether more
  /// alerts wait behind the visible one.
  List<(String, bool, String)> _buildFallbackAlerts(
      UserStats? stats,
      List<ExpirationNotice> notices,
      bool Function(String alertId) isDismissed) {
    final alerts = <(String, bool, String)>[];
    if (stats != null) {
      if (stats.performed.isExceeded && !isDismissed('limit:performed')) {
        alerts.add((
          'Has superado el límite de cláusulazos realizados.',
          false,
          'limit:performed'
        ));
      }
      if (stats.received.isExceeded && !isDismissed('limit:received')) {
        alerts.add((
          'Has superado el límite de cláusulazos recibidos.',
          false,
          'limit:received'
        ));
      }
    }
    for (final notice in notices) {
      // One id per clause and phase, so "se libera en…" and the later "se ha liberado" are different alerts,
      // while the ticking countdown text never resurrects a dismissed one.
      final alertId =
          'notice:${notice.clause.id}:${notice.isJustReleased ? 'released' : 'expiring'}';
      if (!isDismissed(alertId)) alerts.add((notice.message, false, alertId));
    }
    return alerts;
  }
}

/// The stack of IMPORTANTE alerts: the main card (swipe left or right to dismiss, no confirmation) and,
/// when more wait, one card behind it peeking out on the right.
///
/// While the main card is dragged or flying out, the card behind follows the same progress: it slides
/// into the main slot, warms up to the main card's surface and fades its content in. So when the next
/// alert becomes the real main card, nothing changes on screen. The main card's final position never
/// changes, and the deck adds no layout space beyond the 24 dp below, which is animated away with the
/// last alert.
class _ImportantAlertsDeck extends StatefulWidget {
  const _ImportantAlertsDeck({
    required this.mainId,
    required this.mainCard,
    required this.nextId,
    required this.nextCard,
    required this.onDismissed,
  });

  final String? mainId;
  final Widget? mainCard;
  final String? nextId;
  final Widget? nextCard;
  final ValueChanged<String> onDismissed;

  @override
  State<_ImportantAlertsDeck> createState() => _ImportantAlertsDeckState();
}

class _ImportantAlertsDeckState extends State<_ImportantAlertsDeck> {
  // 0 -> 1 while the main card is dragged / flies out.
  final ValueNotifier<double> _progress = ValueNotifier<double>(0);

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mainCard = widget.mainCard;
    final mainId = widget.mainId;
    final nextCard = widget.nextCard;

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      child: mainCard == null || mainId == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (nextCard != null)
                    Positioned.fill(
                      child: _AlertBackdrop(
                        key: ValueKey('alert-backdrop-${widget.nextId}'),
                        progress: _progress,
                        next: nextCard,
                      ),
                    ),
                  Dismissible(
                    key: ValueKey('important-alert-$mainId'),
                    direction: DismissDirection.horizontal,
                    // With another alert waiting there is no collapse: the card behind takes the slot. The last alert
                    // still collapses.
                    resizeDuration: nextCard == null
                        ? const Duration(milliseconds: 300)
                        : null,
                    onUpdate: nextCard == null
                        ? null
                        : (details) => _progress.value = details.progress,
                    onDismissed: (_) {
                      _progress.value = 0;
                      widget.onDismissed(mainId);
                    },
                    child: mainCard,
                  ),
                ],
              ),
            ),
    );
  }
}

/// The card behind the main IMPORTANTE card. At rest it is an empty card shifted 12 dp to the right and
/// inset 8 dp top and bottom (depth effect). As `progress` goes 0 -> 1 it moves into the main slot,
/// warms up to the main card's surface and fades in the next alert's content. When a new card first
/// appears behind after a dismissal, it slides out from under the main card.
class _AlertBackdrop extends StatelessWidget {
  const _AlertBackdrop({
    super.key,
    required this.progress,
    required this.next,
  });

  final ValueNotifier<double> progress;
  final Widget next;

  static const double _restShift = 12;
  static const double _restInset = 8;

  @override
  Widget build(BuildContext context) {
    final restColor =
        Color.lerp(AppColors.surface, AppColors.surfaceElevated, 0.55)!;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      builder: (context, appear, _) => ValueListenableBuilder<double>(
        valueListenable: progress,
        builder: (context, rawProgress, _) {
          final t = Curves.easeOut.transform(rawProgress.clamp(0.0, 1.0));
          final contentOpacity = Curves.easeIn
              .transform(((rawProgress - 0.35) / 0.65).clamp(0.0, 1.0));

          return Padding(
            padding:
                EdgeInsets.symmetric(vertical: _restInset * appear * (1 - t)),
            child: Transform.translate(
              offset: Offset(_restShift * appear * (1 - t), 0),
              child: Opacity(
                opacity: appear,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(
                        color: Color.lerp(
                            restColor, AppColors.surfaceElevated, t)!,
                      ),
                      if (contentOpacity > 0)
                        Opacity(
                          opacity: contentOpacity,
                          // Laid out at its natural height (top-aligned, clipped) so a taller next card can't overflow.
                          child: IgnorePointer(
                            child: OverflowBox(
                              alignment: Alignment.topCenter,
                              minHeight: 0,
                              maxHeight: double.infinity,
                              child: next,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// "Modo Usuario / Modo Admin" selector, visible to everyone but only turned on for the admin account
/// (see `AdminModeProvider`). For anyone else `onChanged` is still called on tap and `setAdminMode`
/// ignores it, so the switch stays put.
class _AdminModeSwitch extends StatelessWidget {
  const _AdminModeSwitch({
    required this.isAdminMode,
    required this.onChanged,
  });

  final bool isAdminMode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    const activeLabelColor = AppColors.primaryGreen;
    const inactiveLabelColor = AppColors.textSecondary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'USUARIO',
          style: AppTextStyles.mono(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: isAdminMode ? inactiveLabelColor : activeLabelColor,
          ).copyWith(letterSpacing: 0.6),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 40,
          height: 24,
          child: FittedBox(
            child: Switch(
              value: isAdminMode,
              onChanged: onChanged,
              activeColor: AppColors.primaryGreen,
              inactiveThumbColor: AppColors.textSecondary,
              inactiveTrackColor: AppColors.surfaceElevated,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          'ADMIN',
          style: AppTextStyles.mono(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: isAdminMode ? activeLabelColor : inactiveLabelColor,
          ).copyWith(letterSpacing: 0.6),
        ),
      ],
    );
  }
}

class _ExcessWarning extends StatelessWidget {
  const _ExcessWarning(
      {required this.active, required this.limit, required this.category});

  final int active;
  final int limit;
  final String category;

  @override
  Widget build(BuildContext context) {
    final excess = active - limit;
    final message = excess == 1
        ? 'Has superado el límite de cláusulazos $category.'
        : 'Has superado el límite por $excess cláusulazos.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.dangerRed.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 16, color: AppColors.dangerRed),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  color: AppColors.dangerRed,
                  fontWeight: FontWeight.w600,
                  fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown instead of a blank screen on first load.
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget block(double height) => Container(
          height: height,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 84, 20, 20),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        block(32),
        const SizedBox(height: 12),
        block(120),
        block(180),
        block(180),
      ],
    );
  }
}
