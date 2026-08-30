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

  /// Seeds the built-in categories once so the Tasks page filter chips and
  /// the Add Task screen category picker stay in sync (same IDs).
  Future<void> _ensureDefaultCategories() async {
    if (getCategories().isNotEmpty) return;
    final now = DateTime.now();
    final defaults = [
      CategoryModel(id: 'work', name: 'Work', colorIndex: 0, userId: '', createdAt: now, updatedAt: now),
      CategoryModel(id: 'study', name: 'Study', colorIndex: 1, userId: '', createdAt: now, updatedAt: now),
      CategoryModel(id: 'personal', name: 'Personal', colorIndex: 2, userId: '', createdAt: now, updatedAt: now),
      CategoryModel(id: 'fitness', name: 'Fitness', colorIndex: 4, userId: '', createdAt: now, updatedAt: now),
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

  Future<void> saveTasks(List<TaskModel> tasks) async {
    final jsonList = tasks.map((t) => t.toJson()).toList();
    await _prefs!.setString(_tasksKey, jsonEncode(jsonList));
  }

  List<TaskModel> getTasks() {
    final jsonString = _prefs!.getString(_tasksKey);
    if (jsonString == null) return [];
    final jsonList = jsonDecode(jsonString) as List<dynamic>;
    return jsonList.map((e) => TaskModel.fromJson(e as Map<String, dynamic>)).toList();
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
    final jsonList = notes.map((n) => n.toJson()).toList();
    await _prefs!.setString(_notesKey, jsonEncode(jsonList));
  }

  List<NoteModel> getNotes() {
    final jsonString = _prefs!.getString(_notesKey);
    if (jsonString == null) return [];
    final jsonList = jsonDecode(jsonString) as List<dynamic>;
    return jsonList.map((e) => NoteModel.fromJson(e as Map<String, dynamic>)).toList();
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
    final jsonList = categories.map((c) => c.toJson()).toList();
    await _prefs!.setString(_categoriesKey, jsonEncode(jsonList));
  }

  List<CategoryModel> getCategories() {
    final jsonString = _prefs!.getString(_categoriesKey);
    if (jsonString == null) return [];
    final jsonList = jsonDecode(jsonString) as List<dynamic>;
    return jsonList.map((e) => CategoryModel.fromJson(e as Map<String, dynamic>)).toList();
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
    final jsonList = sessions.map((s) => s.toJson()).toList();
    await _prefs!.setString(_focusSessionsKey, jsonEncode(jsonList));
  }

  List<FocusSessionModel> getFocusSessions() {
    final jsonString = _prefs!.getString(_focusSessionsKey);
    if (jsonString == null) return [];
    final jsonList = jsonDecode(jsonString) as List<dynamic>;
    return jsonList.map((e) => FocusSessionModel.fromJson(e as Map<String, dynamic>)).toList();
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
    final jsonList = conversations.map((c) => c.toJson()).toList();
    await _prefs!.setString(_conversationsKey, jsonEncode(jsonList));
  }

  List<ConversationModel> getConversations() {
    final jsonString = _prefs!.getString(_conversationsKey);
    if (jsonString == null) return [];
    final jsonList = jsonDecode(jsonString) as List<dynamic>;
    return jsonList.map((e) => ConversationModel.fromJson(e as Map<String, dynamic>)).toList();
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
    if (jsonString == null) return [];
    final jsonList = jsonDecode(jsonString) as List<dynamic>;
    return jsonList.map((e) => MessageModel.fromJson(e as Map<String, dynamic>)).toList();
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
    await _prefs!.setString('${_messagesKey}_${message.conversationId}', jsonEncode(jsonList));
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

  // ── Local data ownership ──────────────────────────────────────────
  static const String _dataOwnerKey = 'local_data_owner_uid';

  /// UID that currently owns the on-device data. Used to detect account
  /// switching so one user's local notes/tasks are never merged into
  /// another user's cloud account.
  String? getDataOwnerUid() => _prefs!.getString(_dataOwnerKey);

  Future<void> setDataOwnerUid(String uid) async {
    await _prefs!.setString(_dataOwnerKey, uid);
  }
}
