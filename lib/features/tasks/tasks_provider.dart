import 'package:flutter/material.dart';
import '../../shared/models/task_model.dart';
import '../../shared/models/category_model.dart';
import '../../core/services/database_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/sync_service.dart';

class TasksState {
  final List<TaskModel> tasks;
  final List<CategoryModel> categories;
  final String? selectedCategoryId;
  final String? selectedPriority;
  final bool showCompleted;
  final String searchQuery;
  final bool isLoading;

  const TasksState({
    this.tasks = const [],
    this.categories = const [],
    this.selectedCategoryId,
    this.selectedPriority,
    this.showCompleted = true,
    this.searchQuery = '',
    this.isLoading = true,
  });

  TasksState copyWith({
    List<TaskModel>? tasks,
    List<CategoryModel>? categories,
    String? selectedCategoryId,
    String? selectedPriority,
    bool? showCompleted,
    String? searchQuery,
    bool? isLoading,
  }) => TasksState(
    tasks: tasks ?? this.tasks,
    categories: categories ?? this.categories,
    selectedCategoryId: selectedCategoryId,
    selectedPriority: selectedPriority,
    showCompleted: showCompleted ?? this.showCompleted,
    searchQuery: searchQuery ?? this.searchQuery,
    isLoading: isLoading ?? this.isLoading,
  );

  List<TaskModel> get filteredTasks {
    var filtered = List<TaskModel>.from(tasks);
    if (selectedCategoryId != null) {
      filtered = filtered.where((t) => t.categoryId == selectedCategoryId).toList();
    }
    if (selectedPriority != null) {
      filtered = filtered.where((t) => t.priority == selectedPriority).toList();
    }
    if (!showCompleted) {
      filtered = filtered.where((t) => !t.isCompleted).toList();
    }
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered = filtered.where((t) {
        return t.title.toLowerCase().contains(query) ||
            (t.description?.toLowerCase().contains(query) ?? false) ||
            t.tags.any((tag) => tag.toLowerCase().contains(query));
      }).toList();
    }
    filtered.sort((a, b) {
      if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
      final priorityOrder = {'urgent': 0, 'high': 1, 'medium': 2, 'low': 3};
      final aPriority = priorityOrder[a.priority] ?? 2;
      final bPriority = priorityOrder[b.priority] ?? 2;
      if (aPriority != bPriority) return aPriority.compareTo(bPriority);
      if (a.dueDate != null && b.dueDate != null) return a.dueDate!.compareTo(b.dueDate!);
      if (a.dueDate != null) return -1;
      if (b.dueDate != null) return 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return filtered;
  }
}

class TasksProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.getInstance();
  final SyncService _sync = SyncService.getInstance();
  TasksState _state = const TasksState();

  TasksState get state => _state;

  Future<void> initialize() async {
    await loadData();
  }

  Future<void> loadData() async {
    _state = _state.copyWith(isLoading: true);
    notifyListeners();

    final tasks = _db.getTasks();
    final categories = _db.getCategories();

    _state = _state.copyWith(
      tasks: tasks,
      categories: categories,
      isLoading: false,
    );
    notifyListeners();
  }

  Future<void> addTask(TaskModel task) async {
    await _db.saveTask(task);

    if (task.dueTime != null && task.dueTime!.isAfter(DateTime.now())) {
      await NotificationService.getInstance().scheduleTaskNotification(
        task.id,
        task.title,
        task.dueTime!,
      );
    }

    await loadData();
    _sync.saveTaskToFirestore(task);
  }

  Future<void> updateTask(TaskModel task) async {
    await NotificationService.getInstance().cancelTaskNotification(task.id);
    await _db.saveTask(task);

    if (task.dueTime != null && task.dueTime!.isAfter(DateTime.now()) && !task.isCompleted) {
      await NotificationService.getInstance().scheduleTaskNotification(
        task.id,
        task.title,
        task.dueTime!,
      );
    }

    await loadData();
    _sync.saveTaskToFirestore(task);
  }

  Future<void> deleteTask(String taskId) async {
    await NotificationService.getInstance().cancelTaskNotification(taskId);
    await _db.deleteTask(taskId);
    await loadData();
    _sync.deleteTaskFromFirestore(taskId);
  }

  Future<void> toggleTask(TaskModel task) async {
    final updated = task.copyWith(
      isCompleted: !task.isCompleted,
      completedAt: !task.isCompleted ? DateTime.now() : null,
      updatedAt: DateTime.now(),
      isSynced: false,
    );
    await _db.saveTask(updated);

    if (updated.isCompleted) {
      await NotificationService.getInstance().cancelTaskNotification(updated.id);
    } else if (updated.dueTime != null && updated.dueTime!.isAfter(DateTime.now())) {
      await NotificationService.getInstance().scheduleTaskNotification(
        updated.id,
        updated.title,
        updated.dueTime!,
      );
    }

    await loadData();
    _sync.saveTaskToFirestore(updated);
  }

  Future<void> addCategory(CategoryModel category) async {
    await _db.saveCategory(category);
    await loadData();
    _sync.saveCategoryToFirestore(category);
  }

  Future<void> deleteCategory(String categoryId) async {
    await _db.deleteCategory(categoryId);
    await loadData();
    _sync.deleteCategoryFromFirestore(categoryId);
  }

  void updateFilter({
    String? categoryId,
    String? priority,
    bool? showCompleted,
    String? searchQuery,
  }) {
    _state = _state.copyWith(
      selectedCategoryId: categoryId,
      selectedPriority: priority,
      showCompleted: showCompleted,
      searchQuery: searchQuery,
    );
    notifyListeners();
  }
}
