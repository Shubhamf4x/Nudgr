import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/constants/color_constants.dart';
import '../../shared/models/step_model.dart';
import 'steps_provider.dart';

class StepsScreen extends StatefulWidget {
  const StepsScreen({super.key});

  @override
  State<StepsScreen> createState() => _StepsScreenState();
}

class _StepsScreenState extends State<StepsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StepsProvider>().initialize();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Consumer<StepsProvider>(
          builder: (context, provider, _) {
            if (provider.state.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!provider.state.hasSensor) {
              return _buildNoSensorState(theme);
            }

            if (!provider.state.hasPermission) {
              return _buildNoPermissionState(provider, theme);
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    'Steps',
                    style: AppTextStyles.googleSans(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: theme.textTheme.titleLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildStepCounter(provider, theme),
                  const SizedBox(height: 24),
                  _buildStepHistory(provider, theme),
                  const SizedBox(height: 24),
                  _buildCalendarSection(provider, theme),
                  const SizedBox(height: 100),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNoSensorState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_walk_rounded, size: 64, color: Colors.grey.withValues(alpha: 0.5)),
            const SizedBox(height: 20),
            Text(
              'Step Counting',
              style: AppTextStyles.googleSans(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: theme.textTheme.titleLarge?.color,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Step counting isn\'t available\non this device.',
              style: AppTextStyles.googleSans(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoPermissionState(StepsProvider provider, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.health_and_safety_rounded, size: 64, color: ColorConstants.primary.withValues(alpha: 0.5)),
            const SizedBox(height: 20),
            Text(
              'Step Tracking',
              style: AppTextStyles.googleSans(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: theme.textTheme.titleLarge?.color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Permission required',
              style: AppTextStyles.googleSans(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'Track your daily steps automatically.\nAllow Nudgr to count your steps throughout the day.',
              style: AppTextStyles.googleSans(fontSize: 13, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 200,
              height: 44,
              child: ElevatedButton(
                onPressed: () => provider.requestPermission(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorConstants.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text(
                  'Allow',
                  style: AppTextStyles.googleSans(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCounter(StepsProvider provider, ThemeData theme) {
    final steps = provider.state.todaySteps;
    final goal = provider.state.dailyGoal;
    final progress = provider.state.progress;
    final percentage = (progress * 100).toInt();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: ColorConstants.primary.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: provider.state.isTracking ? _pulseAnimation.value : 1.0,
                child: child,
              );
            },
            child: SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 10,
                      backgroundColor: theme.brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(ColorConstants.primary),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _formatNumber(steps),
                        style: AppTextStyles.googleSans(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: theme.textTheme.titleLarge?.color,
                        ),
                      ),
                      Text(
                        'steps today',
                        style: AppTextStyles.googleSans(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '$percentage% of goal',
            style: AppTextStyles.googleSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: ColorConstants.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_formatNumber(goal)} steps',
            style: AppTextStyles.googleSans(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                provider.state.isTracking ? Icons.play_arrow_rounded : Icons.pause_rounded,
                size: 16,
                color: provider.state.isTracking ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 4),
              Text(
                provider.state.isTracking ? 'Tracking active' : 'Tracking paused',
                style: AppTextStyles.googleSans(
                  fontSize: 11,
                  color: provider.state.isTracking ? Colors.green : Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  if (provider.state.isTracking) {
                    provider.pauseTracking();
                  } else {
                    provider.resumeTracking();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: ColorConstants.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    provider.state.isTracking ? 'Pause' : 'Resume',
                    style: AppTextStyles.googleSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: ColorConstants.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Shows a persistent notification with your progress',
            style: AppTextStyles.googleSans(
              fontSize: 10,
              color: Colors.grey.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepHistory(StepsProvider provider, ThemeData theme) {
    final history = List<StepDayModel>.from(provider.state.history)
      ..sort((a, b) => b.date.compareTo(a.date));

    if (history.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step History',
          style: AppTextStyles.googleSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: theme.textTheme.titleLarge?.color,
          ),
        ),
        const SizedBox(height: 12),
        ...history.take(7).map((record) => _buildHistoryTile(record, theme)),
      ],
    );
  }

  Widget _buildHistoryTile(StepDayModel record, ThemeData theme) {
    final date = DateTime.parse(record.date);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final recordDate = DateTime(date.year, date.month, date.day);

    String label;
    if (recordDate == today) {
      label = 'Today';
    } else if (recordDate == today.subtract(const Duration(days: 1))) {
      label = 'Yesterday';
    } else {
      label = '${_monthName(date.month)} ${date.day}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.googleSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          Text(
            '${_formatNumber(record.stepCount)} steps',
            style: AppTextStyles.googleSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: ColorConstants.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarSection(StepsProvider provider, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Calendar',
          style: AppTextStyles.googleSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: theme.textTheme.titleLarge?.color,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(16),
          ),
          child: TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
              _showDayStepsDialog(provider, selectedDay);
            },
            onFormatChanged: (format) {
              setState(() => _calendarFormat = format);
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              todayDecoration: BoxDecoration(
                color: ColorConstants.primary.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: ColorConstants.primary,
                shape: BoxShape.circle,
              ),
              defaultTextStyle: AppTextStyles.googleSans(fontSize: 13),
              todayTextStyle: AppTextStyles.googleSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: AppTextStyles.googleSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              leftChevronIcon: const Icon(Icons.chevron_left_rounded, size: 20),
              rightChevronIcon: const Icon(Icons.chevron_right_rounded, size: 20),
            ),
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedDay) {
                final record = provider.getRecordForDate(day);
                if (record != null && record.stepCount > 0) {
                  return Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: ColorConstants.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${day.day}',
                            style: AppTextStyles.googleSans(fontSize: 12),
                          ),
                          Text(
                            _formatCountShort(record.stepCount),
                            style: AppTextStyles.googleSans(
                              fontSize: 8,
                              color: ColorConstants.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return null;
              },
            ),
          ),
        ),
      ],
    );
  }

  void _showDayStepsDialog(StepsProvider provider, DateTime day) {
    final record = provider.getRecordForDate(day);
    final steps = record?.stepCount ?? 0;
    final dateStr = '${_monthName(day.month)} ${day.day}, ${day.year}';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardTheme.color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          dateStr,
          style: AppTextStyles.googleSans(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        content: Text(
          steps > 0 ? '${_formatNumber(steps)} steps' : 'No data',
          style: AppTextStyles.googleSans(fontSize: 24, fontWeight: FontWeight.w700, color: ColorConstants.primary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('OK', style: AppTextStyles.googleSans(color: ColorConstants.primary)),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  String _formatCountShort(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }

  String _monthName(int month) {
    const names = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return names[month];
  }
}

