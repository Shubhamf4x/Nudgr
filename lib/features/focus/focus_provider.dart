import 'dart:async';
import 'package:flutter/material.dart';
import '../../shared/models/focus_session_model.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/database_service.dart';
import '../../core/services/sync_service.dart';

enum FocusStatus { idle, running, paused, breakTime }

class FocusState {
  final FocusStatus status;
  final int totalSeconds;
  final int remainingSeconds;
  final int currentSession;
  final int totalSessions;
  final int focusDuration;
  final int shortBreak;
  final int longBreak;
  final String? taskId;
  final String? taskTitle;
  final List<FocusSessionModel> sessions;
  final bool isLoading;

  const FocusState({
    this.status = FocusStatus.idle,
    this.totalSeconds = 0,
    this.remainingSeconds = 0,
    this.currentSession = 1,
    this.totalSessions = AppConstants.defaultSessionsBeforeLongBreak,
    this.focusDuration = AppConstants.defaultFocusDuration,
    this.shortBreak = AppConstants.defaultShortBreak,
    this.longBreak = AppConstants.defaultLongBreak,
    this.taskId,
    this.taskTitle,
    this.sessions = const [],
    this.isLoading = false,
  });

  FocusState copyWith({
    FocusStatus? status,
    int? totalSeconds,
    int? remainingSeconds,
    int? currentSession,
    int? totalSessions,
    int? focusDuration,
    int? shortBreak,
    int? longBreak,
    String? taskId,
    String? taskTitle,
    List<FocusSessionModel>? sessions,
    bool? isLoading,
  }) => FocusState(
    status: status ?? this.status,
    totalSeconds: totalSeconds ?? this.totalSeconds,
    remainingSeconds: remainingSeconds ?? this.remainingSeconds,
    currentSession: currentSession ?? this.currentSession,
    totalSessions: totalSessions ?? this.totalSessions,
    focusDuration: focusDuration ?? this.focusDuration,
    shortBreak: shortBreak ?? this.shortBreak,
    longBreak: longBreak ?? this.longBreak,
    taskId: taskId ?? this.taskId,
    taskTitle: taskTitle ?? this.taskTitle,
    sessions: sessions ?? this.sessions,
    isLoading: isLoading ?? this.isLoading,
  );

  double get progress =>
      totalSeconds > 0 ? 1.0 - (remainingSeconds / totalSeconds) : 0.0;

  int get totalFocusMinutes =>
      sessions.where((s) => s.sessionType == 'focus' && s.isCompleted).fold(
          0, (sum, s) => sum + s.actualDurationMinutes);

  int get completedSessions =>
      sessions.where((s) => s.sessionType == 'focus' && s.isCompleted).length;

  int get todayFocusMinutes {
    final today = DateTime.now();
    return sessions
        .where((s) =>
            s.sessionType == 'focus' &&
            s.isCompleted &&
            s.startTime.year == today.year &&
            s.startTime.month == today.month &&
            s.startTime.day == today.day)
        .fold(0, (sum, s) => sum + s.actualDurationMinutes);
  }

  int get currentStreak {
    if (sessions.isEmpty) return 0;
    int streak = 0;
    final today = DateTime.now();
    var checkDate = DateTime(today.year, today.month, today.day);

    for (int i = 0; i < 365; i++) {
      final hasSession = sessions.any((s) =>
          s.isCompleted &&
          s.startTime.year == checkDate.year &&
          s.startTime.month == checkDate.month &&
          s.startTime.day == checkDate.day);
      if (hasSession) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else if (i == 0) {
        checkDate = checkDate.subtract(const Duration(days: 1));
        continue;
      } else {
        break;
      }
    }
    return streak;
  }
}

class FocusProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.getInstance();
  final SyncService _sync = SyncService.getInstance();
  Timer? _timer;
  FocusState _state = const FocusState();

  FocusState get state => _state;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> loadData() async {
    _state = _state.copyWith(isLoading: true);
    notifyListeners();

    final sessions = _db.getFocusSessions();

    _state = _state.copyWith(
      sessions: sessions,
      isLoading: false,
    );
    notifyListeners();
  }

  void start() {
    final totalSeconds = _state.focusDuration * 60;
    _state = _state.copyWith(
      status: FocusStatus.running,
      totalSeconds: totalSeconds,
      remainingSeconds: totalSeconds,
    );
    notifyListeners();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_state.remainingSeconds > 0) {
        _state = _state.copyWith(
          remainingSeconds: _state.remainingSeconds - 1,
        );
        notifyListeners();
      } else {
        _timer?.cancel();
        _onSessionComplete();
      }
    });
  }

  void pause() {
    _timer?.cancel();
    _state = _state.copyWith(status: FocusStatus.paused);
    notifyListeners();
  }

  void resume() {
    _state = _state.copyWith(status: FocusStatus.running);
    notifyListeners();
    _startTimer();
  }

  void stop() {
    _timer?.cancel();
    final actualMinutes = (_state.totalSeconds - _state.remainingSeconds) ~/ 60;
    if (actualMinutes > 0) {
      _saveSession(actualMinutes: actualMinutes, completed: false);
    }
    _state = _state.copyWith(
      status: FocusStatus.idle,
      remainingSeconds: 0,
      totalSeconds: 0,
    );
    notifyListeners();
  }

  void skip() {
    _timer?.cancel();
    _onSessionComplete();
  }

  void _onSessionComplete() {
    _saveSession(actualMinutes: _state.focusDuration, completed: true);

    final nextSession = _state.currentSession + 1;
    final isLongBreak = _state.currentSession % _state.totalSessions == 0;
    final breakDuration =
        isLongBreak ? _state.longBreak : _state.shortBreak;
    final breakSeconds = breakDuration * 60;

    _state = _state.copyWith(
      status: FocusStatus.breakTime,
      totalSeconds: breakSeconds,
      remainingSeconds: breakSeconds,
      currentSession: isLongBreak ? 1 : nextSession,
    );
    notifyListeners();
  }

  void _saveSession({required int actualMinutes, required bool completed}) {
    final session = FocusSessionModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      taskId: _state.taskId,
      taskTitle: _state.taskTitle,
      userId: '',
      durationMinutes: _state.focusDuration,
      actualDurationMinutes: actualMinutes,
      sessionType: 'focus',
      sessionNumber: _state.currentSession,
      isCompleted: completed,
      startTime: DateTime.now().subtract(Duration(seconds: _state.totalSeconds - _state.remainingSeconds)),
      endTime: DateTime.now(),
      createdAt: DateTime.now(),
      isSynced: false,
    );
    _db.saveFocusSession(session);
    _sync.saveFocusSessionToFirestore(session);
    _state = _state.copyWith(
      sessions: [..._state.sessions, session],
    );
  }

  void setTask(String? taskId, String? taskTitle) {
    _state = _state.copyWith(taskId: taskId, taskTitle: taskTitle);
    notifyListeners();
  }

  void setDurations({
    int? focusDuration,
    int? shortBreak,
    int? longBreak,
  }) {
    _state = _state.copyWith(
      focusDuration: focusDuration,
      shortBreak: shortBreak,
      longBreak: longBreak,
    );
    notifyListeners();
  }
}
