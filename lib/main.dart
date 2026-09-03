import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:provider/provider.dart';
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

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    AuthProvider? provider;
    try {
      await Firebase.initializeApp();

      try {
        await FirebaseAppCheck.instance.activate(
          androidProvider: kDebugMode
              ? AndroidProvider.debug
              : AndroidProvider.playIntegrity,
        );
      } catch (_) {}

      await DatabaseService.getInstance().initialize();
      await AuthService.getInstance().initialize();
      await StepsService.getInstance().initialize();
      await NotificationService.getInstance().initialize();
      await SyncService.getInstance().initialize();

      provider = AuthProvider();
      await provider.initialize();
    } catch (e) {
      debugPrint('Startup bootstrap failed: $e');
      provider = null;
    }

    if (!mounted) return;
    setState(() => _authProvider = provider);
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
        home: const _BrandedSplash(),
      );
    }

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
        ChangeNotifierProvider(
          create: (_) => StepsProvider()..initialize(),
        ),
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
  const _BrandedSplash();

  @override
  Widget build(BuildContext context) {
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
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
