import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/models/step_model.dart';

class StepsService {
  static StepsService? _instance;
  static SharedPreferences? _prefs;
  static const _channel = MethodChannel('com.nudgr.nudgr/step_counter');
  static void Function(int sensorValue)? _onStepUpdate;
  static void Function(bool granted)? _onPermissionResult;

  StepDayModel? _todayCache;
  String _cacheDate = '';

  StepsService._();

  static StepsService getInstance() {
    _instance ??= StepsService._();
    return _instance!;
  }

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<bool> isSensorAvailable() async {
    try {
      final result = await _channel.invokeMethod<bool>('isSensorAvailable');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestActivityPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestActivityPermission');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isActivityPermissionGranted() async {
    try {
      final result = await _channel.invokeMethod<bool>('isActivityPermissionGranted');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  void startListening(void Function(int sensorValue) onStepUpdate) {
    _onStepUpdate = onStepUpdate;
    _installHandler();
    _channel.invokeMethod('startListening').catchError((_) {});
  }

  void stopListening() {
    _channel.invokeMethod('stopListening').catchError((_) {});
  }

  void setPermissionResultHandler(void Function(bool granted)? handler) {
    _onPermissionResult = handler;
    _installHandler();
  }

  static void _installHandler() {
    _channel.setMethodCallHandler((call) async {
      try {
        switch (call.method) {
          case 'onStepUpdate':
            final value = call.arguments as int;
            _onStepUpdate?.call(value);
            break;
          case 'onPermissionResult':
            final granted = call.arguments as bool? ?? false;
            _onPermissionResult?.call(granted);
            break;
        }
      } catch (_) {}
    });
  }

  Future<void> sendNotification(String title, String body) async {
    try {
      await _channel.invokeMethod('sendNotification', {
        'title': title,
        'body': body,
      });
    } catch (_) {}
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  List<StepDayModel> getStepHistory() {
    final jsonString = _prefs?.getString('step_history');
    if (jsonString == null || jsonString.isEmpty) return [];
    try {
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList.map((e) => StepDayModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveStepHistory(List<StepDayModel> history) async {
    final jsonList = history.map((e) => e.toJson()).toList();
    await _prefs!.setString('step_history', jsonEncode(jsonList));
  }

  StepDayModel? getTodayRecord() {
    final todayKey = _todayKey();
    if (_cacheDate == todayKey) return _todayCache;
    final history = getStepHistory();
    try {
      _todayCache = history.firstWhere((r) => r.date == todayKey);
    } catch (_) {
      _todayCache = null;
    }
    _cacheDate = todayKey;
    return _todayCache;
  }

  Future<void> updateTodaySteps({
    required int stepCount,
    required int sensorBaseline,
    required int lastSensorValue,
  }) async {
    final todayKey = _todayKey();
    final record = StepDayModel(
      date: todayKey,
      stepCount: stepCount,
      sensorBaseline: sensorBaseline,
      lastSensorValue: lastSensorValue,
      lastUpdated: DateTime.now(),
    );

    final history = getStepHistory();
    final index = history.indexWhere((r) => r.date == todayKey);
    if (index >= 0) {
      history[index] = record;
    } else {
      history.add(record);
    }
    await _saveStepHistory(history);

    _todayCache = record;
    _cacheDate = todayKey;
  }

  Future<void> mergeCloudStepDay(String date, int stepCount) async {
    final history = getStepHistory();
    final index = history.indexWhere((r) => r.date == date);

    if (index >= 0) {
      final local = history[index];
      if (local.stepCount >= stepCount) return;
      history[index] = StepDayModel(
        date: date,
        stepCount: stepCount,
        sensorBaseline: local.sensorBaseline,
        lastSensorValue: local.lastSensorValue,
        lastUpdated: DateTime.now(),
      );
    } else {
      history.add(StepDayModel(
        date: date,
        stepCount: stepCount,
        lastUpdated: DateTime.now(),
      ));
    }

    await _saveStepHistory(history);
    if (date == _todayKey()) {
      _todayCache = null;
      _cacheDate = '';
    }
  }

  Future<void> clearStepHistory() async {
    await _prefs?.remove('step_history');
    await _prefs?.remove('step_goal_notification_date');
    _todayCache = null;
    _cacheDate = '';
  }

  int getDailyGoal() {
    return _prefs?.getInt('step_daily_goal') ?? 10000;
  }

  Future<void> setDailyGoal(int goal) async {
    await _prefs!.setInt('step_daily_goal', goal);
  }

  bool areNotificationsEnabled() {
    return _prefs?.getBool('step_notifications_enabled') ?? true;
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    await _prefs!.setBool('step_notifications_enabled', enabled);
  }

  bool hasGoalNotificationBeenSentToday() {
    final lastSent = _prefs?.getString('step_goal_notification_date');
    return lastSent == _todayKey();
  }

  Future<void> markGoalNotificationSent() async {
    await _prefs!.setString('step_goal_notification_date', _todayKey());
  }
}
