import 'dart:math';

import '../../core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../core/constants/color_constants.dart';
import '../../shared/widgets/task_card.dart';
import 'calendar_provider.dart';

enum CalendarView { month, week, day }

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarView _selectedView = CalendarView.month;

  static final Map<DateTime, String> _internationalHolidays = {
    DateTime.utc(2026, 1, 1): '🎆',
    DateTime.utc(2026, 1, 26): '🇮🇳',
    DateTime.utc(2026, 2, 14): '💝',
    DateTime.utc(2026, 3, 8): '👩',
    DateTime.utc(2026, 4, 14): '🇮🇳',
    DateTime.utc(2026, 5, 1): '👷',
    DateTime.utc(2026, 8, 15): '🇮🇳',
    DateTime.utc(2026, 10, 2): '🇮🇳',
    DateTime.utc(2026, 10, 31): '🎃',
    DateTime.utc(2026, 11, 1): '🎃',
    DateTime.utc(2026, 11, 11): '🪔',
    DateTime.utc(2026, 12, 25): '🎄',
    DateTime.utc(2026, 12, 31): '🎉',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CalendarProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, isDark),
            _buildViewSelector(context, isDark),
            Selector<CalendarProvider, DateTime>(
              selector: (_, p) => p.state.focusedDate,
              builder: (context, focusedDay, _) {
                return _buildMonthNavigation(context, focusedDay, isDark);
              },
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Selector<CalendarProvider, ({DateTime focusedDate, List<dynamic> tasks})>(
                      selector: (_, p) => (focusedDate: p.state.focusedDate, tasks: p.state.tasks),
                      builder: (context, data, _) {
                        return _buildCalendar(context, data.focusedDate, data.tasks, isDark);
                      },
                    ),
                    const SizedBox(height: 8),
                    Selector<CalendarProvider, ({DateTime selectedDate, List<dynamic> tasks})>(
                      selector: (_, p) => (selectedDate: p.state.selectedDate, tasks: p.state.tasks),
                      builder: (context, data, _) {
                        return _buildSelectedDayTasks(context, data.selectedDate, data.tasks, isDark);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Calendar',
            style: AppTextStyles.googleSans(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: theme.textTheme.titleLarge?.color,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: ColorConstants.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.calendar_month_rounded,
              size: 22,
              color: ColorConstants.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewSelector(BuildContext context, bool isDark) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: CalendarView.values.map((view) {
            final isSelected = _selectedView == view;
            final label = view == CalendarView.month
                ? 'Month'
                : view == CalendarView.week
                    ? 'Week'
                    : 'Day';
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedView = view),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? ColorConstants.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: ColorConstants.primary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      label,
                      style: AppTextStyles.googleSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : theme.textTheme.bodySmall?.color ?? Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMonthNavigation(
      BuildContext context, DateTime focused, bool isDark) {
    final theme = Theme.of(context);
    final monthName = _getMonthName(focused.month);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildNavButton(
            icon: Icons.chevron_left_rounded,
            onTap: () {
              final newDate = DateTime(focused.year, focused.month - 1, 1);
              context.read<CalendarProvider>().focusOnDate(newDate);
            },
          ),
          Text(
            '$monthName ${focused.year}',
            style: AppTextStyles.googleSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: theme.textTheme.titleLarge?.color,
            ),
          ),
          _buildNavButton(
            icon: Icons.chevron_right_rounded,
            onTap: () {
              final newDate = DateTime(focused.year, focused.month + 1, 1);
              context.read<CalendarProvider>().focusOnDate(newDate);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: ColorConstants.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 22, color: ColorConstants.primary),
      ),
    );
  }

  Widget _buildCalendar(BuildContext context, DateTime focusedDay, List<dynamic> tasks, bool isDark) {
    switch (_selectedView) {
      case CalendarView.month:
        return _buildMonthView(context, focusedDay, tasks, isDark);
      case CalendarView.week:
        return _buildWeekView(context, focusedDay, tasks, isDark);
      case CalendarView.day:
        return _buildDayView(context, focusedDay, tasks, isDark);
    }
  }

  Widget _buildMonthView(
      BuildContext context, DateTime focusedDay, List<dynamic> tasks, bool isDark) {
    final theme = Theme.of(context);

    return TableCalendar(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: focusedDay,
      calendarFormat: CalendarFormat.month,
      rowHeight: 44,
      daysOfWeekHeight: 32,
      daysOfWeekVisible: true,
      selectedDayPredicate: (day) {
        final provider = context.read<CalendarProvider>();
        return isSameDay(day, provider.state.selectedDate);
      },
      onDaySelected: (selectedDay, focusedDay) {
        final provider = context.read<CalendarProvider>();
        provider.selectDate(selectedDay);
        provider.focusOnDate(focusedDay);
      },
      onPageChanged: (focusedDay) {
        context.read<CalendarProvider>().focusOnDate(focusedDay);
      },
      eventLoader: (day) {
        final normalizedDay = DateTime(day.year, day.month, day.day);
        return tasks.where((t) {
          if (t.dueDate == null) return false;
          return t.dueDate!.year == normalizedDay.year &&
              t.dueDate!.month == normalizedDay.month &&
              t.dueDate!.day == normalizedDay.day;
        }).toList();
      },
      calendarStyle: CalendarStyle(
        outsideDaysVisible: true,
        todayDecoration: const BoxDecoration(
          color: Color(0xFFFF9500),
          shape: BoxShape.circle,
        ),
        todayTextStyle: AppTextStyles.googleSans(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        selectedDecoration: BoxDecoration(
          color: ColorConstants.primary,
          shape: BoxShape.circle,
        ),
        selectedTextStyle: AppTextStyles.googleSans(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        defaultDecoration: const BoxDecoration(
          shape: BoxShape.circle,
        ),
        defaultTextStyle: AppTextStyles.googleSans(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: theme.textTheme.bodyLarge?.color,
        ),
        weekendDecoration: const BoxDecoration(
          shape: BoxShape.circle,
        ),
        weekendTextStyle: AppTextStyles.googleSans(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: theme.textTheme.bodyLarge?.color,
        ),
        markerDecoration: const BoxDecoration(
          color: ColorConstants.secondary,
          shape: BoxShape.circle,
        ),
        markerSize: 5,
        markersMaxCount: 3,
        markerMargin: const EdgeInsets.only(top: 2),
      ),
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        leftChevronVisible: false,
        rightChevronVisible: false,
        titleTextStyle: TextStyle(fontSize: 0),
      ),
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: AppTextStyles.googleSans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade500,
        ),
        weekendStyle: AppTextStyles.googleSans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade500,
        ),
      ),
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, focusedDay) =>
            _buildDayCell(context, day, isDark),
        todayBuilder: (context, day, focusedDay) =>
            _buildDayCell(context, day, isDark, isToday: true),
        selectedBuilder: (context, day, focusedDay) =>
            _buildDayCell(context, day, isDark, isSelected: true),
        outsideBuilder: (context, day, focusedDay) =>
            _buildDayCell(context, day, isDark, isOutside: true),
      ),
    );
  }

  Widget _buildDayCell(
    BuildContext context,
    DateTime day,
    bool isDark, {
    bool isToday = false,
    bool isSelected = false,
    bool isOutside = false,
  }) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final provider = context.read<CalendarProvider>();
    final hasEvents =
        (provider.state.tasksByDate[normalizedDay]?.isNotEmpty ?? false);
    final holidayEmoji = _internationalHolidays[
        DateTime.utc(day.year, day.month, day.day)];

    return Center(
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected
              ? ColorConstants.primary
              : isToday
                  ? const Color(0xFFFF9500)
                  : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              holidayEmoji ?? '${day.day}',
              style: AppTextStyles.googleSans(
                fontSize: 13,
                fontWeight:
                    isSelected || isToday ? FontWeight.w700 : FontWeight.w500,
                color: isSelected || isToday
                    ? Colors.white
                    : isOutside
                        ? Colors.grey.withValues(alpha: 0.4)
                        : isDark
                            ? Colors.white70
                            : Colors.black87,
              ),
            ),
            if (hasEvents)
              Positioned(
                bottom: 4,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    min(
                        provider.state.tasksByDate[normalizedDay]?.length ?? 0, 3),
                    (i) => Container(
                      width: 4,
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: isSelected || isToday
                            ? Colors.white.withValues(alpha: 0.8)
                            : ColorConstants.secondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekView(
      BuildContext context, DateTime focusedDay, List<dynamic> tasks, bool isDark) {
    final startOfWeek = focusedDay.subtract(Duration(days: focusedDay.weekday - 1));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                  .map((day) => Expanded(
                        child: Center(
                          child: Text(
                            day,
                            style: AppTextStyles.googleSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(7, (index) {
              final day = startOfWeek.add(Duration(days: index));
              final normalizedDay = DateTime(day.year, day.month, day.day);
              final isToday = isSameDay(day, DateTime.now());
              final provider = context.read<CalendarProvider>();
              final isSelected = isSameDay(day, provider.state.selectedDate);
              final hasEvents = tasks.any((t) {
                if (t.dueDate == null) return false;
                return t.dueDate!.year == normalizedDay.year &&
                    t.dueDate!.month == normalizedDay.month &&
                    t.dueDate!.day == normalizedDay.day;
              });

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    provider.selectDate(day);
                    provider.focusOnDate(day);
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? ColorConstants.primary
                              : isToday
                                  ? const Color(0xFFFF9500)
                                  : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: AppTextStyles.googleSans(
                              fontSize: 14,
                              fontWeight: isSelected || isToday
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected || isToday
                                  ? Colors.white
                                  : isDark
                                      ? Colors.white70
                                      : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                      if (hasEvents) ...[
                        const SizedBox(height: 4),
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isSelected || isToday
                                ? Colors.white.withValues(alpha: 0.8)
                                : ColorConstants.secondary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildDayView(
      BuildContext context, DateTime focusedDay, List<dynamic> tasks, bool isDark) {
    final theme = Theme.of(context);
    final provider = context.read<CalendarProvider>();
    final tasks = provider.state.tasksForSelectedDate;

    return SizedBox(
      height: 400,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 24,
        itemBuilder: (context, index) {
          final hour = index;
          final hourTasks = tasks.where((t) {
            if (t.dueTime == null) return false;
            return t.dueTime!.hour == hour;
          }).toList();

          return Container(
            margin: const EdgeInsets.only(bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 48,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      '${hour.toString().padLeft(2, '0')}:00',
                      style: AppTextStyles.googleSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 56),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade800 : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark
                            ? Colors.grey.shade700
                            : Colors.grey.shade300,
                        width: 1.0,
                      ),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: hourTasks.isNotEmpty
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: hourTasks
                                .map((t) => Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 4,
                                            height: 16,
                                            decoration: BoxDecoration(
                                              color: ColorConstants.primary,
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              t.title,
                                              style: AppTextStyles.googleSans(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color:
                                                    theme.textTheme.bodyLarge?.color,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ))
                                .toList(),
                          )
                        : null,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectedDayTasks(
      BuildContext context, DateTime selectedDay, List<dynamic> tasks, bool isDark) {
    final theme = Theme.of(context);
    final provider = context.read<CalendarProvider>();
    final tasks = provider.state.tasksForSelectedDate;
    final selected = selectedDay;
    final dateLabel =
        '${selected.day} ${_getMonthName(selected.month)} ${selected.year}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dateLabel,
                style: AppTextStyles.googleSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: theme.textTheme.titleLarge?.color,
                ),
              ),
              if (tasks.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: ColorConstants.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${tasks.length} task${tasks.length > 1 ? 's' : ''}',
                    style: AppTextStyles.googleSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: ColorConstants.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (tasks.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.grey.shade700
                      : Colors.grey.shade300,
                  width: 1.0,
                ),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.event_available_rounded,
                      size: 40,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No tasks for this day',
                      style: AppTextStyles.googleSans(
                        color: Colors.grey,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...tasks.map((task) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TaskCard(task: task),
                )),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const names = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return names[month];
  }
}
