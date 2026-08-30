import 'dart:async';
import 'package:flutter/material.dart';
import '../../shared/models/message_model.dart';
import '../../shared/models/conversation_model.dart';
import '../../shared/models/user_model.dart';
import '../../core/services/database_service.dart';

class ChatState {
  final List<ConversationModel> conversations;
  final List<MessageModel> messages;
  final ConversationModel? selectedConversation;
  final bool isLoading;
  final String? error;

  const ChatState({
    this.conversations = const [],
    this.messages = const [],
    this.selectedConversation,
    this.isLoading = true,
    this.error,
  });

  ChatState copyWith({
    List<ConversationModel>? conversations,
    List<MessageModel>? messages,
    ConversationModel? selectedConversation,
    bool? isLoading,
    String? error,
  }) => ChatState(
    conversations: conversations ?? this.conversations,
    messages: messages ?? this.messages,
    selectedConversation: selectedConversation ?? this.selectedConversation,
    isLoading: isLoading ?? this.isLoading,
    error: error,
  );
}

class ChatProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.getInstance();
  ChatState _state = const ChatState();
  Timer? _autoReplyTimer;

  ChatState get state => _state;

  @override
  void dispose() {
    _autoReplyTimer?.cancel();
    super.dispose();
  }

  Future<void> initialize() async {
    await loadConversations();
  }

  Future<void> loadConversations() async {
    _state = _state.copyWith(isLoading: true);
    notifyListeners();

    final conversations = _db.getConversations();
    _state = _state.copyWith(
      conversations: conversations,
      isLoading: false,
    );
    notifyListeners();
  }

  Future<void> loadMessages(String conversationId) async {
    _state = _state.copyWith(isLoading: true);
    notifyListeners();

    final messages = _db.getMessages(conversationId);
    messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    _state = _state.copyWith(
      messages: messages,
      isLoading: false,
    );
    notifyListeners();
  }

  Future<void> sendMessage({
    required String conversationId,
    required String content,
    required UserModel sender,
  }) async {
    final message = MessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      conversationId: conversationId,
      senderId: sender.id,
      senderName: sender.displayName,
      senderPhotoUrl: sender.photoUrl,
      content: content,
      createdAt: DateTime.now(),
      isPending: true,
    );

    await _db.saveMessage(message);
    _state = _state.copyWith(
      messages: [..._state.messages, message],
    );
    notifyListeners();

    final pendingMessage = message.copyWith(isPending: false, isDelivered: true);
    await _db.saveMessage(pendingMessage);

    final updatedMessages = _state.messages.map((m) {
      if (m.id == message.id) return pendingMessage;
      return m;
    }).toList();
    _state = _state.copyWith(messages: updatedMessages);
    notifyListeners();

    _updateConversationLastMessage(conversationId, content, sender.id);
    _scheduleAutoReply(conversationId, sender);
  }

  void _updateConversationLastMessage(
      String conversationId, String content, String senderId) {
    final index = _state.conversations.indexWhere((c) => c.id == conversationId);
    if (index >= 0) {
      final updated = _state.conversations[index].copyWith(
        lastMessage: content,
        lastMessageSenderId: senderId,
        lastMessageTime: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final conversations = List<ConversationModel>.from(_state.conversations);
      conversations[index] = updated;
      _state = _state.copyWith(conversations: conversations);
      _db.saveConversation(updated);
      notifyListeners();
    }
  }

  void _scheduleAutoReply(String conversationId, UserModel sender) {
    _autoReplyTimer?.cancel();
    _autoReplyTimer = Timer(const Duration(seconds: 2), () async {
      final replies = [
        'That sounds great!',
        'I\'ll get back to you on that.',
        'Thanks for letting me know!',
        'Sure, no problem!',
        'Got it!',
        'Interesting, tell me more.',
        'I agree with that.',
        'Let me think about it.',
      ];
      final reply = replies[DateTime.now().millisecondsSinceEpoch % replies.length];

      final autoReply = MessageModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        conversationId: conversationId,
        senderId: 'auto_reply',
        senderName: 'Nudgr Bot',
        content: reply,
        createdAt: DateTime.now(),
      );

      await _db.saveMessage(autoReply);
      _state = _state.copyWith(
        messages: [..._state.messages, autoReply],
      );
      notifyListeners();
    });
  }

  Future<ConversationModel> createConversation({
    required String name,
    required UserModel creator,
    bool isGroup = false,
  }) async {
    final conversation = ConversationModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      type: isGroup ? 'group' : 'direct',
      memberIds: [creator.id],
      memberNames: {creator.id: creator.displayName},
      memberPhotos: {creator.id: creator.photoUrl},
      createdBy: creator.id,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _db.saveConversation(conversation);
    _state = _state.copyWith(
      conversations: [..._state.conversations, conversation],
    );
    notifyListeners();
    return conversation;
  }

  Future<void> deleteConversation(String conversationId) async {
    final conversations = _state.conversations.where((c) => c.id != conversationId).toList();
    _state = _state.copyWith(conversations: conversations);
    await _db.saveConversations(conversations);
    notifyListeners();
  }

  Future<void> markAsRead(String conversationId) async {
    final index = _state.conversations.indexWhere((c) => c.id == conversationId);
    if (index >= 0) {
      final updated = _state.conversations[index].copyWith(unreadCount: 0);
      final conversations = List<ConversationModel>.from(_state.conversations);
      conversations[index] = updated;
      _state = _state.copyWith(conversations: conversations);
      _db.saveConversation(updated);
      notifyListeners();
    }
  }
}
