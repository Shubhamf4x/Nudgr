import 'package:equatable/equatable.dart';

class MessageModel extends Equatable {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String? senderPhotoUrl;
  final String content;
  final String type;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isRead;
  final bool isDelivered;
  final bool isPending;

  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    this.senderPhotoUrl,
    required this.content,
    this.type = 'text',
    required this.createdAt,
    this.updatedAt,
    this.isRead = false,
    this.isDelivered = true,
    this.isPending = false,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) => MessageModel(
    id: json['id'] as String,
    conversationId: json['conversationId'] as String,
    senderId: json['senderId'] as String,
    senderName: json['senderName'] as String,
    senderPhotoUrl: json['senderPhotoUrl'] as String?,
    content: json['content'] as String,
    type: json['type'] as String? ?? 'text',
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt'] as String) : null,
    isRead: json['isRead'] as bool? ?? false,
    isDelivered: json['isDelivered'] as bool? ?? true,
    isPending: json['isPending'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'conversationId': conversationId,
    'senderId': senderId,
    'senderName': senderName,
    'senderPhotoUrl': senderPhotoUrl,
    'content': content,
    'type': type,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'isRead': isRead,
    'isDelivered': isDelivered,
    'isPending': isPending,
  };

  MessageModel copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? senderName,
    String? senderPhotoUrl,
    String? content,
    String? type,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isRead,
    bool? isDelivered,
    bool? isPending,
  }) => MessageModel(
    id: id ?? this.id,
    conversationId: conversationId ?? this.conversationId,
    senderId: senderId ?? this.senderId,
    senderName: senderName ?? this.senderName,
    senderPhotoUrl: senderPhotoUrl ?? this.senderPhotoUrl,
    content: content ?? this.content,
    type: type ?? this.type,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isRead: isRead ?? this.isRead,
    isDelivered: isDelivered ?? this.isDelivered,
    isPending: isPending ?? this.isPending,
  );

  @override
  List<Object?> get props => [id, content, isRead, isPending];
}
