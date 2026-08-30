import 'package:flutter/material.dart';
import '../../shared/models/task_model.dart';
import '../../core/services/database_service.dart';

class CalendarState {
  final DateTime selectedDate;
  final DateTime focusedDate;
  final List<TaskModel> tasks;
  final bool isLoading;

  const CalendarState({
    required this.selectedDate,
    required this.focusedDate,
    this.tasks = const [],
    this.isLoading = true,
  });

  CalendarState copyWith({
    DateTime? selectedDate,
    DateTime? focusedDate,
    List<TaskModel>? tasks,
    bool? isLoading,
  }) => CalendarState(
    selectedDate: selectedDate ?? this.selectedDate,
    focusedDate: focusedDate ?? this.focusedDate,
    tasks: tasks ?? this.tasks,
    isLoading: isLoading ?? this.isLoading,
  );

  List<TaskModel> get tasksForSelectedDate {
    return tasks.where((t) {
      if (t.dueDate == null) return false;
      return t.dueDate!.year == selectedDate.year &&
          t.dueDate!.month == selectedDate.month &&
          t.dueDate!.day == selectedDate.day;
    }).toList();
  }

  Map<DateTime, List<TaskModel>> get tasksByDate {
    final map = <DateTime, List<TaskModel>>{};
    for (final task in tasks) {
      if (task.dueDate != null) {
        final date = DateTime(task.dueDate!.year, task.dueDate!.month, task.dueDate!.day);
        map.putIfAbsent(date, () => []).add(task);
      }
    }
    return map;
  }
}

class CalendarProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.getInstance();
  late CalendarState _state;

  CalendarProvider() {
    final now = DateTime.now();
    _state = CalendarState(
      selectedDate: now,
      focusedDate: now,
    );
  }

  CalendarState get state => _state;

  Future<void> initialize() async {
    await loadData();
  }

  Future<void> loadData() async {
    _state = _state.copyWith(isLoading: true);
    notifyListeners();

    final tasks = _db.getTasks();

    _state = _state.copyWith(
      tasks: tasks,
      isLoading: false,
    );
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
