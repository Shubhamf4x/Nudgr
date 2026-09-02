import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/services/notification_service.dart';
import 'home/home_screen.dart';
import 'tasks/tasks_screen.dart';
import 'chat/screens/mesh_chat_screen.dart';
import 'profile/profile_screen.dart';
import '../shared/widgets/floating_pill_nav_bar.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const HomeScreen(key: PageStorageKey('home')),
      const TasksScreen(key: PageStorageKey('tasks')),
      const SizedBox.shrink(),
      const MeshChatScreen(key: PageStorageKey('chat')),
      const ProfileScreen(key: PageStorageKey('profile')),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      NotificationService.requestPermissionOnce(context);
    });
  }

  Widget _buildScreen(int index) {
    return _screens[index];
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: Theme.of(context).brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (Platform.isAndroid) {
            SystemNavigator.pop();
          }
        },
        child: Scaffold(
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            child: _buildScreen(_currentIndex),
          ),
          bottomNavigationBar: FloatingPillNavBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              if (index != 2) {
                HapticFeedback.selectionClick();
                setState(() => _currentIndex = index);
              }
            },
          ),
        ),
      ),
    );
  }
}
