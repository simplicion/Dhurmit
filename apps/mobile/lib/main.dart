import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'app/router/app_router.dart';
import 'app/router/startup_splash_screen.dart';
import 'core/api/api_client.dart';
import 'core/api/auth_state.dart';
import 'core/theme/theme_provider.dart';
import 'core/sync/offline_cache_store.dart';
import 'core/sync/sync_engine.dart';
import 'core/location/country_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[FLUTTER ERROR CAUGHT] ${details.exceptionAsString()}\n${details.stack}');
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.white,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 40),
              const SizedBox(height: 8),
              const Text('Render Error', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
              const SizedBox(height: 8),
              Text(
                details.exceptionAsString(),
                style: const TextStyle(fontSize: 12, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  };

  // Immediate synchronous runApp call:
  // Guarantees Frame 1 renders within 16ms, immediately dismissing Android 12+ native splash screen!
  runApp(const DhurmitAppBootstrap());
}

/// Root Bootstrap widget that renders Frame 1 immediately and initializes local services
class DhurmitAppBootstrap extends StatefulWidget {
  const DhurmitAppBootstrap({super.key});

  @override
  State<DhurmitAppBootstrap> createState() => _DhurmitAppBootstrapState();
}

class _DhurmitAppBootstrapState extends State<DhurmitAppBootstrap> {
  bool _isReady = false;
  final ApiClient _apiClient = ApiClient();
  final ThemeProvider _themeProvider = ThemeProvider();
  final CountryProvider _countryProvider = CountryProvider();
  late final AuthState _authState;
  late final OfflineCacheStore _cacheStore;
  late final SyncEngine _syncEngine;

  @override
  void initState() {
    super.initState();
    _bootstrapServices();
  }

  Future<void> _bootstrapServices() async {
    try {
      _authState = AuthState(apiClient: _apiClient);
      _cacheStore = await OfflineCacheStore.initialize();
      _syncEngine = SyncEngine(apiClient: _apiClient, cacheStore: _cacheStore);
    } catch (e, stack) {
      debugPrint('[BOOTSTRAP INIT ERROR] $e\n$stack');
      _authState = AuthState(apiClient: _apiClient);
      try {
        _cacheStore = await OfflineCacheStore.initialize();
      } catch (_) {
        // Fallback or ignore in worst-case scenario
      }
      _syncEngine = SyncEngine(apiClient: _apiClient, cacheStore: _cacheStore);
    } finally {
      if (mounted) {
        setState(() {
          _isReady = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      // Instant frame-1 rendering while services initialize in background (~30ms)
      return ChangeNotifierProvider<ThemeProvider>.value(
        value: _themeProvider,
        child: const MaterialApp(
          title: 'Dhurmit',
          debugShowCheckedModeBanner: false,
          home: StartupSplashScreen(),
        ),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: _themeProvider),
        ChangeNotifierProvider<AuthState>.value(value: _authState),
        ChangeNotifierProvider<CountryProvider>.value(value: _countryProvider),
        Provider<OfflineCacheStore>.value(value: _cacheStore),
        ChangeNotifierProvider<SyncEngine>.value(value: _syncEngine),
      ],
      child: const CommitteeLedgerApp(),
    );
  }
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
