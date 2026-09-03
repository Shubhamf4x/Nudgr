import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'shared/providers/theme_provider.dart';
import 'shared/providers/sync_provider.dart';
import 'core/services/database_service.dart';
import 'core/services/auth_service.dart';
import 'core/services/steps_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/sync_service.dart';
import 'features/auth/auth_provider.dart';
import 'features/home/home_provider.dart';
import 'features/tasks/tasks_provider.dart';
import 'features/notes/notes_provider.dart';
import 'features/calendar/calendar_provider.dart';
import 'features/focus/focus_provider.dart';
import 'features/steps/steps_provider.dart';
import 'features/chat/providers/mesh_chat_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/onboarding_screen.dart';
import 'features/main_shell.dart';

void main() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught platform error: $error\n$stack');
    return true;
  };

  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NudgrBootstrap());
}

class NudgrBootstrap extends StatefulWidget {
  const NudgrBootstrap({super.key});

  @override
  State<NudgrBootstrap> createState() => _NudgrBootstrapState();
}

class _NudgrBootstrapState extends State<NudgrBootstrap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  Widget? _app;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      await Firebase.initializeApp();
    } catch (_) {}

    unawaited(
      FirebaseAppCheck.instance
          .activate(
            androidProvider: kDebugMode
                ? AndroidProvider.debug
                : AndroidProvider.playIntegrity,
          )
          .catchError((_) {}),
    );

    await DatabaseService.getInstance().initialize();
    await AuthService.getInstance().initialize();
    await StepsService.getInstance().initialize();
    await NotificationService.getInstance().initialize();
    await SyncService.getInstance().initialize();

    final authProvider = AuthProvider();
    await authProvider.initialize();

    final prefs = await SharedPreferences.getInstance();
    final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;

    final Widget startupScreen;
    if (authProvider.isAuthenticated) {
      startupScreen =
          onboardingComplete ? const MainShell() : const OnboardingScreen();
    } else {
      startupScreen = const LoginScreen();
    }

    if (!mounted) return;
    setState(() {
      _app = NudgrApp(startupScreen: startupScreen, authProvider: authProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = _app;
    if (app == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeProvider().theme,
        home: FadeTransition(
          opacity: _fadeAnimation,
          child: const _BrandedLoader(),
        ),
      );
    }
    return app;
  }
}

class _BrandedLoader extends StatelessWidget {
  const _BrandedLoader();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF3B5998), Color(0xFF1A3A6E), Color(0xFF0F2248)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'N',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF3B5998),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Nudgr',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 28),
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NudgrApp extends StatelessWidget {
  final Widget startupScreen;
  final AuthProvider authProvider;

  const NudgrApp({
    super.key,
    required this.startupScreen,
    required this.authProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SyncProvider()..startPolling()),
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => HomeProvider()),
        ChangeNotifierProvider(create: (_) => TasksProvider()),
        ChangeNotifierProvider(create: (_) => NotesProvider()),
        ChangeNotifierProvider(create: (_) => CalendarProvider()),
        ChangeNotifierProvider(create: (_) => FocusProvider()),
        ChangeNotifierProvider(create: (_) => StepsProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => MeshChatProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Nudgr',
            debugShowCheckedModeBanner: false,
            theme: themeProvider.theme,
            home: startupScreen,
            routes: {
              '/login': (_) => const LoginScreen(),
              '/home': (_) => const MainShell(),
            },
          );
        },
      ),
    );
  }
}
