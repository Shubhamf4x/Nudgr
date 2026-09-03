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

Future<void> main() async {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught platform error: $error\n$stack');
    return true;
  };

  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  unawaited(
    FirebaseAppCheck.instance
        .activate(
          androidProvider:
              kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
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

  authProvider.completeRestore();

  runApp(NudgrApp(authProvider: authProvider));
}

class NudgrApp extends StatelessWidget {
  final AuthProvider authProvider;

  const NudgrApp({
    super.key,
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
