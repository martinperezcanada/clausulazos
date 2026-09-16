import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/clause.dart';
import '../../providers/auth_provider.dart';
import '../../providers/clause_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/clause_card.dart';

enum _ActivityFilter { all, clause, agreed, pending }

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

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClauseProvider>().loadHistory();
    });
  }

  Future<void> _confirm(String clauseId, String classification) async {
    final ok = await context
        .read<ClauseProvider>()
        .confirmClassification(clauseId, classification);

    if (ok && mounted) {
      await context.read<UserProvider>().refreshStatsOnly();
    }
  }

  @override
  Widget build(BuildContext context) {
    final clauseProvider = context.watch<ClauseProvider>();
    final myId = context.watch<AuthProvider>().currentUser?.id;
    final filtered = clauseProvider.history.where(_filter.matches).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Actividad'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            child: SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _ActivityFilter.values.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final option = _ActivityFilter.values[index];
                  final selected = option == _filter;

                  return ChoiceChip(
                    label: Text(option.label),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _filter = option);
                    },
                    backgroundColor: AppColors.surface,
                    selectedColor: AppColors.primaryGreen,
                    labelStyle: TextStyle(
                      color: selected ? Colors.black : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    side: BorderSide(
                      color:
                          selected ? AppColors.primaryGreen : AppColors.divider,
                    ),
                  );
                },
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => context.read<ClauseProvider>().loadHistory(),
              child: clauseProvider.isLoading && clauseProvider.history.isEmpty
                  ? _ActivitySkeleton()
                  : filtered.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 120),
                            Center(
                              child: Text(
                                clauseProvider.history.isEmpty
                                    ? 'Todavía no hay cláusulazos.'
                                    : 'No hay movimientos en "${_filter.label}".',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                            20,
                            4,
                            20,
                            20,
                          ),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final clause = filtered[index];

                            return ClauseCard(
                              clause: clause,
                              currentUserId: myId,
                              onConfirm: (classification) => _confirm(
                                clause.id,
                                classification,
                              ),
                              isConfirming: clauseProvider.confirmingIds
                                  .contains(clause.id),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivitySkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 5,
      itemBuilder: (context, index) => Container(
        height: 110,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
