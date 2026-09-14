import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/clause_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/clause_card.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClauseProvider>().loadHistory();
    });
  }

  Future<void> _cancel(String clauseId) async {
    final ok = await context.read<ClauseProvider>().cancelClause(clauseId);
    if (ok) {
      await context.read<ClauseProvider>().loadHistory();
    }
  }

  Future<void> _confirm(String clauseId, String classification) async {
    // The provider updates that one card in-place, so we don't need to
    // reload the whole history — but the user's own slot counts may have
    // changed, so refresh stats used elsewhere (Home/Players) too.
    final ok = await context.read<ClauseProvider>().confirmClassification(clauseId, classification);
    if (ok && mounted) {
      await context.read<UserProvider>().refreshStatsOnly();
    }
  }

  @override
  Widget build(BuildContext context) {
    final clauseProvider = context.watch<ClauseProvider>();
    final myId = context.watch<AuthProvider>().currentUser?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Actividad')),
      body: RefreshIndicator(
        onRefresh: () => context.read<ClauseProvider>().loadHistory(),
        child: clauseProvider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : clauseProvider.history.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(child: Text('Todavía no hay cláusulazos.')),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: clauseProvider.history.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final clause = clauseProvider.history[index];
                      return ClauseCard(
                        clause: clause,
                        currentUserId: myId,
                        onCancel: () => _cancel(clause.id),
                        onConfirm: (classification) => _confirm(clause.id, classification),
                        isConfirming: clauseProvider.confirmingIds.contains(clause.id),
                      );
                    },
                  ),
      ),
    );
  }
}
