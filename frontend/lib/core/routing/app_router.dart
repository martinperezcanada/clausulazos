import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../screens/activity/activity_screen.dart';
import '../../screens/admin/admin_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/auth/welcome_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/home/main_shell.dart';
import '../../screens/managers/manager_detail_screen.dart';
import '../../screens/players/players_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/splash/splash_screen.dart';
import '../../screens/standings/standings_screen.dart';

// System back must not pop a route by itself, so every screen-level route is wrapped in a
// `PopScope(canPop: false)` here instead of in each screen. It blocks any `Navigator.maybePop()`, which
// both the OS back gesture and `context.pop()` go through, so screens go back with an explicit
// `context.go(...)` instead (`AppTopBar`, Login/Register). Dialogs, bottom sheets and the keyboard are
// unaffected: they sit on top of the page route and are dismissed first.
Widget _blockSystemBack(Widget child) => PopScope(canPop: false, child: child);

/// Page for the four main sections (Inicio / Actividad / Managers / Perfil) inside the `ShellRoute`.
/// Replaces the platform's default transition (the Material zoom, which looks like opening a new page)
/// with a light fade plus a small slide from the right: 220 ms, `easeOut`.
///
/// The outgoing section stays opaque while the incoming one cross-fades over it, so nothing dips to the
/// background and fast tab switching stays smooth. Only the shell's inner Navigator is affected. The
/// shell's first section is added by Flutter without a transition.
Page<void> _sectionPage(GoRouterState state, Widget screen) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: _blockSystemBack(screen),
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // Reverse: this section is the one being replaced; leave it untouched.
      if (animation.status == AnimationStatus.reverse) return child;
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.05, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class AppRouter {
  AppRouter._();

  static GoRouter build(AuthProvider authProvider) {
    // Destination requested while auth was still resolving (e.g. a notification tap to /activity during a
    // cold start): keep it instead of losing it to Splash's redirect, and resume it once authenticated.
    String? pendingDestination;

    return GoRouter(
      initialLocation: '/splash',
      refreshListenable: authProvider,
      redirect: (context, state) {
        final status = authProvider.status;
        final loggingIn = state.matchedLocation == '/login' ||
            state.matchedLocation == '/register' ||
            state.matchedLocation == '/welcome';
        final onSplash = state.matchedLocation == '/splash';

        // `backendUnreachable`: a JWT is stored but the backend couldn't be reached to validate it. Stay on
        // Splash, which keeps retrying, instead of treating it as a logout.
        if (status == AuthStatus.unknown ||
            status == AuthStatus.backendUnreachable) {
          if (!onSplash) pendingDestination = state.matchedLocation;
          return onSplash ? null : '/splash';
        }
        if (status == AuthStatus.unauthenticated) {
          pendingDestination = null;
          return loggingIn ? null : '/welcome';
        }
        // authenticated
        if (onSplash || loggingIn) {
          final resume = pendingDestination;
          pendingDestination = null;
          return resume ?? '/home';
        }
        return null;
      },
      routes: [
        GoRoute(
            path: '/splash',
            builder: (context, state) =>
                _blockSystemBack(const SplashScreen())),
        GoRoute(
            path: '/welcome',
            builder: (context, state) =>
                _blockSystemBack(const WelcomeScreen())),
        GoRoute(
            path: '/login',
            builder: (context, state) => _blockSystemBack(const LoginScreen())),
        GoRoute(
            path: '/register',
            builder: (context, state) =>
                _blockSystemBack(const RegisterScreen())),
        GoRoute(
          path: '/managers/:id',
          builder: (context, state) => _blockSystemBack(
              ManagerDetailScreen(managerId: state.pathParameters['id']!)),
        ),
        GoRoute(
            path: '/standings',
            builder: (context, state) =>
                _blockSystemBack(const StandingsScreen())),
        GoRoute(
            path: '/admin',
            builder: (context, state) => _blockSystemBack(const AdminScreen())),
        ShellRoute(
          // The nested routes render in the shell's own Navigator, so wrapping only their builders leaves the
          // root Navigator entry for the ShellRoute itself unprotected. That's the entry Android's back reaches
          // when a tab has nothing left to pop, and without a PopScope there it exited the app. Wrapping the
          // shell builder's output closes that gap.
          builder: (context, state, child) =>
              _blockSystemBack(MainShell(child: child)),
          routes: [
            GoRoute(
                path: '/home',
                pageBuilder: (context, state) =>
                    _sectionPage(state, const HomeScreen())),
            GoRoute(
                path: '/activity',
                pageBuilder: (context, state) =>
                    _sectionPage(state, const ActivityScreen())),
            GoRoute(
                path: '/players',
                pageBuilder: (context, state) =>
                    _sectionPage(state, const PlayersScreen())),
            GoRoute(
                path: '/profile',
                pageBuilder: (context, state) =>
                    _sectionPage(state, const ProfileScreen())),
          ],
        ),
      ],
    );
  }
}

/// Shortcut to read the [AuthProvider] from a context.
extension AuthProviderReader on BuildContext {
  AuthProvider get auth => read<AuthProvider>();
}
