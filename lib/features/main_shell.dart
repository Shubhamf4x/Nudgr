import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/platform/platform_capabilities.dart';
import '../core/services/notification_service.dart';
import '../core/utils/responsive.dart';
import '../shared/widgets/app_navigation_rail.dart';
import '../shared/widgets/floating_pill_nav_bar.dart';
import 'home/home_provider.dart';
import 'home/home_screen.dart';
import 'tasks/tasks_provider.dart';
import 'tasks/tasks_screen.dart';
import 'chat/screens/mesh_chat_screen.dart';
import 'profile/profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  RailTool? _activeTool;

  static const List<Widget> _screens = [
    HomeScreen(key: PageStorageKey('home')),
    TasksScreen(key: PageStorageKey('tasks')),
    SizedBox.shrink(),
    MeshChatScreen(key: PageStorageKey('chat')),
    ProfileScreen(key: PageStorageKey('profile')),
  ];

  static const List<bool> _selectable = [true, true, false, true, true];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (PlatformCapabilities.hasLocalNotifications) {
        NotificationService.requestPermissionOnce(context);
      }
    });
  }

  void _select(int index) {
    if (!_selectable[index]) return;
    if (index == _currentIndex && _activeTool == null) return;
    if (PlatformCapabilities.isMobile) {
      HapticFeedback.selectionClick();
    }
    setState(() {
      _activeTool = null;
      _currentIndex = index;
    });
    _refreshVisibleProviders(index);
  }

  void _refreshVisibleProviders(int index) {
    try {
      switch (index) {
        case 0:
          final home = context.read<HomeProvider>();
          unawaited(home.loadData(home.state.userName));
          break;
        case 1:
          context.read<TasksProvider>().initialize();
          break;
      }
    } catch (_) {}
  }

  void _openTool(RailTool tool) => setState(() => _activeTool = tool);

  void _closeTool() => setState(() => _activeTool = null);

  @override
  Widget build(BuildContext context) {
    final useRail = Responsive.useNavigationRail(context);
    final body = _activeTool != null
        ? ToolPane(tool: _activeTool!, onClose: _closeTool)
        : AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: _screens[_currentIndex],
          );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: Theme.of(context).brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: PopScope(
        canPop: _activeTool == null,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (_activeTool != null) {
            _closeTool();
            return;
          }
          if (PlatformCapabilities.hasSystemBackButton) {
            SystemNavigator.pop();
          }
        },
        child: Scaffold(
          body: useRail
              ? Row(
                  children: [
                    AppNavigationRail(
                      currentIndex: _currentIndex,
                      onTap: _select,
                      activeTool: _activeTool,
                      onToolSelected: _openTool,
                    ),
                    Expanded(child: body),
                  ],
                )
              : body,
          bottomNavigationBar: useRail
              ? null
              : FloatingPillNavBar(currentIndex: _currentIndex, onTap: _select),
        ),
      ),
    );
  }
}
