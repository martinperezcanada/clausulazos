import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/user_provider.dart';
import '../../widgets/player_card.dart';

class PlayersScreen extends StatefulWidget {
  const PlayersScreen({super.key});

  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProvider>().refreshAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Managers'),
        actions: [
          IconButton(
            tooltip: 'Clasificación de la liga',
            icon: const Icon(Icons.leaderboard_rounded),
            onPressed: () => context.push('/standings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<UserProvider>().refreshAll(),
        child: userProvider.isLoading && userProvider.players.isEmpty
            ? _ManagersSkeleton()
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: userProvider.players.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final player = userProvider.players[index];
                  return PlayerCard(
                    player: player,
                    onTap: () => context.push('/managers/${player.id}'),
                  );
                },
              ),
      ),
    );
  }
}

class _ManagersSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      itemBuilder: (context, index) => Container(
        height: 76,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}
