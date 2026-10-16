import 'package:flutter/material.dart';

import '../../shared/models/task_model.dart';
import '../../core/services/database_service.dart';

class CalendarState {
  final DateTime selectedDate;
  final DateTime focusedDate;
  final List<TaskModel> tasks;
  final bool isLoading;
  final Map<DateTime, List<TaskModel>> tasksByDate;
  CalendarState({
    required this.selectedDate,
    required this.focusedDate,
    this.tasks = const [],
    this.isLoading = true,
    Map<DateTime, List<TaskModel>>? tasksByDate,
  }) : tasksByDate = tasksByDate ?? _groupByDate(tasks);
  static Map<DateTime, List<TaskModel>> _groupByDate(List<TaskModel> tasks) {
    final map = <DateTime, List<TaskModel>>{};
    for (final task in tasks) {
      final due = task.dueDate;
      if (due == null) continue;
      final date = DateTime(due.year, due.month, due.day);
      map.putIfAbsent(date, () => []).add(task);
    }
    return map;
  }

  CalendarState copyWith({
    DateTime? selectedDate,
    DateTime? focusedDate,
    List<TaskModel>? tasks,
    bool? isLoading,
    Map<DateTime, List<TaskModel>>? tasksByDate,
  }) => CalendarState(
    selectedDate: selectedDate ?? this.selectedDate,
    focusedDate: focusedDate ?? this.focusedDate,
    tasks: tasks ?? this.tasks,
    isLoading: isLoading ?? this.isLoading,
    tasksByDate:
        tasksByDate ?? (tasks == null ? this.tasksByDate : _groupByDate(tasks)),
  );
  List<TaskModel> get tasksForSelectedDate {
    return tasksByDate[DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
        )] ??
        const [];
  }
}

class CalendarProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.getInstance();
  late CalendarState _state;
  CalendarProvider() {
    final now = DateTime.now();
    _state = CalendarState(selectedDate: now, focusedDate: now);
  }
  CalendarState get state => _state;
  bool _loadedOnce = false;
  Future<void> initialize() async {
    if (_loadedOnce) return;
    await loadData();
  }

  Future<void> loadData() async {
    _loadedOnce = true;
    _state = _state.copyWith(isLoading: true);
    notifyListeners();
    final tasks = _db.getTasks();
    _state = _state.copyWith(tasks: tasks, isLoading: false);
    notifyListeners();
  }

  void selectDate(DateTime date) {
    _state = _state.copyWith(selectedDate: date);
    notifyListeners();
  }

  void focusOnDate(DateTime date) {
    _state = _state.copyWith(focusedDate: date);
    notifyListeners();
  }
}
