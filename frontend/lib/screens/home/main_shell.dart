import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  static const _tabs = ['/home', '/activity', '/players', '/profile'];

  int _indexForLocation(String location) {
    final index = _tabs.indexWhere((t) => location.startsWith(t));
    return index == -1 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _indexForLocation(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => context.go(_tabs[index]),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Inicio'),
          BottomNavigationBarItem(icon: Text('🔥', style: TextStyle(fontSize: 20)), label: 'Actividad'),
          BottomNavigationBarItem(icon: Icon(Icons.groups_rounded), label: 'Jugadores'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Perfil'),
        ],
      ),
    );
  }
}
