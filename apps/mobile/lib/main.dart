import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'app/router/app_router.dart';
import 'core/api/api_client.dart';
import 'core/api/auth_state.dart';
import 'core/theme/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Base API configuration (can be overridden via --dart-define=API_URL=...)
  const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:3000/api/v1',
  );

  final apiClient = ApiClient(baseUrl: apiUrl);
  final authState = AuthState(apiClient: apiClient);
  final themeProvider = ThemeProvider();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ChangeNotifierProvider<AuthState>.value(value: authState),
      ],
      child: const CommitteeLedgerApp(),
    ),
  );
}

class CommitteeLedgerApp extends StatefulWidget {
  const CommitteeLedgerApp({super.key});

  @override
  State<CommitteeLedgerApp> createState() => _CommitteeLedgerAppState();
}

class _CommitteeLedgerAppState extends State<CommitteeLedgerApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthState>();
    _router = createRouter(authState);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp.router(
      title: 'Committee Ledger',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.currentTheme,
      routerConfig: _router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('ne', 'NP'), // Nepali localization support
      ],
    );
  }
}
