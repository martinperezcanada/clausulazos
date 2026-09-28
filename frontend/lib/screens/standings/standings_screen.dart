import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/debt_formatter.dart';
import '../../models/fantasy_debt.dart';
import '../../providers/clause_provider.dart';
import '../../providers/user_provider.dart';
import '../../repositories/fantasy_repository.dart';
import '../../widgets/app_top_bar.dart';
import 'records_tab.dart';

class StandingsScreen extends StatefulWidget {
  const StandingsScreen({super.key});

  @override
  State<StandingsScreen> createState() => _StandingsScreenState();
}

class _StandingsScreenState extends State<StandingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 2, vsync: this);
  // Last loaded "Tabla general" (and its chart data), kept in memory for the app process only, never on
  // disk. Screens are rebuilt on every visit, so the cache is static: re-entering shows the last table
  // immediately instead of a spinner. It's replaced whenever a load finishes and is gone on the next app
  // start.
  static List<FantasyDebt>? _cachedDebts;
  static List<int>? _cachedPendingWeeks;
  static List<FantasyDebtHistoryPoint>? _cachedHistoryPoints;
  static DateTime? _cachedAt;

  // Re-entering within this window just shows the cached table; after it, the table is refreshed once
  // in the background. Matches the 10-minute sync cycle.
  static const Duration _cacheTtl = Duration(minutes: 10);

  bool _isLoading = true;
  // True once a table (cached or freshly loaded) is available to show.
  bool _hasData = false;
  String? _error;
  List<FantasyDebt> _debts = [];
  List<int> _pendingWeeks = [];
  List<FantasyDebtHistoryPoint> _debtHistoryPoints = [];

  @override
  void initState() {
    super.initState();
    final cachedDebts = _cachedDebts;
    if (cachedDebts != null) {
      _debts = cachedDebts;
      _pendingWeeks = _cachedPendingWeeks ?? const [];
      _debtHistoryPoints = _cachedHistoryPoints ?? const [];
      _isLoading = false;
      _hasData = true;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cachedAt = _cachedAt;
      final stale =
          cachedAt == null || DateTime.now().difference(cachedAt) > _cacheTtl;
      if (!_hasData || stale) _load();
      context.read<UserProvider>().refreshAll();
      context.read<ClauseProvider>().loadHistory();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    // With a table already on screen the refresh is silent: the table stays
    // visible (no spinner) and is replaced when the new data arrives.
    final silent = _hasData;
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final repo = context.read<FantasyRepository>();
      // Independent requests, fetched together; the chart data is a separate dataset built by the backend,
      // not derived from `snapshot`.
      final results = await Future.wait([
        repo.fetchDebts(),
        repo.fetchDebtsHistory(),
      ]);
      final snapshot = results[0] as FantasyDebtsSnapshot;
      final history = results[1] as FantasyDebtHistory;
      // Keep the cache up to date even if the user already left the screen.
      _cachedDebts = snapshot.managers;
      _cachedPendingWeeks = snapshot.pendingWeeks;
      _cachedHistoryPoints = history.points;
      _cachedAt = DateTime.now();
      if (!mounted) return;
      setState(() {
        _debts = snapshot.managers;
        _pendingWeeks = snapshot.pendingWeeks;
        _debtHistoryPoints = history.points;
        _hasData = true;
        _error = null;
      });
    } catch (e) {
      // A failed silent refresh keeps the table that is already showing.
      if (mounted && !silent) {
        setState(() => _error = ApiClient.messageFromError(e));
      }
    } finally {
      if (mounted && !silent) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: AppTopBar(
          showBack: true,
          title: 'Clasificación',
          onBack: () => context.go('/players'),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelStyle:
              AppTextStyles.mono(fontSize: 11, fontWeight: FontWeight.w700),
          unselectedLabelStyle:
              AppTextStyles.mono(fontSize: 11, fontWeight: FontWeight.w500),
          labelColor: AppColors.primaryGreen,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primaryGreen,
          tabs: const [
            Tab(text: 'TABLA GENERAL'),
            Tab(text: 'RÉCORDS Y HITOS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _DebtsTab(
            isLoading: _isLoading,
            error: _error,
            debts: _debts,
            pendingWeeks: _pendingWeeks,
            onRetry: _load,
          ),
          RecordsTab(
            header: _debtHistoryPoints.isNotEmpty
                ? _DebtHistoryChart(points: _debtHistoryPoints)
                : null,
          ),
        ],
      ),
    );
  }
}

/// Debt per manager, computed server-side from LALIGA's per-jornada points (see
/// `FantasyRepository.fetchDebts()` / `FantasySyncService.getLeagueDebts()` for the rule and tie
/// handling), ordered by who owes the most.
class _DebtsTab extends StatelessWidget {
  const _DebtsTab({
    required this.isLoading,
    required this.error,
    required this.debts,
    required this.pendingWeeks,
    required this.onRetry,
  });

  final bool isLoading;
  final String? error;
  final List<FantasyDebt> debts;
  final List<int> pendingWeeks;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final showBanner = !isLoading && error == null && pendingWeeks.isNotEmpty;

    return RefreshIndicator(
      onRefresh: onRetry,
      child: Column(
        children: [
          if (showBanner)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: _PendingWeeksBanner(weeks: pendingWeeks),
            ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                    ? ListView(
                        children: [
                          const SizedBox(height: 100),
                          Center(
                            child: Column(
                              children: [
                                Text(error!,
                                    style: const TextStyle(
                                        color: AppColors.textSecondary)),
                                const SizedBox(height: 12),
                                OutlinedButton(
                                    onPressed: onRetry,
                                    child: const Text('Reintentar')),
                              ],
                            ),
                          ),
                        ],
                      )
                    : debts.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 100),
                              Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 32),
                                  child: Text(
                                    'Todavía no hay jornadas terminadas suficientes para calcular lo que debe cada manager.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: AppColors.textSecondary),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView(
                            padding: const EdgeInsets.all(20),
                            children: [
                              for (var index = 0;
                                  index < debts.length;
                                  index++) ...[
                                if (index > 0) const SizedBox(height: 10),
                                Card(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 14),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 28,
                                          child: Text(
                                            '${index + 1}',
                                            style: AppTextStyles.mono(
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.textSecondary),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(debts[index].managerName,
                                              style: AppTextStyles.headline(
                                                  fontSize: 16)),
                                        ),
                                        Text(
                                          DebtFormatter.format(
                                              debts[index].debtCents),
                                          style: AppTextStyles.mono(
                                            color: debts[index].debtCents > 0
                                                ? AppColors.dangerRed
                                                : AppColors.primaryGreen,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
          ),
        ],
      ),
    );
  }
}

/// Danger notice above the debt table when at least one jornada has a pending match and was excluded
/// from the calculation. `weeks` comes from the backend's per-jornada calendar check, so it updates
/// itself when that jornada's last match finishes.
class _PendingWeeksBanner extends StatelessWidget {
  const _PendingWeeksBanner({required this.weeks});

  final List<int> weeks;

  static String _weeksList(List<int> weeks) {
    final sorted = [...weeks]..sort();
    if (sorted.length == 1) return 'Jornada ${sorted.first}';
    if (sorted.length == 2) return 'Jornadas ${sorted[0]} y ${sorted[1]}';
    final allButLast = sorted.sublist(0, sorted.length - 1).join(', ');
    return 'Jornadas $allButLast y ${sorted.last}';
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = weeks.length == 1
        ? 'Esta jornada todavía no ha terminado y no se ha incluido en el cálculo.'
        : 'Estas jornadas todavía no han terminado y no se han incluido en el cálculo.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.dangerRed.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.dangerRed.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.pending_actions_rounded,
              size: 18, color: AppColors.dangerRed),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_weeksList(weeks)} en curso',
                  style: AppTextStyles.headline(
                      fontSize: 13, color: AppColors.dangerRed),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.body(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One line per manager with the accumulated debt after each finished jornada (`GET
/// /fantasy/debts/history`, same scan and rule as "Tabla general"). Shown as the header of "Récords y
/// hitos" (`RecordsTab.header`). Pending and future jornadas are absent from `points`, so the X axis
/// only shows jornadas that contributed money.
class _DebtHistoryChart extends StatelessWidget {
  const _DebtHistoryChart({required this.points});

  final List<FantasyDebtHistoryPoint> points;

  static const _palette = <Color>[
    AppColors.primaryGreen,
    AppColors.infoBlue,
    AppColors.dangerRed,
    AppColors.pendingYellow,
    Color(0xFFB48CFF),
    Color(0xFFFF9F43),
    Color(0xFFFF6FB5),
    Color(0xFF2DD4BF),
  ];

  int _debtCentsAt(int pointIndex, String managerId) {
    final managers = points[pointIndex].managers;
    for (final m in managers) {
      if (m.managerId == managerId) return m.debtCents;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    // Every point carries the full manager roster (see `FantasySyncService.getLeagueDebtHistory()`), so
    // the first one gives a stable order for the legend and colors.
    final managers = points.first.managers;

    final maxDebtCents = points
        .expand((p) => p.managers)
        .map((m) => m.debtCents)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final maxY = ((maxDebtCents <= 0 ? 100 : maxDebtCents) / 100.0) * 1.2;
    final yInterval = maxY / 4;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 16),
            child: Text('Evolución por jornada',
                style: AppTextStyles.headline(fontSize: 14)),
          ),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: yInterval,
                  getDrawingHorizontalLine: (_) =>
                      const FlLine(color: AppColors.divider, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: yInterval,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toStringAsFixed(0)}€',
                        style: AppTextStyles.mono(
                            fontSize: 9, color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final i = value.round();
                        if (i < 0 || i >= points.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('J${points[i].week}',
                              style: AppTextStyles.mono(
                                  fontSize: 9, color: AppColors.textSecondary)),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.surfaceElevated,
                    getTooltipItems: (spots) => spots.map((s) {
                      final manager = managers[s.barIndex];
                      return LineTooltipItem(
                        '${manager.managerName}\n${DebtFormatter.format(s.y.round() * 100)}',
                        AppTextStyles.mono(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _palette[s.barIndex % _palette.length],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                lineBarsData: [
                  for (var mi = 0; mi < managers.length; mi++)
                    LineChartBarData(
                      spots: [
                        for (var pi = 0; pi < points.length; pi++)
                          FlSpot(pi.toDouble(),
                              _debtCentsAt(pi, managers[mi].managerId) / 100.0),
                      ],
                      isCurved: false,
                      color: _palette[mi % _palette.length],
                      barWidth: 2,
                      dotData: FlDotData(
                        getDotPainter: (spot, percent, bar, index) =>
                            FlDotCirclePainter(
                                radius: 2.5,
                                color: bar.color ?? AppColors.primaryGreen,
                                strokeWidth: 0),
                      ),
                      belowBarData: BarAreaData(show: false),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                for (var mi = 0; mi < managers.length; mi++)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _palette[mi % _palette.length]),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        managers[mi].managerName,
                        style: AppTextStyles.mono(
                            fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
