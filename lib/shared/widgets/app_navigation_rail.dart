import 'package:flutter/material.dart';

import '../../core/constants/color_constants.dart';
import '../../core/utils/responsive.dart';
import '../../features/calendar/calendar_screen.dart';
import '../../features/focus/focus_screen.dart';
import '../../features/notes/notes_screen.dart';
import '../../features/steps/steps_screen.dart';
import '../../features/world_clock/world_clock_screen.dart';

/// A tool destination reachable from the rail.
enum RailTool { focus, notes, calendar, steps, clock }

extension RailToolInfo on RailTool {
  String get label => switch (this) {
    RailTool.focus => 'Focus',
    RailTool.notes => 'Notes',
    RailTool.calendar => 'Calendar',
    RailTool.steps => 'Steps',
    RailTool.clock => 'World Clock',
  };

  IconData get icon => switch (this) {
    RailTool.focus => Icons.timer_rounded,
    RailTool.notes => Icons.note_alt_rounded,
    RailTool.calendar => Icons.calendar_month_rounded,
    RailTool.steps => Icons.directions_walk_rounded,
    RailTool.clock => Icons.access_time_rounded,
  };

  Widget build() => switch (this) {
    RailTool.focus => const FocusScreen(),
    RailTool.notes => const NotesScreen(),
    RailTool.calendar => const CalendarScreen(),
    RailTool.steps => const StepsScreen(),
    RailTool.clock => const WorldClockScreen(),
  };
}

/// Wide-window navigation.
///
/// Replaces the bottom pill on desktop/tablet widths. It exposes the four
/// primary destinations *and* the five tools, because on a wide window the
/// radial FAB menu that normally reaches the tools is gone — leaving them
/// unreachable, which is a dead end rather than a layout quirk.
///
/// Tools render inside the shell (see [MainShell]) instead of being pushed as
/// full-screen routes, so the rail stays visible and there is always a way back.
class AppNavigationRail extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final RailTool? activeTool;
  final ValueChanged<RailTool> onToolSelected;

  const AppNavigationRail({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.activeTool,
    required this.onToolSelected,
  });

  static const List<({int index, IconData icon, String label})> _primary = [
    (index: 0, icon: Icons.home_rounded, label: 'Home'),
    (index: 1, icon: Icons.check_circle_outline_rounded, label: 'Tasks'),
    (index: 3, icon: Icons.chat_bubble_outline_rounded, label: 'Chat'),
    (index: 4, icon: Icons.person_outline_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 96,
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        border: Border(
          right: BorderSide(
            color: isDark
                ? Colors.white10
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: SafeArea(
        right: false,
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 16),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: ColorConstants.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Text(
                    'N',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              for (final item in _primary)
                _RailButton(
                  icon: item.icon,
                  label: item.label,
                  selected: activeTool == null && currentIndex == item.index,
                  onTap: () => onTap(item.index),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                child: Divider(
                  height: 1,
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
              for (final tool in RailTool.values)
                _RailButton(
                  icon: tool.icon,
                  label: tool.label,
                  selected: activeTool == tool,
                  onTap: () => onToolSelected(tool),
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RailButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = selected
        ? ColorConstants.primary
        : (isDark ? Colors.white60 : Colors.black54);
    return Tooltip(
      message: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 24, color: color),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Wraps a tool screen shown inside the shell with a visible way back.
///
/// Tool screens were designed as pushed routes; on desktop there is no system
/// back button, so entering one from the rail would trap the user.
class ToolPane extends StatelessWidget {
  final RailTool tool;
  final VoidCallback onClose;
  const ToolPane({super.key, required this.tool, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
          child: Row(
            children: [
              IconButton(
                onPressed: onClose,
                tooltip:
                    'Back to ${Responsive.useNavigationRail(context) ? 'home' : 'app'}',
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 4),
              Text(
                tool.label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Expanded(child: tool.build()),
      ],
    );
  }
}
