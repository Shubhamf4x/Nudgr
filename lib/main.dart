import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:provider/provider.dart';

import 'core/config/firebase_configuration.dart';
import 'core/platform/platform_capabilities.dart';
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
  runApp(const NudgrApp());
}

class NudgrApp extends StatefulWidget {
  const NudgrApp({super.key});
  @override
  State<NudgrApp> createState() => _NudgrAppState();
}

class _NudgrAppState extends State<NudgrApp> {
  AuthProvider? _authProvider;
  HomeProvider? _homeProvider;
  TasksProvider? _tasksProvider;
  NotesProvider? _notesProvider;
  CalendarProvider? _calendarProvider;
  FocusProvider? _focusProvider;
  Future<void> Function()? _pullListener;
  String? _bootstrapFailure;
  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    if (kIsWeb && FirebaseConfiguration.webOptions == null) {
      setState(() {
        _authProvider = null;
        _bootstrapFailure =
            'This web build has no Firebase configuration. Rebuild with '
            'FIREBASE_WEB_API_KEY and FIREBASE_WEB_APP_ID dart-defines — see '
            'CROSS_PLATFORM_SETUP.md. Until then, cloud accounts and sync '
            'cannot start.';
      });
      return;
    }
    AuthProvider? provider;
    String? failure;
    try {
      await Firebase.initializeApp(
        options: kIsWeb ? FirebaseConfiguration.webOptions : null,
      );
      try {
        if (PlatformCapabilities.isAndroid) {
          await FirebaseAppCheck.instance.activate(
            androidProvider: kDebugMode
                ? AndroidProvider.debug
                : AndroidProvider.playIntegrity,
          );
        } else if (kIsWeb &&
            FirebaseConfiguration.webRecaptchaSiteKey.isNotEmpty) {
          await FirebaseAppCheck.instance.activate(
            webProvider: ReCaptchaV3Provider(
              FirebaseConfiguration.webRecaptchaSiteKey,
            ),
          );
        }
      } catch (_) {}
      await DatabaseService.getInstance().initialize();
      await AuthService.getInstance().initialize();
      await StepsService.getInstance().initialize();
      await NotificationService.getInstance().initialize();
      await SyncService.getInstance().initialize();
      final homeProvider = HomeProvider();
      final tasksProvider = TasksProvider();
      final notesProvider = NotesProvider();
      final calendarProvider = CalendarProvider();
      final focusProvider = FocusProvider();
      setState(() {
        _homeProvider = homeProvider;
        _tasksProvider = tasksProvider;
        _notesProvider = notesProvider;
        _calendarProvider = calendarProvider;
        _focusProvider = focusProvider;
      });
      final syncService = SyncService.getInstance();
      final previousListener = _pullListener;
      if (previousListener != null) {
        syncService.removePullListener(previousListener);
      }
      Future<void> pullListener() async {
        try {
          await tasksProvider.loadData();
          await notesProvider.loadData();
          await calendarProvider.loadData();
          await focusProvider.loadData();
          await homeProvider.loadData(homeProvider.state.userName);
        } catch (_) {}
      }

      syncService.addPullListener(pullListener);
      _pullListener = pullListener;
      provider = AuthProvider();
      await provider.initialize();
    } catch (e) {
      debugPrint('Startup bootstrap failed: $e');
      failure = 'Could not start up. Check your connection and try again.';
      provider = null;
    }
    if (!mounted) return;
    setState(() {
      _authProvider = provider;
      _bootstrapFailure = failure;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = _authProvider;
    if (authProvider == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF10101C),
          colorScheme: const ColorScheme.dark(primary: Color(0xFF6C63FF)),
        ),
        home: _BrandedSplash(
          message: _bootstrapFailure,
          onRetry:
              _bootstrapFailure == null ||
                  (kIsWeb && FirebaseConfiguration.webOptions == null)
              ? null
              : () {
                  setState(() => _bootstrapFailure = null);
                  unawaited(_bootstrap());
                },
        ),
      );
    }
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SyncProvider()..startPolling()),
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider.value(value: _homeProvider ?? HomeProvider()),
        ChangeNotifierProvider.value(value: _tasksProvider ?? TasksProvider()),
        ChangeNotifierProvider.value(value: _notesProvider ?? NotesProvider()),
        ChangeNotifierProvider.value(
          value: _calendarProvider ?? CalendarProvider(),
        ),
        ChangeNotifierProvider.value(value: _focusProvider ?? FocusProvider()),
        ChangeNotifierProvider(create: (_) => StepsProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => MeshChatProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Nudgr',
            debugShowCheckedModeBanner: false,
            theme: themeProvider.theme,
            home: const AuthGate(),
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

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        switch (auth.state) {
          case AuthState.initial:
          case AuthState.loading:
            return Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              body: const Center(
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            );
          case AuthState.authenticated:
            return auth.onboardingComplete
                ? const MainShell()
                : const OnboardingScreen();
          case AuthState.unauthenticated:
          case AuthState.error:
            return const LoginScreen();
        }
      },
    );
  }
}

class _BrandedSplash extends StatelessWidget {
  const _BrandedSplash({this.message, this.onRetry});
  final String? message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) {
    final message = this.message;
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6C63FF), Color(0xFF8B85FF)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
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
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'N',
                          style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6C63FF),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Nudgr',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (message != null)
                      Column(
                        children: [
                          Text(
                            message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                          if (onRetry != null) ...[
                            const SizedBox(height: 16),
                            TextButton.icon(
                              onPressed: onRetry,
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('Retry'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.white24,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ],
                        ],
                      )
                    else
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white70,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
