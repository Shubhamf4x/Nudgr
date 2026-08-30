import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String id;
  final String email;
  final String displayName;
  final String? username;
  final String? photoUrl;
  final String? bio;
  final bool isOnline;
  final DateTime lastSeen;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> preferences;
  final Map<String, dynamic> statistics;

  final bool isGoogleAccount;

  const UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    this.username,
    this.photoUrl,
    this.bio,
    this.isOnline = false,
    required this.lastSeen,
    required this.createdAt,
    required this.updatedAt,
    this.preferences = const {},
    this.statistics = const {},
    this.isGoogleAccount = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'] as String,
    email: json['email'] as String,
    displayName: json['displayName'] as String,
    username: json['username'] as String?,
    photoUrl: json['photoUrl'] as String?,
    bio: json['bio'] as String?,
    isOnline: json['isOnline'] as bool? ?? false,
    lastSeen: DateTime.parse(json['lastSeen'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    preferences: (json['preferences'] as Map<String, dynamic>?) ?? {},
    statistics: (json['statistics'] as Map<String, dynamic>?) ?? {},
    isGoogleAccount: json['isGoogleAccount'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'displayName': displayName,
    'username': username,
    'photoUrl': photoUrl,
    'bio': bio,
    'isOnline': isOnline,
    'lastSeen': lastSeen.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'preferences': preferences,
    'statistics': statistics,
    'isGoogleAccount': isGoogleAccount,
  };

  UserModel copyWith({
    String? id,
    String? email,
    String? displayName,
    String? username,
    String? photoUrl,
    String? bio,
    bool? isOnline,
    DateTime? lastSeen,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? preferences,
    Map<String, dynamic>? statistics,
    bool? isGoogleAccount,
  }) => UserModel(
    id: id ?? this.id,
    email: email ?? this.email,
    displayName: displayName ?? this.displayName,
    username: username ?? this.username,
    photoUrl: photoUrl ?? this.photoUrl,
    bio: bio ?? this.bio,
    isOnline: isOnline ?? this.isOnline,
    lastSeen: lastSeen ?? this.lastSeen,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    preferences: preferences ?? this.preferences,
    statistics: statistics ?? this.statistics,
    isGoogleAccount: isGoogleAccount ?? this.isGoogleAccount,
  );

  @override
  List<Object?> get props => [id, email, displayName];
}
