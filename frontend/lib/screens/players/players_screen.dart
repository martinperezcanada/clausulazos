import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
      appBar: AppBar(title: const Text('Jugadores')),
      body: RefreshIndicator(
        onRefresh: () => context.read<UserProvider>().refreshAll(),
        child: userProvider.isLoading && userProvider.players.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: userProvider.players.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final player = userProvider.players[index];
                  return PlayerCard(player: player);
                },
              ),
      ),
    );
  }
}
