import 'dart:async';
import 'package:flutter/material.dart';
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

  Future<void> initialize() async {
    _state = _state.copyWith(isLoading: true);
    notifyListeners();

    _stepsService.setPermissionResultHandler(_onPermissionResult);

    final hasSensor = await _stepsService.isSensorAvailable();
    final hasPermission = await _stepsService.isActivityPermissionGranted();
    final dailyGoal = _stepsService.getDailyGoal();
    final history = _stepsService.getStepHistory();
    final todayRecord = _stepsService.getTodayRecord();
    final todaySteps = todayRecord?.stepCount ?? 0;
    final goalShown = _stepsService.hasGoalNotificationBeenSentToday();

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

    if (hasSensor && hasPermission) {
      _startListening();
    }
  }

  /// Called when the native ACTIVITY_RECOGNITION dialog resolves.
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
    // On Android 10+ the system dialog is async: requestActivityPermission
    // returns false immediately and _onPermissionResult fires once the user
    // answers. Only finalize here when permission was already granted.
    if (granted) {
      _onPermissionResult(true);
    } else {
      // Re-check once in case the dialog resolved synchronously.
      final nowGranted = await _stepsService.isActivityPermissionGranted();
      if (nowGranted) _onPermissionResult(true);
    }
    notifyListeners();
    return _state.hasPermission;
  }

  void _startListening() {
    _stepsService.startListening(_onStepUpdate);
    _state = _state.copyWith(isTracking: true);
    notifyListeners();
  }

  void _onStepUpdate(int sensorValue) {
    final todayRecord = _stepsService.getTodayRecord();
    int baseline = todayRecord?.sensorBaseline ?? 0;
    int previousSensorValue = todayRecord?.lastSensorValue ?? 0;

    if (todayRecord == null) {
      baseline = sensorValue;
      _stepsService.updateTodaySteps(
        stepCount: 0,
        sensorBaseline: baseline,
        lastSensorValue: sensorValue,
      );
      _state = _state.copyWith(
        todaySteps: 0,
        progress: 0.0,
      );
      notifyListeners();
      return;
    }

    if (sensorValue < previousSensorValue) {
      baseline = sensorValue;
    }

    final steps = sensorValue - baseline;
    final todaySteps = steps > 0 ? steps : todayRecord.stepCount;

    // Skip work entirely when the count has not changed — the hardware
    // sensor fires very frequently with the same cumulative value.
    if (todaySteps == todayRecord.stepCount &&
        sensorValue == previousSensorValue) {
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

    _state = _state.copyWith(
      todaySteps: todaySteps,
      progress: progress,
    );
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
      // Throttle cloud writes: at most once per minute and only when the
      // step count actually changed since the last upload.
      final now = DateTime.now();
      if (todaySteps == _lastSyncedSteps) return;
      if (now.difference(_lastCloudSync) < const Duration(minutes: 1)) return;
      _lastCloudSync = now;
      _lastSyncedSteps = todaySteps;
      _sync.saveStepDayToFirestore(todayKey, todaySteps);
    } catch (_) {}
  }

  Future<void> updateDailyGoal(int goal) async {
    await _stepsService.setDailyGoal(goal);
    final progress = goal > 0 ? (_state.todaySteps / goal).clamp(0.0, 1.0) : 0.0;
    _state = _state.copyWith(dailyGoal: goal, progress: progress);
    notifyListeners();
  }

  Future<void> toggleNotifications(bool enabled) async {
    await _stepsService.setNotificationsEnabled(enabled);
    _state = _state.copyWith();
    notifyListeners();
  }

  bool get notificationsEnabled => _stepsService.areNotificationsEnabled();

  StepDayModel? getRecordForDate(DateTime date) {
    final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    try {
      return _state.history.firstWhere((r) => r.date == key);
    } catch (_) {
      return null;
    }
  }
}
