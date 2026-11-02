import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/models/task_model.dart';
import '../../shared/models/note_model.dart';
import '../../shared/models/category_model.dart';
import '../../shared/models/focus_session_model.dart';

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
  static const String _tombstonesKey = 'tombstones';
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
  Future<void> clearQuarantine() async {
    _skippedRecords.clear();
    await _prefs?.remove(_quarantineKey);
  }

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

  Future<void> markTaskSynced(String taskId) async {
    final tasks = getTasks();
    final index = tasks.indexWhere((t) => t.id == taskId);
    if (index < 0 || tasks[index].isSynced) return;
    tasks[index] = tasks[index].copyWith(isSynced: true);
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

  Future<void> markNoteSynced(String noteId) async {
    final notes = getNotes();
    final index = notes.indexWhere((n) => n.id == noteId);
    if (index < 0 || notes[index].isSynced) return;
    notes[index] = notes[index].copyWith(isSynced: true);
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

  Future<void> markCategorySynced(String categoryId) async {
    final categories = getCategories();
    final index = categories.indexWhere((c) => c.id == categoryId);
    if (index < 0 || categories[index].isSynced) return;
    categories[index] = categories[index].copyWith(isSynced: true);
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

  Future<void> deleteFocusSession(String sessionId) async {
    final sessions = getFocusSessions();
    sessions.removeWhere((s) => s.id == sessionId);
    await saveFocusSessions(sessions);
  }

  Future<void> markFocusSessionSynced(String sessionId) async {
    final sessions = getFocusSessions();
    final index = sessions.indexWhere((s) => s.id == sessionId);
    if (index < 0 || sessions[index].isSynced) return;
    sessions[index] = sessions[index].copyWith(isSynced: true);
    await saveFocusSessions(sessions);
  }

  List<Map<String, dynamic>> getTombstones() {
    final jsonString = _prefs!.getString(_tombstonesKey);
    if (jsonString == null || jsonString.isEmpty) return [];
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! List) return [];
      final result = <Map<String, dynamic>>[];
      for (final entry in decoded) {
        if (entry is! Map) continue;
        final map = Map<String, dynamic>.from(entry);
        final id = map['id'];
        final type = map['type'];
        if (id is! String || id.isEmpty) continue;
        if (type is! String || type.isEmpty) continue;
        result.add(map);
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  Future<void> addTombstones(List<Map<String, dynamic>> records) async {
    final existing = getTombstones();
    final index = <String, int>{};
    for (var i = 0; i < existing.length; i++) {
      final t = existing[i];
      index['${t['type']}|${t['id']}'] = i;
    }
    for (final record in records) {
      final id = record['id'];
      final type = record['type'];
      if (id is! String || id.isEmpty || type is! String || type.isEmpty) {
        continue;
      }
      final key = '$type|$id';
      if (index.containsKey(key)) {
        final current = existing[index[key]!];
        final candidateAt = DateTime.tryParse('${record['at']}');
        final currentAt = DateTime.tryParse('${current['at']}');
        if (candidateAt != null &&
            (currentAt == null || candidateAt.isAfter(currentAt))) {
          existing[index[key]!] = record;
        }
      } else {
        index[key] = existing.length;
        existing.add(record);
      }
    }
    await _prefs!.setString(_tombstonesKey, jsonEncode(existing));
  }

  Future<void> addTombstone(String type, String id) async {
    await addTombstones([
      {
        'id': id,
        'type': type,
        'at': DateTime.now().toIso8601String(),
      },
    ]);
  }

  Future<void> removeTombstone(String type, String id) async {
    final existing = getTombstones();
    existing.removeWhere((t) => t['type'] == type && t['id'] == id);
    await _prefs!.setString(_tombstonesKey, jsonEncode(existing));
  }

  Future<void> clearTombstones() async {
    await _prefs?.remove(_tombstonesKey);
  }

  Future<void> pruneTombstones({int maxAgeDays = 90}) async {
    final cutoff = DateTime.now().subtract(Duration(days: maxAgeDays));
    final existing = getTombstones();
    final kept = existing.where((t) {
      final at = DateTime.tryParse('${t['at']}');
      return at == null || at.isAfter(cutoff);
    }).toList();
    if (kept.length == existing.length) return;
    await _prefs!.setString(_tombstonesKey, jsonEncode(kept));
  }

  Future<void> clearAll() async {
    await _prefs!.remove(_tasksKey);
    await _prefs!.remove(_notesKey);
    await _prefs!.remove(_categoriesKey);
    await _prefs!.remove(_focusSessionsKey);
    await _prefs!.remove(_conversationsKey);
    await _prefs!.remove(_tombstonesKey);
    final keys = _prefs!.getKeys().where((k) => k.startsWith(_messagesKey));
    for (final key in keys.toList()) {
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
