import '../../core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/color_constants.dart';
import '../../core/utils/helpers.dart';
import '../../shared/models/focus_session_model.dart';
import 'focus_provider.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  bool _isBreakMode = false;
  int? _savedFocusDuration;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FocusProvider>().loadData();
    });
  }

  void _onPlay(FocusProvider provider) {
    if (_isBreakMode && provider.state.status == FocusStatus.idle) {
      _savedFocusDuration = provider.state.focusDuration;
      provider.setDurations(focusDuration: provider.state.shortBreak);
    }
    provider.start();
  }

  void _onReset(FocusProvider provider) {
    provider.stop();
    if (_savedFocusDuration != null) {
      provider.setDurations(focusDuration: _savedFocusDuration!);
      _savedFocusDuration = null;
    }
  }

  void _onSkip(FocusProvider provider) {
    provider.skip();
  }

  void _showDurationPicker(FocusProvider provider) {
    final currentDuration =
        _isBreakMode ? provider.state.shortBreak : provider.state.focusDuration;
    double sliderValue = currentDuration.toDouble();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final totalMin = sliderValue.round();
            final h = totalMin ~/ 60;
            final m = totalMin % 60;
            final displayText = h > 0
                ? '$h hr${h > 1 ? 's' : ''}${m > 0 ? ' $m min' : ''}'
                : '$m min';

            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isBreakMode ? 'Break Duration' : 'Focus Duration',
                    style: AppTextStyles.googleSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    displayText,
                    style: AppTextStyles.googleSans(
                      fontSize: 48,
                      fontWeight: FontWeight.w700,
                      color: ColorConstants.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: ColorConstants.primary,
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                      thumbColor: ColorConstants.primary,
                      overlayColor:
                          ColorConstants.primary.withValues(alpha: 0.15),
                    ),
                    child: Slider(
                      value: sliderValue,
                      min: 1,
                      max: 360,
                      divisions: 359,
                      onChanged: (v) => setModalState(() => sliderValue = v),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('1 min',
                            style: AppTextStyles.googleSans(
                                fontSize: 12, color: Colors.white38)),
                        Text('6 hrs',
                            style: AppTextStyles.googleSans(
                                fontSize: 12, color: Colors.white38)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        final value = sliderValue.round();
                        if (_isBreakMode) {
                          provider.setDurations(shortBreak: value);
                        } else {
                          provider.setDurations(focusDuration: value);
                        }
                        Navigator.pop(context);
                      },
                      child: const Text('Set Duration'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Focus',
                    style: AppTextStyles.googleSans(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.bar_chart_rounded, size: 24),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _buildMainCard(),
                    const SizedBox(height: 24),
                    _buildRecentSessions(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerTheme.color ?? Colors.grey.shade200),
      ),
      child: SizedBox(
        height: 400,
        child: Selector<FocusProvider, ({FocusStatus status, int remainingSeconds})>(
          selector: (_, p) => (status: p.state.status, remainingSeconds: p.state.remainingSeconds),
          builder: (context, data, _) {
            final provider = context.read<FocusProvider>();
            final status = data.status;
            final isIdle = status == FocusStatus.idle;
            final isRunning = status == FocusStatus.running;
            final isPaused = status == FocusStatus.paused;
            final isBreakTime = status == FocusStatus.breakTime;
            final timerActive = isRunning || isPaused || isBreakTime;

            return Column(
              children: [
                _buildToggleTabs(timerActive),
                const SizedBox(height: 16),
                if (isIdle) ...[
                  _buildDurationChip(),
                  const Spacer(flex: 2),
                ] else
                  const Spacer(flex: 1),
                _buildTimerText(status: data.status, remainingSeconds: data.remainingSeconds),
                const SizedBox(height: 8),
                Text(
                  _getStatusText(status),
                  style: AppTextStyles.googleSans(
                    fontSize: 15,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
                const Spacer(flex: 3),
                _buildControls(provider, isIdle, isRunning, isPaused, isBreakTime),
                const SizedBox(height: 20),
                _buildStatsLine(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildToggleTabs(bool disabled) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Expanded(child: _buildTab('Focus', !_isBreakMode, disabled)),
          Expanded(child: _buildTab('Break', _isBreakMode, disabled)),
        ],
      ),
    );
  }

  Widget _buildTab(String label, bool isSelected, bool disabled) {
    return GestureDetector(
      onTap: disabled
          ? null
          : () => setState(() => _isBreakMode = label == 'Break'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? ColorConstants.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTextStyles.googleSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
      ),
    );
  }

  Widget _buildDurationChip() {
    final provider = context.read<FocusProvider>();
    final duration =
        _isBreakMode ? provider.state.shortBreak : provider.state.focusDuration;
    return GestureDetector(
      onTap: () => _showDurationPicker(provider),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.access_time_rounded, size: 16, color: Theme.of(context).textTheme.bodySmall?.color),
            const SizedBox(width: 8),
            Text(
              '$duration min',
              style: AppTextStyles.googleSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.edit_outlined, size: 14, color: Theme.of(context).textTheme.bodySmall?.color),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerText({required FocusStatus status, required int remainingSeconds}) {
    String timerText;
    if (status == FocusStatus.idle) {
      final provider = context.read<FocusProvider>();
      final duration =
          _isBreakMode ? provider.state.shortBreak : provider.state.focusDuration;
      final totalSec = duration * 60;
      timerText =
          '${(totalSec ~/ 60).toString().padLeft(2, '0')}:${(totalSec % 60).toString().padLeft(2, '0')}';
    } else {
      timerText =
          '${(remainingSeconds ~/ 60).toString().padLeft(2, '0')}:${(remainingSeconds % 60).toString().padLeft(2, '0')}';
    }

    return Text(
      timerText,
      style: AppTextStyles.googleSans(
        fontSize: 72,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
        height: 1,
      ),
    );
  }

  String _getStatusText(FocusStatus status) {
    switch (status) {
      case FocusStatus.idle:
        return 'Ready when you are';
      case FocusStatus.running:
        return _isBreakMode ? 'Take a break' : 'Stay focused!';
      case FocusStatus.paused:
        return 'Timer paused';
      case FocusStatus.breakTime:
        return 'Take a break';
    }
  }

  Widget _buildControls(
    FocusProvider provider,
    bool isIdle,
    bool isRunning,
    bool isPaused,
    bool isBreakTime,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildIconButton(
          icon: Icons.refresh_rounded,
          onTap: isIdle ? null : () => _onReset(provider),
        ),
        GestureDetector(
          onTap: () {
            if (isIdle || isBreakTime) {
              _onPlay(provider);
            } else if (isRunning) {
              provider.pause();
            } else if (isPaused) {
              provider.resume();
            }
          },
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: ColorConstants.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: ColorConstants.primary.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
        ),
        _buildIconButton(
          icon: Icons.skip_next_rounded,
          onTap: isIdle ? null : () => _onSkip(provider),
        ),
      ],
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(
        icon,
        size: 28,
        color: onTap != null
            ? Theme.of(context).textTheme.bodyLarge?.color
            : Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.3),
      ),
    );
  }

  Widget _buildStatsLine() {
    final provider = context.read<FocusProvider>();
    final totalMinutes = provider.state.todayFocusMinutes;
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    final focusedTime =
        '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

    return Text(
      '${provider.state.completedSessions} focus sessions today \u00b7 $focusedTime focused',
      style: AppTextStyles.googleSans(fontSize: 13, color: Theme.of(context).textTheme.bodySmall?.color),
    );
  }

  Widget _buildRecentSessions() {
    return Selector<FocusProvider, List<FocusSessionModel>>(
      selector: (_, p) => p.state.sessions,
      builder: (context, sessions, _) {
        final focusSessions = sessions
            .where((s) => s.sessionType == 'focus')
            .toList()
          ..sort((a, b) => b.startTime.compareTo(a.startTime));
        final recent = focusSessions.take(10).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent sessions',
              style: AppTextStyles.googleSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (recent.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'Complete your first focus session to see history.',
                    style: AppTextStyles.googleSans(fontSize: 14, color: Theme.of(context).textTheme.bodySmall?.color),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ...recent.map(_buildSessionTile),
          ],
        );
      },
    );
  }

  Widget _buildSessionTile(FocusSessionModel session) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerTheme.color ?? Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: session.isCompleted
                    ? ColorConstants.success.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                session.isCompleted
                    ? Icons.check_rounded
                    : Icons.close_rounded,
                color: session.isCompleted
                    ? ColorConstants.success
                    : Colors.white38,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${session.actualDurationMinutes} min focus',
                    style: AppTextStyles.googleSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    Helpers.formatRelativeTime(session.startTime),
                    style: AppTextStyles.googleSans(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ),
            if (session.taskTitle != null)
              Text(
                session.taskTitle!,
                style: AppTextStyles.googleSans(
                  fontSize: 12,
                  color: ColorConstants.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
