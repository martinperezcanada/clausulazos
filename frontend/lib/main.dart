import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/network/api_client.dart';
import 'core/routing/app_router.dart';
import 'core/storage/token_storage.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/clause_provider.dart';
import 'providers/user_provider.dart';
import 'repositories/auth_repository.dart';
import 'repositories/clause_repository.dart';
import 'repositories/user_repository.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_ES');
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
  late final AuthProvider _authProvider;
  late final GoRouter _router;

  // Mutable indirection so ApiClient (built before AuthProvider exists)
  // can still notify AuthProvider on a 401 from any request.
  VoidCallback? _onUnauthorized;

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

    _authProvider = AuthProvider(authRepository: _authRepository);
    _onUnauthorized = _authProvider.forceLogout;

    _router = AppRouter.build(_authProvider);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
        ChangeNotifierProvider<UserProvider>(
          create: (_) => UserProvider(userRepository: _userRepository),
        ),
        ChangeNotifierProvider<ClauseProvider>(
          create: (_) => ClauseProvider(clauseRepository: _clauseRepository),
        ),
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
