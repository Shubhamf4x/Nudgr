import 'package:equatable/equatable.dart';

class SubTaskModel extends Equatable {
  final String id;
  final String title;
  final bool isCompleted;
  final DateTime createdAt;
  const SubTaskModel({
    required this.id,
    required this.title,
    this.isCompleted = false,
    required this.createdAt,
  });
  factory SubTaskModel.fromJson(Map<String, dynamic> json) => SubTaskModel(
    id: json['id'] as String,
    title: json['title'] as String,
    isCompleted: json['isCompleted'] as bool? ?? false,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'isCompleted': isCompleted,
    'createdAt': createdAt.toIso8601String(),
  };
  SubTaskModel copyWith({
    String? id,
    String? title,
    bool? isCompleted,
    DateTime? createdAt,
  }) => SubTaskModel(
    id: id ?? this.id,
    title: title ?? this.title,
    isCompleted: isCompleted ?? this.isCompleted,
    createdAt: createdAt ?? this.createdAt,
  );
  @override
  List<Object?> get props => [id, title, isCompleted];
}

class TaskModel extends Equatable {
  final String id;
  final String title;
  final String? description;
  final String? categoryId;
  final String? categoryName;
  final String priority;
  final DateTime? dueDate;
  final DateTime? dueTime;
  final bool isCompleted;
  final bool isRecurring;
  final String? recurrencePattern;
  final List<String> tags;
  final List<SubTaskModel> subtasks;
  final DateTime? reminderTime;
  final String userId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final bool isSynced;
  const TaskModel({
    required this.id,
    required this.title,
    this.description,
    this.categoryId,
    this.categoryName,
    this.priority = 'medium',
    this.dueDate,
    this.dueTime,
    this.isCompleted = false,
    this.isRecurring = false,
    this.recurrencePattern,
    this.tags = const [],
    this.subtasks = const [],
    this.reminderTime,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.isSynced = true,
  });
  factory TaskModel.fromJson(Map<String, dynamic> json) => TaskModel(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String?,
    categoryId: json['categoryId'] as String?,
    categoryName: json['categoryName'] as String?,
    priority: json['priority'] as String? ?? 'medium',
    dueDate: json['dueDate'] != null
        ? DateTime.parse(json['dueDate'] as String)
        : null,
    dueTime: json['dueTime'] != null
        ? DateTime.parse(json['dueTime'] as String)
        : null,
    isCompleted: json['isCompleted'] as bool? ?? false,
    isRecurring: json['isRecurring'] as bool? ?? false,
    recurrencePattern: json['recurrencePattern'] as String?,
    tags:
        (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
        [],
    subtasks:
        (json['subtasks'] as List<dynamic>?)
            ?.map((e) => SubTaskModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
    reminderTime: json['reminderTime'] != null
        ? DateTime.parse(json['reminderTime'] as String)
        : null,
    userId: json['userId'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    completedAt: json['completedAt'] != null
        ? DateTime.parse(json['completedAt'] as String)
        : null,
    isSynced: json['isSynced'] as bool? ?? true,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'categoryId': categoryId,
    'categoryName': categoryName,
    'priority': priority,
    'dueDate': dueDate?.toIso8601String(),
    'dueTime': dueTime?.toIso8601String(),
    'isCompleted': isCompleted,
    'isRecurring': isRecurring,
    'recurrencePattern': recurrencePattern,
    'tags': tags,
    'subtasks': subtasks.map((e) => e.toJson()).toList(),
    'reminderTime': reminderTime?.toIso8601String(),
    'userId': userId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'isSynced': isSynced,
  };
  TaskModel copyWith({
    String? id,
    String? title,
    String? description,
    String? categoryId,
    String? categoryName,
    String? priority,
    DateTime? dueDate,
    DateTime? dueTime,
    bool? isCompleted,
    bool? isRecurring,
    String? recurrencePattern,
    List<String>? tags,
    List<SubTaskModel>? subtasks,
    DateTime? reminderTime,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    bool? isSynced,
  }) => TaskModel(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    categoryId: categoryId ?? this.categoryId,
    categoryName: categoryName ?? this.categoryName,
    priority: priority ?? this.priority,
    dueDate: dueDate ?? this.dueDate,
    dueTime: dueTime ?? this.dueTime,
    isCompleted: isCompleted ?? this.isCompleted,
    isRecurring: isRecurring ?? this.isRecurring,
    recurrencePattern: recurrencePattern ?? this.recurrencePattern,
    tags: tags ?? this.tags,
    subtasks: subtasks ?? this.subtasks,
    reminderTime: reminderTime ?? this.reminderTime,
    userId: userId ?? this.userId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    isSynced: isSynced ?? this.isSynced,
  );
  @override
  List<Object?> get props => [id, title, isCompleted, priority];
}

extension TaskRecurrence on TaskModel {
  DateTime? nextOccurrenceDate() {
    if (!isRecurring) return null;
    final base = dueDate ?? DateTime.now();
    final dateOnly = DateTime(base.year, base.month, base.day);
    switch (recurrencePattern) {
      case 'daily':
        return dateOnly.add(const Duration(days: 1));
      case 'weekly':
        return dateOnly.add(const Duration(days: 7));
      case 'monthly':
        final nextMonthAnchor = DateTime(base.year, base.month + 1);
        final lastDay = DateTime(
          nextMonthAnchor.year,
          nextMonthAnchor.month + 1,
          0,
        ).day;
        final day = dateOnly.day < 1
            ? 1
            : (dateOnly.day > lastDay ? lastDay : dateOnly.day);
        return DateTime(nextMonthAnchor.year, nextMonthAnchor.month, day);
      default:
        return null;
    }
  }

  TaskModel? nextOccurrence(String newId) {
    final nextDate = nextOccurrenceDate();
    if (nextDate == null) return null;
    final now = DateTime.now();
    final shift = dueDate == null
        ? nextDate.difference(DateTime(now.year, now.month, now.day))
        : nextDate.difference(
            DateTime(dueDate!.year, dueDate!.month, dueDate!.day),
          );
    final nextReminder = reminderTime?.add(shift);
    return TaskModel(
      id: newId,
      title: title,
      description: description,
      categoryId: categoryId,
      categoryName: categoryName,
      priority: priority,
      dueDate: nextDate,
      dueTime: dueTime,
      isCompleted: false,
      isRecurring: isRecurring,
      recurrencePattern: recurrencePattern,
      tags: tags,
      subtasks: subtasks
          .map(
            (s) => SubTaskModel(
              id: '${s.id}_${nextDate.millisecondsSinceEpoch}',
              title: s.title,
              isCompleted: false,
              createdAt: now,
            ),
          )
          .toList(),
      reminderTime: nextReminder,
      userId: userId,
      createdAt: now,
      updatedAt: now,
      isSynced: false,
    );
  }
}
