import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'core/storage/session_store.dart';
import 'core/theme/app_theme.dart';
import 'providers/admin_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/catalog_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/order_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/shell/home_shell.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppConfig.initialize();
  final store = await SessionStore.create();
  final themeProvider = await ThemeProvider.create();

  // The client is created first so AuthProvider can restore the stored token
  // into it; 401 handling needs a reference to the provider, wired below.
  late final AuthProvider authProvider;
  final api = ApiClient(
    onUnauthorized: () async => authProvider.clearSession(),
  );

  authProvider = AuthProvider(api: api, store: store);
  api.setToken(store.readToken());

  runApp(
    ParfumImApp(
      api: api,
      authProvider: authProvider,
      themeProvider: themeProvider,
    ),
  );
}

class ParfumImApp extends StatelessWidget {
  const ParfumImApp({
    super.key,
    required this.api,
    required this.authProvider,
    required this.themeProvider,
  });

  final ApiClient api;
  final AuthProvider authProvider;
  final ThemeProvider themeProvider;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <ChangeNotifierProvider<ChangeNotifier>>[
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ChangeNotifierProvider<CatalogProvider>(
          create: (_) => CatalogProvider(api: api)..loadCategories(),
        ),
        ChangeNotifierProvider<CartProvider>(
          create: (_) => CartProvider(api: api),
        ),
        ChangeNotifierProvider<NotificationProvider>(
          create: (_) => NotificationProvider(api: api),
        ),
        ChangeNotifierProvider<OrderProvider>(
          create: (_) => OrderProvider(api: api),
        ),
        ChangeNotifierProvider<AdminProvider>(
          create: (_) => AdminProvider(api: api),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) => MaterialApp(
          title: 'Parfum IM',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: theme.mode,
          home: const _RootGate(),
        ),
      ),
    );
  }
}

/// Chooses the landing screen once the stored session has been restored, and
/// bounces the user to login whenever the session is dropped.
class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final status = context.watch<AuthProvider>().status;

    return switch (status) {
      AuthStatus.unknown => const Scaffold(
        body: SafeArea(child: LoadingView()),
      ),
      AuthStatus.authenticated => const HomeShell(),
      AuthStatus.unauthenticated => const LoginScreen(),
    };
  }
}
