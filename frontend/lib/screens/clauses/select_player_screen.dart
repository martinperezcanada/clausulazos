import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/player_card.dart';

class SelectPlayerScreen extends StatefulWidget {
  const SelectPlayerScreen({super.key});

  @override
  State<SelectPlayerScreen> createState() => _SelectPlayerScreenState();
}

class _SelectPlayerScreenState extends State<SelectPlayerScreen> {
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
      appBar: AppBar(title: const Text('¿A quién quieres clausular?')),
      body: userProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: userProvider.players.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final player = userProvider.players[index];
                return PlayerCard(
                  player: player,
                  showReceivedOnly: true,
                  onTap: () => context.push('/confirm-clause', extra: player),
                );
              },
            ),
    );
  }
}
