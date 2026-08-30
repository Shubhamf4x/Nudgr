import 'package:equatable/equatable.dart';

class FocusSessionModel extends Equatable {
  final String id;
  final String? taskId;
  final String? taskTitle;
  final String userId;
  final int durationMinutes;
  final int actualDurationMinutes;
  final String sessionType;
  final int sessionNumber;
  final bool isCompleted;
  final DateTime startTime;
  final DateTime? endTime;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;

  const FocusSessionModel({
    required this.id,
    this.taskId,
    this.taskTitle,
    required this.userId,
    required this.durationMinutes,
    this.actualDurationMinutes = 0,
    this.sessionType = 'focus',
    this.sessionNumber = 1,
    this.isCompleted = false,
    required this.startTime,
    this.endTime,
    required this.createdAt,
    DateTime? updatedAt,
    this.isSynced = true,
  }) : updatedAt = updatedAt ?? createdAt;

  factory FocusSessionModel.fromJson(Map<String, dynamic> json) => FocusSessionModel(
    id: json['id'] as String,
    taskId: json['taskId'] as String?,
    taskTitle: json['taskTitle'] as String?,
    userId: json['userId'] as String,
    durationMinutes: json['durationMinutes'] as int,
    actualDurationMinutes: json['actualDurationMinutes'] as int? ?? 0,
    sessionType: json['sessionType'] as String? ?? 'focus',
    sessionNumber: json['sessionNumber'] as int? ?? 1,
    isCompleted: json['isCompleted'] as bool? ?? false,
    startTime: DateTime.parse(json['startTime'] as String),
    endTime: json['endTime'] != null ? DateTime.parse(json['endTime'] as String) : null,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt'] as String) : null,
    isSynced: json['isSynced'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'taskId': taskId,
    'taskTitle': taskTitle,
    'userId': userId,
    'durationMinutes': durationMinutes,
    'actualDurationMinutes': actualDurationMinutes,
    'sessionType': sessionType,
    'sessionNumber': sessionNumber,
    'isCompleted': isCompleted,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'isSynced': isSynced,
  };

  FocusSessionModel copyWith({
    String? id,
    String? taskId,
    String? taskTitle,
    String? userId,
    int? durationMinutes,
    int? actualDurationMinutes,
    String? sessionType,
    int? sessionNumber,
    bool? isCompleted,
    DateTime? startTime,
    DateTime? endTime,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
  }) => FocusSessionModel(
    id: id ?? this.id,
    taskId: taskId ?? this.taskId,
    taskTitle: taskTitle ?? this.taskTitle,
    userId: userId ?? this.userId,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    actualDurationMinutes: actualDurationMinutes ?? this.actualDurationMinutes,
    sessionType: sessionType ?? this.sessionType,
    sessionNumber: sessionNumber ?? this.sessionNumber,
    isCompleted: isCompleted ?? this.isCompleted,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isSynced: isSynced ?? this.isSynced,
  );

  @override
  List<Object?> get props => [id, isCompleted, actualDurationMinutes];
}
