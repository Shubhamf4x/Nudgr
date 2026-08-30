import 'package:equatable/equatable.dart';

class NoteModel extends Equatable {
  final String id;
  final String title;
  final String content;
  final String? categoryId;
  final String? categoryName;
  final List<String> tags;
  final bool isPinned;
  final bool isArchived;
  final String userId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;

  const NoteModel({
    required this.id,
    required this.title,
    required this.content,
    this.categoryId,
    this.categoryName,
    this.tags = const [],
    this.isPinned = false,
    this.isArchived = false,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = true,
  });

  String get preview => content.length > 100 ? content.substring(0, 100) : content;

  factory NoteModel.fromJson(Map<String, dynamic> json) => NoteModel(
    id: json['id'] as String,
    title: json['title'] as String,
    content: json['content'] as String,
    categoryId: json['categoryId'] as String?,
    categoryName: json['categoryName'] as String?,
    tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
    isPinned: json['isPinned'] as bool? ?? false,
    isArchived: json['isArchived'] as bool? ?? false,
    userId: json['userId'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    isSynced: json['isSynced'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'categoryId': categoryId,
    'categoryName': categoryName,
    'tags': tags,
    'isPinned': isPinned,
    'isArchived': isArchived,
    'userId': userId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'isSynced': isSynced,
  };

  NoteModel copyWith({
    String? id,
    String? title,
    String? content,
    String? categoryId,
    String? categoryName,
    List<String>? tags,
    bool? isPinned,
    bool? isArchived,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
  }) => NoteModel(
    id: id ?? this.id,
    title: title ?? this.title,
    content: content ?? this.content,
    categoryId: categoryId ?? this.categoryId,
    categoryName: categoryName ?? this.categoryName,
    tags: tags ?? this.tags,
    isPinned: isPinned ?? this.isPinned,
    isArchived: isArchived ?? this.isArchived,
    userId: userId ?? this.userId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isSynced: isSynced ?? this.isSynced,
  );

  @override
  List<Object?> get props => [id, title, isPinned, isArchived];
}
