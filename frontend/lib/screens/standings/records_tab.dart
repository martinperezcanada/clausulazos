import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/clause.dart';
import '../../providers/clause_provider.dart';

/// Records derived from our own clause history (`ClauseProvider.history`, already loaded for the whole
/// app). Only aggregates computed from that data.
class RecordsTab extends StatelessWidget {
  const RecordsTab({super.key, this.header});

  /// Optional content above the record cards, e.g. the debt evolution chart on Estadísticas.
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final clauseProvider = context.watch<ClauseProvider>();
    final history = clauseProvider.history;

    if (clauseProvider.isLoading && history.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (header != null) ...[header!, const SizedBox(height: 20)],
          const SizedBox(height: 60),
          const Center(child: CircularProgressIndicator()),
        ],
      );
    }

    final withAmount = history.where((c) => c.amount != null).toList()
      ..sort((a, b) => b.amount!.compareTo(a.amount!));

    // "El Verdugo": most clausulazos executed (fromUserId). "La Víctima": most received (toUserId). Both
    // are plain tallies over the loaded history.
    final executedByManager = <String, int>{};
    final receivedByManager = <String, int>{};
    for (final c in history
        .where((c) => c.classification == ClauseClassification.clause)) {
      executedByManager[c.fromUserId] =
          (executedByManager[c.fromUserId] ?? 0) + 1;
      receivedByManager[c.toUserId] = (receivedByManager[c.toUserId] ?? 0) + 1;
    }

    String? topExecutorId;
    var topExecutorCount = 0;
    executedByManager.forEach((id, count) {
      if (count > topExecutorCount) {
        topExecutorId = id;
        topExecutorCount = count;
      }
    });
    final topExecutorName = topExecutorId == null
        ? null
        : history
            .firstWhere((c) => c.fromUserId == topExecutorId,
                orElse: () => history.first)
            .fromUser
            ?.name;

    String? topVictimId;
    var topVictimCount = 0;
    receivedByManager.forEach((id, count) {
      if (count > topVictimCount) {
        topVictimId = id;
        topVictimCount = count;
      }
    });
    final topVictimName = topVictimId == null
        ? null
        : history
            .firstWhere((c) => c.toUserId == topVictimId,
                orElse: () => history.first)
            .toUser
            ?.name;

    if (history.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (header != null) ...[header!, const SizedBox(height: 20)],
          const SizedBox(height: 40),
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Todavía no hay historial suficiente para mostrar récords.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(context).padding.bottom),
      children: [
        if (header != null) ...[header!, const SizedBox(height: 20)],
        Text(
          'RADAR HISTÓRICO DE RIVALIDAD',
          style: AppTextStyles.mono(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary)
              .copyWith(letterSpacing: 1),
        ),
        const SizedBox(height: 12),
        if (withAmount.isNotEmpty)
          RecordCard(
            icon: Icons.payments_outlined,
            title: 'Mayor clausulazo',
            value: '${withAmount.first.amount}€',
            subtitle: withAmount.first.displayPlayerName,
          ),
        if (withAmount.isNotEmpty) const SizedBox(height: 12),
        if (topExecutorName != null)
          RecordCard(
            icon: Icons.bolt_rounded,
            title: 'El Verdugo',
            value: '$topExecutorCount',
            subtitle: '$topExecutorName · cláusulazos ejecutados',
          ),
        if (topExecutorName != null) const SizedBox(height: 12),
        if (topVictimName != null)
          RecordCard(
            icon: Icons.gps_fixed_rounded,
            title: 'La Víctima',
            value: '$topVictimCount',
            subtitle: '$topVictimName · cláusulazos sufridos',
          ),
        if (topVictimName != null) const SizedBox(height: 12),
        RecordCard(
          icon: Icons.history_rounded,
          title: 'Movimientos totales',
          value: '${history.length}',
          subtitle: 'entre todos los managers de la liga',
        ),
      ],
    );
  }
}

class RecordCard extends StatelessWidget {
  const RecordCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: AppColors.primaryGreen, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: AppTextStyles.mono(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)
                      .copyWith(letterSpacing: 1),
                ),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: AppTextStyles.body(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Text(value,
              style: AppTextStyles.mono(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen)),
        ],
      ),
    );
  }
}
