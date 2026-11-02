import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

import '../../core/constants/color_constants.dart';
import '../../core/platform/platform_capabilities.dart';
import '../../core/theme/app_text_styles.dart';

class NotificationItem {
  final String id;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? data;
  const NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.isRead = false,
    required this.createdAt,
    this.data,
  });
  factory NotificationItem.fromJson(Map<String, dynamic> json) =>
      NotificationItem(
        id: json['id'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        type: json['type'] as String,
        isRead: json['isRead'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
        data: json['data'] as Map<String, dynamic>?,
      );
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'type': type,
    'isRead': isRead,
    'createdAt': createdAt.toIso8601String(),
    'data': data,
  };
  NotificationItem copyWith({bool? isRead}) => NotificationItem(
    id: id,
    title: title,
    body: body,
    type: type,
    isRead: isRead ?? this.isRead,
    createdAt: createdAt,
    data: data,
  );
}

class NotificationService {
  static NotificationService? _instance;
  static SharedPreferences? _prefs;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  List<NotificationItem> _notifications = [];
  static bool _initialized = false;
  static const String _notificationIdsKey = 'notification_ids';
  static const int _reservedAndroidServiceId = 1001;
  static const int _maxNotificationId = 2147483647;
  final Map<String, int> _notificationIds = {};
  bool _idsLoaded = false;
  NotificationService._();
  static NotificationService getInstance() {
    _instance ??= NotificationService._();
    return _instance!;
  }

  FlutterLocalNotificationsPlugin get localNotifications => _localNotifications;

  Future<void> _ensureIdsLoaded() async {
    if (_idsLoaded) return;
    _idsLoaded = true;
    try {
      _prefs ??= await SharedPreferences.getInstance();
    } catch (_) {
      return;
    }
    try {
      final jsonString = _prefs!.getString(_notificationIdsKey);
      if (jsonString == null || jsonString.isEmpty) return;
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map) return;
      decoded.forEach((key, value) {
        if (value is int && value > 0 && value <= _maxNotificationId) {
          _notificationIds['$key'] = value;
        }
      });
    } catch (_) {}
  }

  Future<int> _allocateNotificationId(String key) async {
    await _ensureIdsLoaded();
    final existing = _notificationIds[key];
    if (existing != null) return existing;
    final used = {..._notificationIds.values, _reservedAndroidServiceId};
    var candidate = key.hashCode.abs() % _maxNotificationId;
    if (candidate == 0) candidate = 1;
    while (used.contains(candidate)) {
      candidate = candidate < _maxNotificationId ? candidate + 1 : 1;
    }
    _notificationIds[key] = candidate;
    try {
      await _prefs?.setString(
        _notificationIdsKey,
        jsonEncode(_notificationIds),
      );
    } catch (_) {}
    return candidate;
  }

  Future<void> _releaseNotificationId(String key) async {
    await _ensureIdsLoaded();
    if (_notificationIds.remove(key) == null) return;
    try {
      await _prefs?.setString(
        _notificationIdsKey,
        jsonEncode(_notificationIds),
      );
    } catch (_) {}
  }

  Future<void> _cancelScheduled(int id) async {
    if (!PlatformCapabilities.hasLocalNotifications) return;
    try {
      await _localNotifications.cancel(id);
    } catch (_) {}
  }
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    restoreStoredNotifications();
    if (!PlatformCapabilities.hasLocalNotifications) return;
    if (!_initialized) {
      try {
        tz_data.initializeTimeZones();
        try {
          final tzInfo = await FlutterTimezone.getLocalTimezone();
          tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
        } catch (_) {
          try {
            tz.setLocalLocation(tz.getLocation('UTC'));
          } catch (_) {}
        }
        const androidSettings = AndroidInitializationSettings(
          '@mipmap/ic_launcher',
        );
        const iosSettings = DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );
        const settings = InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
        );
        await _localNotifications.initialize(settings);
        await _createNotificationChannel();
        _initialized = true;
      } catch (e) {
        debugPrint('Notification plugin unavailable: $e');
      }
    }
  }

  Future<void> _createNotificationChannel() async {
    const channel = AndroidNotificationChannel(
      'task_reminders',
      'Task Reminders',
      description: 'Notifications for task due times',
      importance: Importance.high,
      enableVibration: true,
      enableLights: true,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  List<NotificationItem> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  void restoreStoredNotifications() {
    _notifications = [];
    try {
      final jsonString = _prefs?.getString('notifications');
      if (jsonString == null || jsonString.isEmpty) return;
      final decoded = jsonDecode(jsonString);
      if (decoded is! List) return;
      final restored = <NotificationItem>[];
      for (final entry in decoded) {
        if (entry is! Map) continue;
        try {
          restored.add(
            NotificationItem.fromJson(Map<String, dynamic>.from(entry)),
          );
        } catch (_) {}
      }
      _notifications = restored;
    } catch (_) {
      _notifications = [];
    }
  }

  Future<void> _saveNotifications() async {
    final jsonList = _notifications.map((n) => n.toJson()).toList();
    await _prefs!.setString('notifications', jsonEncode(jsonList));
  }

  Future<void> addNotification({
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    final notification = NotificationItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: body,
      type: type,
      createdAt: DateTime.now(),
      data: data,
    );
    _notifications.insert(0, notification);
    await _saveNotifications();
  }

  Future<void> markAsRead(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index >= 0) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      await _saveNotifications();
    }
  }

  Future<void> markAllAsRead() async {
    _notifications = _notifications
        .map((n) => n.copyWith(isRead: true))
        .toList();
    await _saveNotifications();
  }

  Future<void> clearAll() async {
    _notifications.clear();
    await _saveNotifications();
  }

  Future<void> _zonedScheduleWithFallback(
    int id,
    String title,
    String body,
    tz.TZDateTime when,
    NotificationDetails details,
  ) async {
    if (!PlatformCapabilities.hasLocalNotifications) return;
    try {
      await _localNotifications.zonedSchedule(
        id,
        title,
        body,
        when,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      try {
        await _localNotifications.zonedSchedule(
          id,
          title,
          body,
          when,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (_) {}
    }
  }

  Future<void> scheduleTaskNotification(
    String taskId,
    String taskTitle,
    DateTime dueTime,
  ) async {
    if (PlatformCapabilities.hasLocalNotifications && !dueTime.isBefore(DateTime.now())) {
      final notificationId = await _allocateNotificationId('due:$taskId');
      await _zonedScheduleWithFallback(
        notificationId,
        'Task Due Now',
        taskTitle,
        tz.TZDateTime.from(dueTime, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'task_reminders',
            'Task Reminders',
            channelDescription: 'Notifications for task due times',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            enableVibration: true,
            enableLights: true,
            styleInformation: BigTextStyleInformation(taskTitle),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    }
  }

  Future<void> cancelTaskNotification(String taskId) async {
    await _ensureIdsLoaded();
    final id = _notificationIds['due:$taskId'];
    await _cancelScheduled(taskId.hashCode.abs() % _maxNotificationId);
    if (id != null) await _cancelScheduled(id);
    await _releaseNotificationId('due:$taskId');
  }

  Future<void> scheduleTaskReminder(
    String taskId,
    String taskTitle,
    DateTime reminderTime,
  ) async {
    if (PlatformCapabilities.hasLocalNotifications && !reminderTime.isBefore(DateTime.now())) {
      final notificationId = await _allocateNotificationId('reminder:$taskId');
      await _zonedScheduleWithFallback(
        notificationId,
        'Task Reminder',
        taskTitle,
        tz.TZDateTime.from(reminderTime, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'task_reminders',
            'Task Reminders',
            channelDescription: 'Notifications for task due times',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            enableVibration: true,
            enableLights: true,
            styleInformation: BigTextStyleInformation(taskTitle),
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    }
  }

  Future<void> cancelTaskReminder(String taskId) async {
    await _ensureIdsLoaded();
    final id = _notificationIds['reminder:$taskId'];
    await _cancelScheduled(
      (taskId.hashCode.abs() % _maxNotificationId) + 1,
    );
    if (id != null) await _cancelScheduled(id);
    await _releaseNotificationId('reminder:$taskId');
  }

  Future<void> scheduleFocusComplete(
    int durationMinutes,
    int sessionNumber,
  ) async {
    await addNotification(
      title: 'Focus Session Complete!',
      body:
          'Great job! You focused for $durationMinutes minutes. Session #$sessionNumber done.',
      type: 'focus_complete',
      data: {
        'durationMinutes': durationMinutes,
        'sessionNumber': sessionNumber,
      },
    );
  }

  static Future<void> requestPermissionOnce(BuildContext context) async {
    if (!PlatformCapabilities.hasLocalNotifications) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('notification_prompt_shown') ?? false) return;
    bool alreadyGranted = false;
    try {
      final status = await Permission.notification.status;
      alreadyGranted = status.isGranted || status.isProvisional;
    } catch (_) {
      return;
    }
    if (alreadyGranted) {
      await prefs.setBool('notification_prompt_shown', true);
      return;
    }
    if (!context.mounted) return;
    final enable = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(dialogContext).cardTheme.color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ColorConstants.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.notifications_active_rounded,
                color: ColorConstants.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Stay on Track',
              style: AppTextStyles.googleSans(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Text(
          'Nudgr needs notification access to send you task reminders, focus session alerts, and habit tracking nudges so you never miss what matters.',
          style: AppTextStyles.googleSans(
            fontSize: 14,
            color: Theme.of(dialogContext).textTheme.bodySmall?.color,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Later',
              style: AppTextStyles.googleSans(
                color: Theme.of(dialogContext).textTheme.bodySmall?.color,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorConstants.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Enable',
              style: AppTextStyles.googleSans(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    if (enable == true) {
      try {
        await Permission.notification.request();
        await Permission.scheduleExactAlarm.request();
      } catch (_) {}
    }
    await prefs.setBool('notification_prompt_shown', true);
  }
}
