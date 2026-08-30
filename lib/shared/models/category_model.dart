import 'package:equatable/equatable.dart';

class CategoryModel extends Equatable {
  final String id;
  final String name;
  final int colorIndex;
  final String? icon;
  final String userId;
  final String type;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;

  const CategoryModel({
    required this.id,
    required this.name,
    this.colorIndex = 0,
    this.icon,
    required this.userId,
    this.type = 'task',
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = true,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) => CategoryModel(
    id: json['id'] as String,
    name: json['name'] as String,
    colorIndex: json['colorIndex'] as int? ?? 0,
    icon: json['icon'] as String?,
    userId: json['userId'] as String,
    type: json['type'] as String? ?? 'task',
    sortOrder: json['sortOrder'] as int? ?? 0,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    isSynced: json['isSynced'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'colorIndex': colorIndex,
    'icon': icon,
    'userId': userId,
    'type': type,
    'sortOrder': sortOrder,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'isSynced': isSynced,
  };

  CategoryModel copyWith({
    String? id,
    String? name,
    int? colorIndex,
    String? icon,
    String? userId,
    String? type,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
  }) => CategoryModel(
    id: id ?? this.id,
    name: name ?? this.name,
    colorIndex: colorIndex ?? this.colorIndex,
    icon: icon ?? this.icon,
    userId: userId ?? this.userId,
    type: type ?? this.type,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isSynced: isSynced ?? this.isSynced,
  );

  @override
  List<Object?> get props => [id, name, colorIndex, type];
}
