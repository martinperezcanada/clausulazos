import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import 'core/network/api_client.dart';
import 'core/notifications/notification_service.dart';
import 'core/routing/app_router.dart';
import 'core/storage/token_storage.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'providers/admin_mode_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/clause_provider.dart';
import 'providers/fantasy_sync_provider.dart';
import 'providers/passkeys_provider.dart';
import 'providers/user_provider.dart';
import 'repositories/auth_repository.dart';
import 'repositories/clause_repository.dart';
import 'repositories/fantasy_repository.dart';
import 'repositories/notifications_repository.dart';
import 'repositories/passkeys_repository.dart';
import 'repositories/user_repository.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );

  await initializeDateFormatting('es_ES');

  // Push notifications are optional: a misconfigured platform, a denied permission or (on Web) the
  // missing VAPID key mustn't stop startup or block login.
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    // Not awaited: the permission request and token fetch are slow and not needed for the first frame.
    unawaited(NotificationService.instance.initialize());
  } catch (error) {
    debugPrint('[Firebase] initialization failed: $error');
  }

  runApp(const ClausulazosApp());
}

class ClausulazosApp extends StatefulWidget {
  const ClausulazosApp({super.key});

  @override
  State<ClausulazosApp> createState() => _ClausulazosAppState();
}

class _ClausulazosAppState extends State<ClausulazosApp> {
  late final TokenStorage _tokenStorage;
  late final ApiClient _apiClient;
  late final AuthRepository _authRepository;
  late final UserRepository _userRepository;
  late final ClauseRepository _clauseRepository;
  late final PasskeysRepository _passkeysRepository;
  late final FantasyRepository _fantasyRepository;
  late final NotificationsRepository _notificationsRepository;
  late final AuthProvider _authProvider;
  late final GoRouter _router;

  // Mutable indirection: ApiClient is built before AuthProvider but must notify it on a 401.
  VoidCallback? _onUnauthorized;

  // Detects the transition to authenticated (login, register, restored session, a different user) so
  // the FCM token is registered on those transitions and not on every AuthProvider notification.
  AuthStatus? _lastAuthStatus;

  @override
  void initState() {
    super.initState();

    _tokenStorage = TokenStorage();
    _apiClient = ApiClient(
      tokenStorage: _tokenStorage,
      onUnauthorized: () => _onUnauthorized?.call(),
    );

    _authRepository =
        AuthRepository(apiClient: _apiClient, tokenStorage: _tokenStorage);
    _userRepository = UserRepository(apiClient: _apiClient);
    _clauseRepository = ClauseRepository(apiClient: _apiClient);
    _passkeysRepository = PasskeysRepository(
      apiClient: _apiClient,
      tokenStorage: _tokenStorage,
    );
    _fantasyRepository = FantasyRepository(apiClient: _apiClient);
    _notificationsRepository = NotificationsRepository(apiClient: _apiClient);

    _authProvider = AuthProvider(
      authRepository: _authRepository,
      passkeysRepository: _passkeysRepository,
    );
    _onUnauthorized = _authProvider.forceLogout;

    // Registers the FCM token (fetched from main()) with the backend once a JWT exists.
    NotificationService.instance.attachBackend(
      registerDevice: (token, platform) =>
          _notificationsRepository.registerDevice(
        token: token,
        platform: platform,
      ),
      isAuthenticated: () => _authProvider.status == AuthStatus.authenticated,
    );
    _authProvider.addListener(_onAuthChanged);

    _router = AppRouter.build(_authProvider);
    NotificationService.instance.attachNavigation(
      (route) => _router.go(route),
    );
  }

  void _onAuthChanged() {
    final status = _authProvider.status;
    if (status == AuthStatus.authenticated && status != _lastAuthStatus) {
      NotificationService.instance.notifyAuthStateChanged();
    } else if (status != AuthStatus.authenticated &&
        _lastAuthStatus == AuthStatus.authenticated) {
      // Logout: let the service forget its last registration so the next login sends it again.
      NotificationService.instance.notifyAuthStateChanged();
    }
    _lastAuthStatus = status;
  }

  @override
  void dispose() {
    _authProvider.removeListener(_onAuthChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
        ChangeNotifierProvider<AdminModeProvider>(
          create: (_) => AdminModeProvider(authProvider: _authProvider),
        ),
        ChangeNotifierProvider<UserProvider>(
          create: (_) => UserProvider(userRepository: _userRepository),
        ),
        ChangeNotifierProvider<ClauseProvider>(
          create: (_) => ClauseProvider(clauseRepository: _clauseRepository),
        ),
        ChangeNotifierProvider<PasskeysProvider>(
          create: (_) =>
              PasskeysProvider(passkeysRepository: _passkeysRepository),
        ),
        ChangeNotifierProvider<FantasySyncProvider>(
          create: (_) =>
              FantasySyncProvider(fantasyRepository: _fantasyRepository),
        ),
        Provider<FantasyRepository>.value(value: _fantasyRepository),
        Provider<UserRepository>.value(value: _userRepository),
      ],
      child: MaterialApp.router(
        title: 'Clausulazos',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        routerConfig: _router,
      ),
    );
  }
}
