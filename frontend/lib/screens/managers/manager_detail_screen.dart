import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/amount_formatter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/relative_time_formatter.dart';
import '../../core/theme/release_time_formatter.dart';
import '../../models/clause.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/clause_provider.dart';
import '../../providers/user_provider.dart';
import '../../repositories/user_repository.dart';
import '../../widgets/app_top_bar.dart';

/// Public profile of a league manager, opened from the Managers list: clause stats and history. Never
/// shows email, password or other private fields.
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      if (context.read<UserProvider>().myStats == null) {
        context.read<UserProvider>().refreshAll();
      }
    });
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
      // Make sure the history is loaded so it can be filtered below; usually it's already cached from
      // Home/Activity.
      await context.read<ClauseProvider>().loadHistory();
    } catch (e) {
      if (mounted)
        setState(() => _error = 'No se ha podido cargar este manager.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _executeClause(String myId) async {
    final manager = _manager;
    if (manager == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar cláusulazo'),
        content: Text(
          '¿Ejecutar un cláusulazo a ${manager.name}? Ocupará una de tus plazas realizadas y una de sus plazas recibidas durante 7×24h.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Ejecutar cláusulazo')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final ok = await context.read<ClauseProvider>().createClause(manager.id);
    if (!mounted) return;

    if (ok) {
      await Future.wait([
        context.read<UserProvider>().refreshStatsOnly(),
        _load(),
      ]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cláusulazo ejecutado a ${manager.name}.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(context.read<ClauseProvider>().errorMessage ??
                'No se ha podido ejecutar el cláusulazo.')),
      );
    }
  }

  String _initialsFor(String name) {
    final trimmed = name.trim();
    return trimmed.isNotEmpty ? trimmed[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final clauseProvider = context.watch<ClauseProvider>();
    final userProvider = context.watch<UserProvider>();
    final myId = context.watch<AuthProvider>().currentUser?.id;
    final manager = _manager;

    final relevantHistory = manager == null
        ? const <Clause>[]
        : clauseProvider.history
            .where(
                (c) => c.fromUserId == manager.id || c.toUserId == manager.id)
            .take(10)
            .toList();

    final myAvailable = userProvider.myStats?.performed.available ?? 0;
    final theirAvailable = manager?.stats?.received.available ?? 0;
    final isSelf = manager != null && manager.id == myId;
    final canExecute =
        manager != null && !isSelf && myAvailable > 0 && theirAvailable > 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: AppTopBar(
          showBack: true,
          title: manager?.name ?? 'Manager',
          onBack: () => context.go('/players'),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading && manager == null
                ? const Center(child: CircularProgressIndicator())
                : _error != null && manager == null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!,
                                style: const TextStyle(
                                    color: AppColors.textSecondary)),
                            const SizedBox(height: 12),
                            OutlinedButton(
                                onPressed: _load,
                                child: const Text('Reintentar')),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                          children: [
                            _ManagerBannerCard(
                                name: manager!.name,
                                initials: _initialsFor(manager.name)),
                            const SizedBox(height: 24),
                            const _SectionHeader(
                              icon: Icons.tune_rounded,
                              iconColor: AppColors.primaryGreen,
                              title: 'Control de Cláusulas',
                            ),
                            const SizedBox(height: 10),
                            if (manager.stats != null) ...[
                              _ClauseStatCard(
                                title: 'CLÁUSULAS REALIZADAS',
                                stats: manager.stats!.performed,
                                badgeAvailableSuffix: 'DISPONIBLE',
                                badgeCompleteSuffix: 'AGOTADAS',
                                availableSubtitle:
                                    'Puede hacer ${manager.stats!.performed.available} más.',
                                completeSubtitle:
                                    'Bloqueo activo: no puede robar a rivales.',
                                availableIcon: Icons.bolt_rounded,
                                completeIcon: Icons.lock_clock_rounded,
                              ),
                              const SizedBox(height: 10),
                              _ClauseStatCard(
                                title: 'CLÁUSULAS RECIBIDAS',
                                stats: manager.stats!.received,
                                badgeAvailableSuffix: 'VULNERABLE',
                                badgeCompleteSuffix: 'BLINDADO',
                                availableSubtitle: isSelf
                                    ? 'Puede recibir ${manager.stats!.received.available} más.'
                                    : '¡Flanco abierto! Puedes clausularle ${manager.stats!.received.available} jugador(es).',
                                completeSubtitle:
                                    'Blindado: sin plazas libres para clausular.',
                                availableIcon: Icons.gpp_maybe_rounded,
                                completeIcon: Icons.shield_rounded,
                              ),
                            ],
                            const SizedBox(height: 24),
                            const _SectionHeader(
                              icon: Icons.history_edu_rounded,
                              iconColor: AppColors.infoBlue,
                              title: 'Historial de Mercado',
                              trailingLabel: 'ÚLTIMOS MOVIMIENTOS',
                            ),
                            const SizedBox(height: 10),
                            _MarketHistoryCard(
                                history: relevantHistory,
                                managerId: manager.id),
                          ],
                        ),
                      ),
          ),
          // A Column sibling below the scrollable content, not a floating `Scaffold.bottomSheet`, so it can't
          // sit on top of the cards or the history however tall the button label or the caption get.
          if (manager != null && !isSelf)
            SafeArea(
              top: false,
              // Transparent on purpose: it floats over the screen background and shouldn't read as an opaque
              // panel. The button's own elevation is enough, so no extra container background, border or shadow.
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: (canExecute && !clauseProvider.isCreating)
                            ? () => _executeClause(myId!)
                            : null,
                        icon: clauseProvider.isCreating
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.black54),
                              )
                            : const Icon(Icons.bolt_rounded, size: 20),
                        label: Text(
                          myAvailable <= 0
                              ? 'Sin plazas realizadas disponibles'
                              : theirAvailable <= 0
                                  ? '${manager.name} está blindado'
                                  : 'Ejecutar cláusulazo a ${manager.name}',
                        ),
                      ),
                    ),
                    if (canExecute) ...[
                      const SizedBox(height: 6),
                      Text.rich(
                        TextSpan(
                          text: 'Cupo disponible: ',
                          style: AppTextStyles.mono(
                              fontSize: 11, color: AppColors.textSecondary),
                          children: [
                            TextSpan(
                              text:
                                  '$theirAvailable jugador${theirAvailable == 1 ? '' : 'es'} disponible${theirAvailable == 1 ? '' : 's'} para robo',
                              style: AppTextStyles.mono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryGreen),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Banner card at the top: avatar (initials), name and a decorative "verified" check, like Profile's
/// header. Team name, rank, points and budget aren't shown: there's no data source for them.
class _ManagerBannerCard extends StatelessWidget {
  const _ManagerBannerCard({required this.name, required this.initials});

  final String name;
  final String initials;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: const BoxDecoration(color: AppColors.surfaceHighest),
        padding: const EdgeInsets.all(20),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: -30,
              top: -30,
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryGreen.withOpacity(0.18)),
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.surfaceElevated,
                  child: Text(
                    initials,
                    style: const TextStyle(
                        fontSize: 26,
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: AppTextStyles.headline(fontSize: 22),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.verified_rounded,
                          size: 18, color: AppColors.primaryGreen),
                    ],
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

/// Section title row: icon + headline + optional trailing caption.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.trailingLabel,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? trailingLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: 6),
        Expanded(
            child: Text(title, style: AppTextStyles.headline(fontSize: 18))),
        if (trailingLabel != null)
          Text(
            trailingLabel!,
            style:
                AppTextStyles.mono(fontSize: 10, color: AppColors.textSecondary)
                    .copyWith(letterSpacing: 0.6),
          ),
      ],
    );
  }
}

/// Shared card for "Cláusulas Realizadas" and "Cláusulas Recibidas": same container, header, status,
/// slot bar and countdown, driven by the `SlotStats` passed in. Only the wording and icons differ between
/// the two call sites (see `ManagerDetailScreen.build`).
///
/// Colour is kept to accents: neutral surfaces and text carry the information, a small status dot says
/// whether there is room (green) or not (red), and the slot bar fills occupied slots in that colour.
class _ClauseStatCard extends StatelessWidget {
  const _ClauseStatCard({
    required this.title,
    required this.stats,
    required this.badgeAvailableSuffix,
    required this.badgeCompleteSuffix,
    required this.availableSubtitle,
    required this.completeSubtitle,
    required this.availableIcon,
    required this.completeIcon,
  });

  final String title;
  final SlotStats stats;
  final String badgeAvailableSuffix;
  final String badgeCompleteSuffix;
  final String availableSubtitle;
  final String completeSubtitle;
  final IconData availableIcon;
  final IconData completeIcon;

  @override
  Widget build(BuildContext context) {
    final isComplete = stats.isComplete;
    final stateColor =
        isComplete ? AppColors.dangerRed : AppColors.primaryGreen;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceHighest.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isComplete ? completeIcon : availableIcon,
                  color: isComplete
                      ? AppColors.dangerRed
                      : AppColors.textSecondary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.mono(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary)
                          .copyWith(letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                              color: stateColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isComplete
                              ? badgeCompleteSuffix
                              : badgeAvailableSuffix,
                          style: AppTextStyles.mono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary)
                              .copyWith(letterSpacing: 0.6),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text.rich(
                TextSpan(
                  text: '${stats.active}',
                  style: AppTextStyles.headline(
                      fontSize: 26, fontWeight: FontWeight.w700),
                  children: [
                    TextSpan(
                      text: '/${stats.limit}',
                      style: AppTextStyles.headline(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (stats.limit > 0) ...[
            const SizedBox(height: 16),
            Row(
              children: List.generate(stats.limit, (i) {
                final occupied = i < stats.active;
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: i < stats.limit - 1 ? 6 : 0),
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      // Same colours as the Managers list (`PlayerCard`): occupied slots green, all red once
                      // full, free slots grey.
                      color: occupied ? stateColor : AppColors.surfaceHighest,
                    ),
                  ),
                );
              }),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            isComplete ? completeSubtitle : availableSubtitle,
            style: AppTextStyles.body(
                fontSize: 12, color: AppColors.textSecondary),
          ),
          if (isComplete && stats.nextReleaseAt != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                  color: AppColors.background.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.hourglass_bottom_rounded,
                          size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        'Próxima liberación',
                        style: AppTextStyles.mono(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  Text(
                    ReleaseTimeFormatter.describe(stats.nextReleaseAt!),
                    style: AppTextStyles.mono(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Historial de Mercado" card: the clause history filtered to this manager (either side of the
/// movement).
class _MarketHistoryCard extends StatelessWidget {
  const _MarketHistoryCard({required this.history, required this.managerId});

  final List<Clause> history;
  final String managerId;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.all(20),
        child: const Center(
          child: Text('Sin movimientos todavía.',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          for (var i = 0; i < history.length; i++) ...[
            if (i > 0) ...[
              const SizedBox(height: 10),
              Container(height: 1, color: AppColors.divider),
              const SizedBox(height: 10),
            ],
            _MarketHistoryRow(clause: history[i], managerId: managerId),
          ],
        ],
      ),
    );
  }
}

class _MarketHistoryRow extends StatelessWidget {
  const _MarketHistoryRow({required this.clause, required this.managerId});

  final Clause clause;
  final String managerId;

  @override
  Widget build(BuildContext context) {
    final iAmFrom = clause.fromUserId == managerId;
    final counterpart =
        (iAmFrom ? clause.toUser?.name : clause.fromUser?.name) ?? 'un manager';

    late final IconData icon;
    late final Color iconColor;
    late final String title;
    late final String badgeText;
    late final Color badgeColor;
    late final String caption;

    switch (clause.classification) {
      case ClauseClassification.pending:
        icon = Icons.hourglass_empty_rounded;
        iconColor = AppColors.pendingYellow;
        title = iAmFrom
            ? 'Pendiente con $counterpart'
            : '$counterpart tiene un movimiento pendiente';
        badgeText = 'PENDIENTE';
        badgeColor = AppColors.pendingYellow;
        caption = 'Esperando confirmación';
        break;
      case ClauseClassification.agreed:
        icon = Icons.handshake_rounded;
        iconColor = AppColors.infoBlue;
        title = 'Traspaso pactado con $counterpart';
        badgeText = 'ACUERDO';
        badgeColor = AppColors.infoBlue;
        caption = 'Mercado interno';
        break;
      case ClauseClassification.clause:
        icon = Icons.flash_on_rounded;
        iconColor = AppColors.dangerRed;
        title =
            iAmFrom ? 'Clausuló a $counterpart' : 'Le clausuló $counterpart';
        badgeText = 'ÉXITO';
        badgeColor = AppColors.primaryGreen;
        caption = 'Operación unilateral';
        break;
    }

    final subtitle = clause.amount != null
        ? '${clause.displayPlayerName} · ${AmountFormatter.format(clause.amount!)}'
        : clause.displayPlayerName;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15), shape: BoxShape.circle),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: AppTextStyles.headline(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    RelativeTimeFormatter.describe(clause.createdAt),
                    style: AppTextStyles.mono(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTextStyles.body(
                    fontSize: 12, color: AppColors.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(4)),
                    child: Text(
                      badgeText,
                      style: AppTextStyles.mono(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: badgeColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      caption,
                      style: AppTextStyles.mono(
                          fontSize: 11, color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
