import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../shared/models/step_model.dart';
import '../../core/services/steps_service.dart';
import '../../core/services/sync_service.dart';

class StepsState {
  final int todaySteps;
  final int dailyGoal;
  final double progress;
  final List<StepDayModel> history;
  final bool isTracking;
  final bool hasPermission;
  final bool hasSensor;
  final bool isLoading;
  final bool goalNotificationShown;
  const StepsState({
    this.todaySteps = 0,
    this.dailyGoal = 10000,
    this.progress = 0.0,
    this.history = const [],
    this.isTracking = false,
    this.hasPermission = false,
    this.hasSensor = false,
    this.isLoading = true,
    this.goalNotificationShown = false,
  });
  StepsState copyWith({
    int? todaySteps,
    int? dailyGoal,
    double? progress,
    List<StepDayModel>? history,
    bool? isTracking,
    bool? hasPermission,
    bool? hasSensor,
    bool? isLoading,
    bool? goalNotificationShown,
  }) => StepsState(
    todaySteps: todaySteps ?? this.todaySteps,
    dailyGoal: dailyGoal ?? this.dailyGoal,
    progress: progress ?? this.progress,
    history: history ?? this.history,
    isTracking: isTracking ?? this.isTracking,
    hasPermission: hasPermission ?? this.hasPermission,
    hasSensor: hasSensor ?? this.hasSensor,
    isLoading: isLoading ?? this.isLoading,
    goalNotificationShown: goalNotificationShown ?? this.goalNotificationShown,
  );
}

class StepsProvider extends ChangeNotifier {
  final StepsService _stepsService = StepsService.getInstance();
  final SyncService _sync = SyncService.getInstance();
  StepsState _state = const StepsState();
  DateTime _lastCloudSync = DateTime.fromMillisecondsSinceEpoch(0);
  int _lastSyncedSteps = -1;
  StepsState get state => _state;
  @override
  void dispose() {
    _stepsService.setPermissionResultHandler(null);
    _stepsService.stopListening();
    super.dispose();
  }

  bool _initialized = false;
  int _stepOffset = 0;
  Future<void> initialize() async {
    if (_initialized) {
      await _refreshFromStorage();
      return;
    }
    _initialized = true;
    _state = _state.copyWith(isLoading: true);
    notifyListeners();
    _stepsService.setPermissionResultHandler(_onPermissionResult);
    final hasSensor = await _stepsService.isSensorAvailable();
    final hasPermission = await _stepsService.isActivityPermissionGranted();
    final dailyGoal = _stepsService.getDailyGoal();
    final history = _stepsService.getStepHistory();
    final todayRecord = _stepsService.getTodayRecord();
    var todaySteps = todayRecord?.stepCount ?? 0;
    final goalShown = _stepsService.hasGoalNotificationBeenSentToday();
    final foregroundSteps = _stepsService.getForegroundSteps();
    if (foregroundSteps != null && foregroundSteps > todaySteps) {
      final fgBaseline = _stepsService.getForegroundBaseline();
      await _stepsService.updateTodaySteps(
        stepCount: foregroundSteps,
        sensorBaseline: fgBaseline,
        lastSensorValue: fgBaseline + foregroundSteps,
      );
      todaySteps = foregroundSteps;
      history.clear();
      history.addAll(_stepsService.getStepHistory());
    }
    _state = _state.copyWith(
      hasSensor: hasSensor,
      hasPermission: hasPermission,
      dailyGoal: dailyGoal,
      history: history,
      todaySteps: todaySteps,
      progress: dailyGoal > 0 ? (todaySteps / dailyGoal).clamp(0.0, 1.0) : 0.0,
      isLoading: false,
      goalNotificationShown: goalShown,
    );
    notifyListeners();
    if (hasSensor &&
        hasPermission &&
        !_stepsService.foregroundTrackingStopped) {
      _startListening();
    }
  }

  Future<void> _refreshFromStorage() async {
    final dailyGoal = _stepsService.getDailyGoal();
    final history = _stepsService.getStepHistory();
    final todayRecord = _stepsService.getTodayRecord();
    var todaySteps = todayRecord?.stepCount ?? 0;
    final foregroundSteps = _stepsService.getForegroundSteps();
    if (foregroundSteps != null && foregroundSteps > todaySteps) {
      final fgBaseline = _stepsService.getForegroundBaseline();
      await _stepsService.updateTodaySteps(
        stepCount: foregroundSteps,
        sensorBaseline: fgBaseline,
        lastSensorValue: fgBaseline + foregroundSteps,
      );
      todaySteps = foregroundSteps;
      history.clear();
      history.addAll(_stepsService.getStepHistory());
    }
    _state = _state.copyWith(
      dailyGoal: dailyGoal,
      history: history,
      todaySteps: todaySteps,
      progress: dailyGoal > 0 ? (todaySteps / dailyGoal).clamp(0.0, 1.0) : 0.0,
      isLoading: false,
    );
    notifyListeners();
  }

  void _onPermissionResult(bool granted) {
    if (!granted) return;
    _state = _state.copyWith(hasPermission: true);
    if (_state.hasSensor) {
      _startListening();
    } else {
      notifyListeners();
    }
  }

  Future<bool> requestPermission() async {
    final granted = await _stepsService.requestActivityPermission();
    if (granted) {
      _onPermissionResult(true);
    } else {
      final nowGranted = await _stepsService.isActivityPermissionGranted();
      if (nowGranted) _onPermissionResult(true);
    }
    try {
      await Permission.notification.request();
    } catch (_) {}
    notifyListeners();
    return _state.hasPermission;
  }

  void _startListening() {
    _stepsService.startListening(_onStepUpdate);
    _state = _state.copyWith(isTracking: true);
    notifyListeners();
    _syncForegroundService();
  }

  Future<void> _syncForegroundService() async {
    final today = _stepsService.getTodayRecord();
    final baseline =
        today?.sensorBaseline ?? _stepsService.getForegroundBaseline();
    await _stepsService.startForegroundTracking(
      baseline: baseline,
      steps: today?.stepCount ?? 0,
      goal: _state.dailyGoal,
    );
    await _stepsService.setForegroundTrackingStopped(false);
  }

  Future<void> pauseTracking() async {
    await _stepsService.stopForegroundTracking();
    await _stepsService.setForegroundTrackingStopped(true);
    _state = _state.copyWith(isTracking: false);
    notifyListeners();
  }

  Future<void> resumeTracking() async {
    if (!_state.hasSensor || !_state.hasPermission) return;
    await _syncForegroundService();
    _stepsService.startListening(_onStepUpdate);
    _state = _state.copyWith(isTracking: true);
    notifyListeners();
  }

  Future<void> updateDailyGoal(int goal) async {
    await _stepsService.setDailyGoal(goal);
    final progress = goal > 0
        ? (_state.todaySteps / goal).clamp(0.0, 1.0)
        : 0.0;
    _state = _state.copyWith(dailyGoal: goal, progress: progress);
    notifyListeners();
    if (_state.isTracking) {
      final today = _stepsService.getTodayRecord();
      await _stepsService.startForegroundTracking(
        baseline: today?.sensorBaseline ?? 0,
        steps: today?.stepCount ?? 0,
        goal: goal,
      );
    }
  }

  static ({int steps, int baseline, int offset}) resolveSensorReading({
    required int sensorValue,
    required int previousBaseline,
    required int previousSensorValue,
    required int previousStepCount,
    int baseOffset = 0,
  }) {
    if (previousBaseline <= 0) {
      return (steps: previousStepCount, baseline: sensorValue, offset: 0);
    }
    if (sensorValue < previousSensorValue) {
      return (
        steps: previousStepCount,
        baseline: sensorValue,
        offset: previousStepCount,
      );
    }
    final delta = (sensorValue - previousBaseline).clamp(0, 1000000);
    final steps = (baseOffset + delta).clamp(0, 1000000);
    return (
      steps: steps > 0 ? steps : previousStepCount,
      baseline: previousBaseline,
      offset: baseOffset,
    );
  }

  void _onStepUpdate(int sensorValue) {
    final todayRecord = _stepsService.getTodayRecord();
    if (todayRecord == null) {
      _stepOffset = 0;
      _stepsService.updateTodaySteps(
        stepCount: 0,
        sensorBaseline: sensorValue,
        lastSensorValue: sensorValue,
      );
      _state = _state.copyWith(todaySteps: 0, progress: 0.0);
      notifyListeners();
      return;
    }
    final resolved = resolveSensorReading(
      sensorValue: sensorValue,
      previousBaseline: todayRecord.sensorBaseline,
      previousSensorValue: todayRecord.lastSensorValue,
      previousStepCount: todayRecord.stepCount,
      baseOffset: _stepOffset,
    );
    _stepOffset = resolved.offset;
    final baseline = resolved.baseline;
    final todaySteps = resolved.steps;
    if (todaySteps == todayRecord.stepCount &&
        sensorValue == todayRecord.lastSensorValue) {
      return;
    }
    _stepsService.updateTodaySteps(
      stepCount: todaySteps,
      sensorBaseline: baseline,
      lastSensorValue: sensorValue,
    );
    final progress = _state.dailyGoal > 0
        ? (todaySteps / _state.dailyGoal).clamp(0.0, 1.0)
        : 0.0;
    _state = _state.copyWith(todaySteps: todaySteps, progress: progress);
    notifyListeners();
    _checkGoalNotification(todaySteps);
    _syncStepToFirestore(todaySteps);
  }

  void _checkGoalNotification(int todaySteps) {
    if (todaySteps >= _state.dailyGoal &&
        !_state.goalNotificationShown &&
        !_stepsService.hasGoalNotificationBeenSentToday()) {
      _state = _state.copyWith(goalNotificationShown: true);
      notifyListeners();
      _stepsService.markGoalNotificationSent();
      _stepsService.sendNotification(
        'Nudgr Steps',
        'Daily step goal reached! ${_state.dailyGoal} steps today.',
      );
    }
  }

  void _syncStepToFirestore(int todaySteps) {
    try {
      final todayKey = _stepsService.getTodayRecord()?.date ?? '';
      if (todayKey.isEmpty) return;
      final now = DateTime.now();
      if (todaySteps == _lastSyncedSteps) return;
      if (now.difference(_lastCloudSync) < const Duration(minutes: 1)) return;
      _lastCloudSync = now;
      _lastSyncedSteps = todaySteps;
      _sync.saveStepDayToFirestore(todayKey, todaySteps);
    } catch (_) {}
  }

  Future<void> toggleNotifications(bool enabled) async {
    await _stepsService.setNotificationsEnabled(enabled);
    _state = _state.copyWith();
    notifyListeners();
  }

  bool get notificationsEnabled => _stepsService.areNotificationsEnabled();
  StepDayModel? getRecordForDate(DateTime date) {
    final key =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    try {
      return _state.history.firstWhere((r) => r.date == key);
    } catch (_) {
      return null;
    }
  }
}
