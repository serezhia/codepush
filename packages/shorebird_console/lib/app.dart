import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shorebird_console/data/api_client.dart';
import 'package:shorebird_console/data/auth_storage.dart';
import 'package:shorebird_console/di/app_dependencies.dart';
import 'package:shorebird_console/features/apps/domain/apps_bloc.dart';
import 'package:shorebird_console/features/auth/data/auth_repository.dart';
import 'package:shorebird_console/features/auth/domain/auth_bloc.dart';
import 'package:shorebird_console/router/app_router.dart';

class App extends StatefulWidget {
  const App({required this.apiBaseUrl, super.key});

  final String apiBaseUrl;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final AuthStorage _authStorage;
  late final ApiClient _apiClient;
  late final AuthRepository _authRepository;

  @override
  void initState() {
    super.initState();
    _authStorage = AuthStorage();
    _apiClient = ApiClient(
      baseUrl: widget.apiBaseUrl,
      authStorage: _authStorage,
    );
    _authRepository = AuthRepository(
      apiClient: _apiClient,
      authStorage: _authStorage,
    );
  }

  @override
  Widget build(BuildContext context) {
    final router = createRouter(_authStorage);

    return AppDependencies(
      apiClient: _apiClient,
      authStorage: _authStorage,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) =>
                AuthBloc(authRepository: _authRepository)
                  ..add(AuthCheckRequested()),
          ),
          BlocProvider(
            create: (_) =>
                AppsBloc(apiClient: _apiClient)..add(AppsLoadRequested()),
          ),
        ],
        child: MaterialApp.router(
          title: 'Shorebird Console',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorSchemeSeed: Colors.blue,
            useMaterial3: true,
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            colorSchemeSeed: Colors.blue,
            useMaterial3: true,
            brightness: Brightness.dark,
          ),
          routerConfig: router,
        ),
      ),
    );
  }
}
