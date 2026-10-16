import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/models/task_model.dart';
import '../../shared/models/note_model.dart';
import '../../shared/models/category_model.dart';
import '../../shared/models/focus_session_model.dart';
import '../../shared/models/conversation_model.dart';
import '../../shared/models/message_model.dart';

class DatabaseService {
  static DatabaseService? _instance;
  static SharedPreferences? _prefs;
  DatabaseService._();
  static DatabaseService getInstance() {
    _instance ??= DatabaseService._();
    return _instance!;
  }

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _ensureDefaultCategories();
  }

  Future<void> _ensureDefaultCategories() async {
    if (getCategories().isNotEmpty) return;
    final now = DateTime.now();
    final defaults = [
      CategoryModel(
        id: 'work',
        name: 'Work',
        colorIndex: 0,
        userId: '',
        createdAt: now,
        updatedAt: now,
      ),
      CategoryModel(
        id: 'study',
        name: 'Study',
        colorIndex: 1,
        userId: '',
        createdAt: now,
        updatedAt: now,
      ),
      CategoryModel(
        id: 'personal',
        name: 'Personal',
        colorIndex: 2,
        userId: '',
        createdAt: now,
        updatedAt: now,
      ),
      CategoryModel(
        id: 'fitness',
        name: 'Fitness',
        colorIndex: 4,
        userId: '',
        createdAt: now,
        updatedAt: now,
      ),
    ];
    await saveCategories(defaults);
  }

  SharedPreferences get prefs => _prefs!;
  static const String _tasksKey = 'tasks';
  static const String _notesKey = 'notes';
  static const String _categoriesKey = 'categories';
  static const String _focusSessionsKey = 'focus_sessions';
  static const String _conversationsKey = 'conversations';
  static const String _messagesKey = 'messages';
  List<T> _decodeList<T>(
    String jsonString,
    T Function(Map<String, dynamic>) fromJson, {
    String? quarantineKey,
  }) {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! List) return [];
      final result = <T>[];
      final skipped = <String>[];
      for (final entry in decoded) {
        if (entry is! Map) continue;
        final map = Map<String, dynamic>.from(entry);
        try {
          result.add(fromJson(map));
        } catch (_) {
          if (quarantineKey != null) skipped.add(jsonEncode(map));
        }
      }
      if (quarantineKey != null) {
        if (skipped.isEmpty) {
          _skippedRecords.remove(quarantineKey);
        } else {
          _skippedRecords[quarantineKey] = skipped;
        }
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  final Map<String, List<String>> _skippedRecords = {};
  Future<void> _quarantineSkipped(String key) async {
    final skipped = _skippedRecords.remove(key);
    if (skipped == null || skipped.isEmpty) return;
    try {
      final stored = _prefs!.getStringList(_quarantineKey) ?? <String>[];
      final now = DateTime.now().toIso8601String();
      stored.addAll(
        skipped.map((raw) => jsonEncode({'key': key, 'at': now, 'raw': raw})),
      );
      if (stored.length > _maxQuarantinedRecords) {
        stored.removeRange(0, stored.length - _maxQuarantinedRecords);
      }
      await _prefs!.setStringList(_quarantineKey, stored);
    } catch (_) {}
  }

  static const String _quarantineKey = 'quarantined_records';
  static const int _maxQuarantinedRecords = 200;
  int get quarantinedRecordCount =>
      _prefs?.getStringList(_quarantineKey)?.length ?? 0;
  Future<void> saveTasks(List<TaskModel> tasks) async {
    await _quarantineSkipped(_tasksKey);
    final jsonList = tasks.map((t) => t.toJson()).toList();
    await _prefs!.setString(_tasksKey, jsonEncode(jsonList));
  }

  List<TaskModel> getTasks() {
    final jsonString = _prefs!.getString(_tasksKey);
    if (jsonString == null || jsonString.isEmpty) return [];
    return _decodeList(
      jsonString,
      (m) => TaskModel.fromJson(m),
      quarantineKey: _tasksKey,
    );
  }

  Future<void> saveTask(TaskModel task) async {
    final tasks = getTasks();
    final index = tasks.indexWhere((t) => t.id == task.id);
    if (index >= 0) {
      tasks[index] = task;
    } else {
      tasks.add(task);
    }
    await saveTasks(tasks);
  }

  Future<void> deleteTask(String taskId) async {
    final tasks = getTasks();
    tasks.removeWhere((t) => t.id == taskId);
    await saveTasks(tasks);
  }

  Future<void> saveNotes(List<NoteModel> notes) async {
    await _quarantineSkipped(_notesKey);
    final jsonList = notes.map((n) => n.toJson()).toList();
    await _prefs!.setString(_notesKey, jsonEncode(jsonList));
  }

  List<NoteModel> getNotes() {
    final jsonString = _prefs!.getString(_notesKey);
    if (jsonString == null || jsonString.isEmpty) return [];
    return _decodeList(
      jsonString,
      (m) => NoteModel.fromJson(m),
      quarantineKey: _notesKey,
    );
  }

  Future<void> saveNote(NoteModel note) async {
    final notes = getNotes();
    final index = notes.indexWhere((n) => n.id == note.id);
    if (index >= 0) {
      notes[index] = note;
    } else {
      notes.add(note);
    }
    await saveNotes(notes);
  }

  Future<void> deleteNote(String noteId) async {
    final notes = getNotes();
    notes.removeWhere((n) => n.id == noteId);
    await saveNotes(notes);
  }

  Future<void> saveCategories(List<CategoryModel> categories) async {
    await _quarantineSkipped(_categoriesKey);
    final jsonList = categories.map((c) => c.toJson()).toList();
    await _prefs!.setString(_categoriesKey, jsonEncode(jsonList));
  }

  List<CategoryModel> getCategories() {
    final jsonString = _prefs!.getString(_categoriesKey);
    if (jsonString == null || jsonString.isEmpty) return [];
    return _decodeList(
      jsonString,
      (m) => CategoryModel.fromJson(m),
      quarantineKey: _categoriesKey,
    );
  }

  Future<void> saveCategory(CategoryModel category) async {
    final categories = getCategories();
    final index = categories.indexWhere((c) => c.id == category.id);
    if (index >= 0) {
      categories[index] = category;
    } else {
      categories.add(category);
    }
    await saveCategories(categories);
  }

  Future<void> deleteCategory(String categoryId) async {
    final categories = getCategories();
    categories.removeWhere((c) => c.id == categoryId);
    await saveCategories(categories);
  }

  Future<void> saveFocusSessions(List<FocusSessionModel> sessions) async {
    await _quarantineSkipped(_focusSessionsKey);
    final jsonList = sessions.map((s) => s.toJson()).toList();
    await _prefs!.setString(_focusSessionsKey, jsonEncode(jsonList));
  }

  List<FocusSessionModel> getFocusSessions() {
    final jsonString = _prefs!.getString(_focusSessionsKey);
    if (jsonString == null || jsonString.isEmpty) return [];
    return _decodeList(
      jsonString,
      (m) => FocusSessionModel.fromJson(m),
      quarantineKey: _focusSessionsKey,
    );
  }

  Future<void> saveFocusSession(FocusSessionModel session) async {
    final sessions = getFocusSessions();
    final index = sessions.indexWhere((s) => s.id == session.id);
    if (index >= 0) {
      sessions[index] = session;
    } else {
      sessions.add(session);
    }
    await saveFocusSessions(sessions);
  }

  Future<void> saveConversations(List<ConversationModel> conversations) async {
    await _quarantineSkipped(_conversationsKey);
    final jsonList = conversations.map((c) => c.toJson()).toList();
    await _prefs!.setString(_conversationsKey, jsonEncode(jsonList));
  }

  List<ConversationModel> getConversations() {
    final jsonString = _prefs!.getString(_conversationsKey);
    if (jsonString == null || jsonString.isEmpty) return [];
    return _decodeList(
      jsonString,
      (m) => ConversationModel.fromJson(m),
      quarantineKey: _conversationsKey,
    );
  }

  Future<void> saveConversation(ConversationModel conversation) async {
    final conversations = getConversations();
    final index = conversations.indexWhere((c) => c.id == conversation.id);
    if (index >= 0) {
      conversations[index] = conversation;
    } else {
      conversations.add(conversation);
    }
    await saveConversations(conversations);
  }

  List<MessageModel> getMessages(String conversationId) {
    final jsonString = _prefs!.getString('${_messagesKey}_$conversationId');
    if (jsonString == null || jsonString.isEmpty) return [];
    return _decodeList(jsonString, (m) => MessageModel.fromJson(m));
  }

  Future<void> saveMessage(MessageModel message) async {
    final messages = getMessages(message.conversationId);
    final index = messages.indexWhere((m) => m.id == message.id);
    if (index >= 0) {
      messages[index] = message;
    } else {
      messages.add(message);
    }
    final jsonList = messages.map((m) => m.toJson()).toList();
    await _prefs!.setString(
      '${_messagesKey}_${message.conversationId}',
      jsonEncode(jsonList),
    );
  }

  Future<void> clearAll() async {
    await _prefs!.remove(_tasksKey);
    await _prefs!.remove(_notesKey);
    await _prefs!.remove(_categoriesKey);
    await _prefs!.remove(_focusSessionsKey);
    await _prefs!.remove(_conversationsKey);
    final keys = _prefs!.getKeys().where((k) => k.startsWith(_messagesKey));
    for (final key in keys) {
      await _prefs!.remove(key);
    }
    await _prefs!.remove(_dataOwnerKey);
  }

  Future<void> clearDataOwner() async {
    await _prefs!.remove(_dataOwnerKey);
  }

  static const String _dataOwnerKey = 'local_data_owner_uid';
  String? getDataOwnerUid() => _prefs!.getString(_dataOwnerKey);
  Future<void> setDataOwnerUid(String uid) async {
    await _prefs!.setString(_dataOwnerKey, uid);
  }
}
