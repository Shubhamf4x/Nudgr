import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/color_constants.dart';
import '../../core/utils/smooth_transitions.dart';
import '../../features/focus/focus_screen.dart';
import '../../features/notes/notes_screen.dart';
import '../../features/calendar/calendar_screen.dart';
import '../../features/steps/steps_screen.dart';
import '../../features/world_clock/world_clock_screen.dart';

class FloatingPillNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const FloatingPillNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<FloatingPillNavBar> createState() => _FloatingPillNavBarState();
}

class _FloatingPillNavBarState extends State<FloatingPillNavBar>
    with SingleTickerProviderStateMixin {
  bool _isFabOpen = false;
  late AnimationController _fabController;
  late Animation<double> _fabAnimation;
  OverlayEntry? _radialOverlay;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabController,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void dispose() {
    _removeOverlay();
    _fabController.dispose();
    super.dispose();
  }

  void _removeOverlay() {
    _radialOverlay?.remove();
    _radialOverlay = null;
  }

  void _toggleFab() {
    HapticFeedback.lightImpact();
    setState(() {
      _isFabOpen = !_isFabOpen;
      if (_isFabOpen) {
        _fabController.forward();
        _showRadialMenu();
      } else {
        _fabController.reverse();
        _removeOverlay();
      }
    });
  }

  void _closeFab() {
    if (_isFabOpen) {
      setState(() {
        _isFabOpen = false;
        _fabController.reverse();
        _removeOverlay();
      });
    }
  }

  void _showRadialMenu() {
    _removeOverlay();
    _radialOverlay = OverlayEntry(
      builder: (context) => _RadialMenuOverlay(
        animation: _fabAnimation,
        onClose: _closeFab,
        onActionTap: _onFabActionTap,
      ),
    );
    Overlay.of(context).insert(_radialOverlay!);
  }

  void _onFabActionTap(String screen) {
    _closeFab();
    Widget? targetScreen;
    switch (screen) {
      case 'focus':
        targetScreen = const FocusScreen();
        break;
      case 'notes':
        targetScreen = const NotesScreen();
        break;
      case 'calendar':
        targetScreen = const CalendarScreen();
        break;
      case 'steps':
        targetScreen = const StepsScreen();
        break;
      case 'clock':
        targetScreen = const WorldClockScreen();
        break;
    }
    if (targetScreen != null) {
      context.pushSmooth(targetScreen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bp = MediaQuery.of(context).padding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: SizedBox(
        height: 64 + bp,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            _buildPill(isDark, bp),
            _buildCenterFab(isDark, bp),
          ],
        ),
      ),
    );
  }

  Widget _buildPill(bool isDark, double bp) {
    return Positioned(
      bottom: bp,
      left: 20,
      right: 20,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(child: _buildPillIcon(0, isDark)),
            Expanded(child: _buildPillIcon(1, isDark)),
            const SizedBox(width: 52),
            Expanded(child: _buildPillIcon(3, isDark)),
            Expanded(child: _buildPillIcon(4, isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildPillIcon(int index, bool isDark) {
    final isSelected = widget.currentIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap(index);
      },
      child: SizedBox(
        height: 52,
        child: Center(
          child: Icon(
            _getItemIcon(index),
            size: 22,
            color: isSelected
                ? ColorConstants.primary
                : (isDark ? Colors.white38 : Colors.grey.shade400),
          ),
        ),
      ),
    );
  }

  Widget _buildCenterFab(bool isDark, double bp) {
    final cx = MediaQuery.of(context).size.width / 2;

    return Positioned(
      left: cx - 24,
      bottom: bp + 26,
      child: GestureDetector(
        onTap: _toggleFab,
        child: AnimatedScale(
          scale: _isFabOpen ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              shape: BoxShape.circle,
              border: Border.all(
                color: ColorConstants.primary.withValues(alpha: 0.4),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: ColorConstants.primary.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: AnimatedRotation(
              turns: _isFabOpen ? 0.125 : 0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: Icon(
                _isFabOpen ? Icons.close_rounded : Icons.add_rounded,
                size: 22,
                color: ColorConstants.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getItemIcon(int index) {
    switch (index) {
      case 0: return Icons.home_rounded;
      case 1: return Icons.check_circle_outline_rounded;
      case 3: return Icons.chat_bubble_outline_rounded;
      case 4: return Icons.person_outline_rounded;
      default: return Icons.circle;
    }
  }
}

class _RadialMenuOverlay extends StatefulWidget {
  final Animation<double> animation;
  final VoidCallback onClose;
  final ValueChanged<String> onActionTap;

  const _RadialMenuOverlay({
    required this.animation,
    required this.onClose,
    required this.onActionTap,
  });

  @override
  State<_RadialMenuOverlay> createState() => _RadialMenuOverlayState();
}

class _RadialMenuOverlayState extends State<_RadialMenuOverlay> {
  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;
    final bp = MediaQuery.of(context).padding.bottom;
    final centerX = sw / 2;
    final fabY = sh - bp - 64 + 26;

    final actions = [
      _FabData(icon: Icons.timer_rounded, screen: 'focus'),
      _FabData(icon: Icons.note_alt_rounded, screen: 'notes'),
      _FabData(icon: Icons.calendar_month_rounded, screen: 'calendar'),
      _FabData(icon: Icons.directions_walk_rounded, screen: 'steps'),
      _FabData(icon: Icons.access_time_rounded, screen: 'clock'),
    ];

    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, _) {
        if (widget.animation.value == 0.0) return const SizedBox.shrink();

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: widget.onClose,
                child: Container(color: Colors.black45),
              ),
            ),
            ...List.generate(actions.length, (index) {
              final action = actions[index];
              final startAngle = -pi * 0.08;
              final endAngle = -pi * 0.92;
              final angle = startAngle +
                  (endAngle - startAngle) * (index / (actions.length - 1));
              final radius = 110.0;
              final itemAnim =
                  (widget.animation.value - index * 0.07).clamp(0.0, 1.0);
              final slide = Curves.easeOutBack.transform(itemAnim);

              final x = centerX + cos(angle) * radius * slide - 26;
              final y = fabY + sin(angle) * radius * slide - 26;

              return Positioned(
                left: x,
                top: y,
                child: Transform.scale(
                  scale: slide,
                  child: Opacity(
                    opacity: itemAnim,
                    child: GestureDetector(
                      onTap: () => widget.onActionTap(action.screen),
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C4DFF),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7C4DFF).withValues(alpha: 0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(action.icon, size: 24, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _FabData {
  final IconData icon;
  final String screen;
  const _FabData({required this.icon, required this.screen});
}

