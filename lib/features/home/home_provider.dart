import 'package:flutter/material.dart';
import '../../shared/models/task_model.dart';
import '../../shared/models/note_model.dart';
import '../../core/services/database_service.dart';
import '../../core/utils/helpers.dart';

class HomeState {
  final List<TaskModel> todayTasks;
  final List<NoteModel> recentNotes;
  final String greeting;
  final String motivationalMessage;
  final String userName;
  final bool isLoading;
  final int completedToday;
  final int totalToday;
  final double progress;
  final int completed30Days;
  final double completionRate;
  final List<double> weeklyActivity;
  final List<double> dailyActivity;
  final double totalFocusHours;

  const HomeState({
    this.todayTasks = const [],
    this.recentNotes = const [],
    this.greeting = '',
    this.motivationalMessage = '',
    this.userName = '',
    this.isLoading = true,
    this.completedToday = 0,
    this.totalToday = 0,
    this.progress = 0.0,
    this.completed30Days = 0,
    this.completionRate = 0.0,
    this.weeklyActivity = const [],
    this.dailyActivity = const [],
    this.totalFocusHours = 0.0,
  });

  HomeState copyWith({
    List<TaskModel>? todayTasks,
    List<NoteModel>? recentNotes,
    String? greeting,
    String? motivationalMessage,
    String? userName,
    bool? isLoading,
    int? completedToday,
    int? totalToday,
    double? progress,
    int? completed30Days,
    double? completionRate,
    List<double>? weeklyActivity,
    List<double>? dailyActivity,
    double? totalFocusHours,
  }) => HomeState(
    todayTasks: todayTasks ?? this.todayTasks,
    recentNotes: recentNotes ?? this.recentNotes,
    greeting: greeting ?? this.greeting,
    motivationalMessage: motivationalMessage ?? this.motivationalMessage,
    userName: userName ?? this.userName,
    isLoading: isLoading ?? this.isLoading,
    completedToday: completedToday ?? this.completedToday,
    totalToday: totalToday ?? this.totalToday,
    progress: progress ?? this.progress,
    completed30Days: completed30Days ?? this.completed30Days,
    completionRate: completionRate ?? this.completionRate,
    weeklyActivity: weeklyActivity ?? this.weeklyActivity,
    dailyActivity: dailyActivity ?? this.dailyActivity,
    totalFocusHours: totalFocusHours ?? this.totalFocusHours,
  );
}

class HomeProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.getInstance();
  HomeState _state = const HomeState();

  HomeState get state => _state;

  Future<void> loadData(String userName) async {
    _state = _state.copyWith(isLoading: true, userName: userName);
    notifyListeners();

    final tasks = _db.getTasks();
    final notes = _db.getNotes();
    final now = DateTime.now();

    final todayTasks = tasks.where((t) {
      if (t.dueDate == null) return false;
      return t.dueDate!.year == now.year &&
          t.dueDate!.month == now.month &&
          t.dueDate!.day == now.day;
    }).toList();

    final completedToday = todayTasks.where((t) => t.isCompleted).length;
    final totalToday = todayTasks.length;
    final progress = totalToday > 0 ? completedToday / totalToday : 0.0;

    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final recent30Tasks = tasks.where((t) {
      if (t.createdAt.isAfter(thirtyDaysAgo)) return true;
      if (t.completedAt != null && t.completedAt!.isAfter(thirtyDaysAgo)) return true;
      return false;
    }).toList();
    final completed30Days = recent30Tasks.where((t) => t.isCompleted).length;
    final completionRate = recent30Tasks.isNotEmpty
        ? completed30Days / recent30Tasks.length
        : 0.0;

    final weeklyActivity = _calculateWeeklyActivity(tasks);
    final dailyActivity = _calculateDailyActivity(tasks, now);

    final sortedNotes = List<NoteModel>.from(notes)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    _state = _state.copyWith(
      todayTasks: todayTasks,
      recentNotes: sortedNotes.take(5).toList(),
      greeting: Helpers.getGreeting(),
      motivationalMessage: Helpers.getMotivationalMessage(),
      isLoading: false,
      completedToday: completedToday,
      totalToday: totalToday,
      progress: progress,
      completed30Days: completed30Days,
      completionRate: completionRate,
      weeklyActivity: weeklyActivity,
      dailyActivity: dailyActivity,
      totalFocusHours: completed30Days * 0.8,
    );
    notifyListeners();
  }

  List<double> _calculateWeeklyActivity(List<TaskModel> tasks) {
    final now = DateTime.now();
    final List<double> weekly = [];

    for (int i = 3; i >= 0; i--) {
      final weekStart = now.subtract(Duration(days: (i + 1) * 7));
      final weekEnd = now.subtract(Duration(days: i * 7));
      final weekTasks = tasks.where((t) {
        if (t.completedAt == null) return false;
        return t.completedAt!.isAfter(weekStart) && t.completedAt!.isBefore(weekEnd);
      }).toList();
      weekly.add(weekTasks.length.toDouble());
    }

    final todayDone = tasks.where((t) {
      if (t.completedAt == null) return false;
      return t.completedAt!.year == now.year &&
          t.completedAt!.month == now.month &&
          t.completedAt!.day == now.day;
    }).length;
    weekly.add(todayDone.toDouble());

    return weekly;
  }

  List<double> _calculateDailyActivity(List<TaskModel> tasks, DateTime now) {
    final List<double> daily = [];

    for (int i = 4; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day - i);
      final dayTasks = tasks.where((t) {
        if (t.completedAt == null) return false;
        return t.completedAt!.year == day.year &&
            t.completedAt!.month == day.month &&
            t.completedAt!.day == day.day;
      }).toList();
      daily.add(dayTasks.length.toDouble());
    }

    return daily;
  }

  Future<void> toggleTask(TaskModel task) async {
    final updated = task.copyWith(
      isCompleted: !task.isCompleted,
      completedAt: !task.isCompleted ? DateTime.now() : null,
      updatedAt: DateTime.now(),
      isSynced: false,
    );
    await _db.saveTask(updated);
    await loadData(_state.userName);
  }

  Future<void> deleteTask(String taskId) async {
    await _db.deleteTask(taskId);
    await loadData(_state.userName);
  }
}
