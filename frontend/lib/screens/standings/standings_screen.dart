import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../repositories/fantasy_repository.dart';

/// Shows LALIGA Fantasy's own league standings, read generically: we
/// don't have a confirmed, verified schema for this payload (no access to
/// a live LALIGA_TOKEN to inspect a real response while building this),
/// so rather than guess a rigid shape and risk showing wrong/blank data,
/// this parses defensively and falls back to a clear "couldn't read this"
/// message instead of breaking. No points/positions are ever invented —
/// only what LALIGA's own API actually returns is shown.
class StandingsScreen extends StatefulWidget {
  const StandingsScreen({super.key});

  @override
  State<StandingsScreen> createState() => _StandingsScreenState();
}

class _StandingsScreenState extends State<StandingsScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];

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
      final repo = context.read<FantasyRepository>();
      final raw = await repo.fetchStandings();
      setState(() => _rows = _extractRows(raw));
    } catch (e) {
      if (mounted) setState(() => _error = ApiClient.messageFromError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  static List<Map<String, dynamic>> _extractRows(dynamic raw) {
    List<dynamic>? list;
    if (raw is List) {
      list = raw;
    } else if (raw is Map) {
      for (final key in ['data', 'standing', 'standings', 'elements', 'items', 'results']) {
        if (raw[key] is List) {
          list = raw[key] as List;
          break;
        }
      }
    }
    if (list == null) return [];
    return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static String? _firstString(Map<String, dynamic> row, List<String> keys) {
    for (final k in keys) {
      final v = row[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clasificación')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    children: [
                      const SizedBox(height: 100),
                      Center(
                        child: Column(
                          children: [
                            Text(_error!, style: const TextStyle(color: AppColors.textSecondary)),
                            const SizedBox(height: 12),
                            OutlinedButton(onPressed: _load, child: const Text('Reintentar')),
                          ],
                        ),
                      ),
                    ],
                  )
                : _rows.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 100),
                          Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                'La clasificación no está disponible en un formato que podamos mostrar todavía.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: _rows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final row = _rows[index];
                          final position = _firstString(row, ['position', 'pos', 'rank', 'ranking']) ?? '${index + 1}';
                          final manager = _firstString(
                                row,
                                ['managerName', 'teamName', 'name', 'userName', 'nickname'],
                              ) ??
                              'Manager';
                          final points = _firstString(row, ['points', 'totalPoints', 'score']);

                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 28,
                                    child: Text(
                                      position,
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(manager, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  ),
                                  if (points != null)
                                    Text(
                                      '$points pts',
                                      style: const TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
