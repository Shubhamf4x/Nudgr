import 'package:equatable/equatable.dart';

class ConversationModel extends Equatable {
  final String id;
  final String? name;
  final String? photoUrl;
  final String type;
  final List<String> memberIds;
  final Map<String, String> memberNames;
  final Map<String, String?> memberPhotos;
  final String? lastMessage;
  final String? lastMessageSenderId;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPinned;
  final bool isMuted;

  const ConversationModel({
    required this.id,
    this.name,
    this.photoUrl,
    this.type = 'direct',
    this.memberIds = const [],
    this.memberNames = const {},
    this.memberPhotos = const {},
    this.lastMessage,
    this.lastMessageSenderId,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.isPinned = false,
    this.isMuted = false,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) => ConversationModel(
    id: json['id'] as String,
    name: json['name'] as String?,
    photoUrl: json['photoUrl'] as String?,
    type: json['type'] as String? ?? 'direct',
    memberIds: (json['memberIds'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
    memberNames: (json['memberNames'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as String)) ?? {},
    memberPhotos: (json['memberPhotos'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as String?)) ?? {},
    lastMessage: json['lastMessage'] as String?,
    lastMessageSenderId: json['lastMessageSenderId'] as String?,
    lastMessageTime: json['lastMessageTime'] != null ? DateTime.parse(json['lastMessageTime'] as String) : null,
    unreadCount: json['unreadCount'] as int? ?? 0,
    createdBy: json['createdBy'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    isPinned: json['isPinned'] as bool? ?? false,
    isMuted: json['isMuted'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'photoUrl': photoUrl,
    'type': type,
    'memberIds': memberIds,
    'memberNames': memberNames,
    'memberPhotos': memberPhotos,
    'lastMessage': lastMessage,
    'lastMessageSenderId': lastMessageSenderId,
    'lastMessageTime': lastMessageTime?.toIso8601String(),
    'unreadCount': unreadCount,
    'createdBy': createdBy,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'isPinned': isPinned,
    'isMuted': isMuted,
  };

  ConversationModel copyWith({
    String? id,
    String? name,
    String? photoUrl,
    String? type,
    List<String>? memberIds,
    Map<String, String>? memberNames,
    Map<String, String?>? memberPhotos,
    String? lastMessage,
    String? lastMessageSenderId,
    DateTime? lastMessageTime,
    int? unreadCount,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPinned,
    bool? isMuted,
  }) => ConversationModel(
    id: id ?? this.id,
    name: name ?? this.name,
    photoUrl: photoUrl ?? this.photoUrl,
    type: type ?? this.type,
    memberIds: memberIds ?? this.memberIds,
    memberNames: memberNames ?? this.memberNames,
    memberPhotos: memberPhotos ?? this.memberPhotos,
    lastMessage: lastMessage ?? this.lastMessage,
    lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
    lastMessageTime: lastMessageTime ?? this.lastMessageTime,
    unreadCount: unreadCount ?? this.unreadCount,
    createdBy: createdBy ?? this.createdBy,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isPinned: isPinned ?? this.isPinned,
    isMuted: isMuted ?? this.isMuted,
  );

  @override
  List<Object?> get props => [id, name, type, lastMessage, unreadCount];
}
