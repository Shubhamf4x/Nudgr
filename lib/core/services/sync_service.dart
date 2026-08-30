import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/models/task_model.dart';
import '../../shared/models/note_model.dart';
import '../../shared/models/category_model.dart';
import '../../shared/models/focus_session_model.dart';
import 'database_service.dart';
import 'auth_service.dart';
import 'steps_service.dart';

enum SyncStatus { idle, syncing, error, offline }

enum SyncOperation { create, update, delete }

class SyncQueueItem {
  final String id;
  final String collection;
  final String documentId;
  final SyncOperation operation;
  final Map<String, dynamic>? data;
  final DateTime timestamp;
  int retryCount;

  SyncQueueItem({
    required this.id,
    required this.collection,
    required this.documentId,
    required this.operation,
    this.data,
    DateTime? timestamp,
    this.retryCount = 0,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'collection': collection,
    'documentId': documentId,
    'operation': operation.name,
    'data': data,
    'timestamp': timestamp.toIso8601String(),
    'retryCount': retryCount,
  };

  factory SyncQueueItem.fromJson(Map<String, dynamic> json) => SyncQueueItem(
    id: json['id'] as String,
    collection: json['collection'] as String,
    documentId: json['documentId'] as String,
    operation: SyncOperation.values.firstWhere(
      (e) => e.name == json['operation'],
      orElse: () => SyncOperation.update,
    ),
    data: json['data'] as Map<String, dynamic>?,
    timestamp: DateTime.parse(json['timestamp'] as String),
    retryCount: json['retryCount'] as int? ?? 0,
  );
}

class SyncService {
  static SyncService? _instance;
  static SharedPreferences? _prefs;
  final DatabaseService _db = DatabaseService.getInstance();
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  String? _currentUserId;
  bool _cloudEnabled = false;
  SyncStatus _status = SyncStatus.idle;
  DateTime? _lastSyncTime;
  int _pendingCount = 0;
  bool _isSyncing = false;
  bool _isOnline = true;
  final int _maxRetries = 3;

  static const String _syncQueueKey = 'sync_queue';
  static const String _lastSyncKey = 'last_sync_time';

  SyncService._();

  static SyncService getInstance() {
    _instance ??= SyncService._();
    return _instance!;
  }

  SyncStatus get status => _status;
  DateTime? get lastSyncTime => _lastSyncTime;
  int get pendingCount => _pendingCount;
  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  String? get currentUserId => _currentUserId;
  bool get cloudEnabled => _cloudEnabled;

  /// Cloud sync is only active for accounts that opt in (Google sign-in).
  /// Email/password accounts remain purely local.
  bool get _canSync => _cloudEnabled && _currentUserId != null && _isOnline;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _loadLastSyncTime();
    await _loadSyncQueue();

    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((results) {
      final wasOnline = _isOnline;
      _isOnline = results.any((r) => r != ConnectivityResult.none);

      if (_isOnline && !wasOnline) {
        syncPendingData();
      }
    });

    final results = await _connectivity.checkConnectivity();
    _isOnline = results.any((r) => r != ConnectivityResult.none);
  }

  void setUser(String? userId, {bool cloudEnabled = false}) {
    _currentUserId = userId;
    _cloudEnabled = cloudEnabled;
    if (userId != null && _canSync) {
      syncPendingData();
    }
  }

  // ── Queue Management ──────────────────────────────────────────────

  List<SyncQueueItem> _syncQueue = [];

  Future<void> _loadSyncQueue() async {
    final jsonString = _prefs?.getString(_syncQueueKey);
    if (jsonString == null || jsonString.isEmpty) {
      _syncQueue = [];
      return;
    }
    try {
      final decoded = jsonDecode(jsonString) as List<dynamic>;
      _syncQueue = decoded
          .map((e) => SyncQueueItem.fromJson(e as Map<String, dynamic>))
          .toList();
      _pendingCount = _syncQueue.length;
    } catch (e) {
      _syncQueue = [];
    }
  }

  Future<void> _saveSyncQueue() async {
    final jsonList = _syncQueue.map((item) => item.toJson()).toList();
    await _prefs!.setString(_syncQueueKey, jsonEncode(jsonList));
    _pendingCount = _syncQueue.length;
  }

  void addToQueue({
    required String collection,
    required String documentId,
    required SyncOperation operation,
    Map<String, dynamic>? data,
  }) {
    // Never queue changes for accounts without cloud sync.
    if (!_cloudEnabled) return;

    final item = SyncQueueItem(
      id: '${collection}_${documentId}_${DateTime.now().millisecondsSinceEpoch}',
      collection: collection,
      documentId: documentId,
      operation: operation,
      data: data,
    );
    _syncQueue.add(item);
    _pendingCount = _syncQueue.length;
    _saveSyncQueue();

    if (_isOnline && !_isSyncing) {
      syncPendingData();
    }
  }

  // ── Firestore References ──────────────────────────────────────────

  CollectionReference _userCollection(String collection) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUserId)
        .collection(collection);
  }

  // ── Push Local → Cloud ────────────────────────────────────────────

  Future<void> syncPendingData() async {
    if (_isSyncing || !_canSync) return;

    _isSyncing = true;
    _status = SyncStatus.syncing;

    try {
      final items = List<SyncQueueItem>.from(_syncQueue);
      final failedItems = <SyncQueueItem>[];

      for (final item in items) {
        try {
          await _processQueueItem(item);
          _syncQueue.removeWhere((q) => q.id == item.id);
        } catch (e) {
          item.retryCount++;
          if (item.retryCount >= _maxRetries) {
            _syncQueue.removeWhere((q) => q.id == item.id);
          } else {
            failedItems.add(item);
          }
        }
      }

      await _saveSyncQueue();
      _lastSyncTime = DateTime.now();
      await _prefs!.setString(_lastSyncKey, _lastSyncTime!.toIso8601String());
      _status = _syncQueue.isEmpty ? SyncStatus.idle : SyncStatus.error;
    } catch (e) {
      _status = SyncStatus.error;
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _processQueueItem(SyncQueueItem item) async {
    final ref = _userCollection(item.collection).doc(item.documentId);

    switch (item.operation) {
      case SyncOperation.create:
      case SyncOperation.update:
        if (item.data != null) {
          await ref.set(item.data!, SetOptions(merge: true));
        }
        break;
      case SyncOperation.delete:
        await ref.delete();
        break;
    }
  }

  // ── Pull Cloud → Local ────────────────────────────────────────────

  Future<void> pullFromCloud() async {
    if (!_canSync) return;

    _status = SyncStatus.syncing;
    _isSyncing = true;

    try {
      await _pullTasks();
      await _pullNotes();
      await _pullCategories();
      await _pullFocusSessions();
      await _pullSteps();
      await _pullUserProfile();

      _lastSyncTime = DateTime.now();
      await _prefs!.setString(_lastSyncKey, _lastSyncTime!.toIso8601String());
      _status = SyncStatus.idle;
    } catch (e) {
      _status = SyncStatus.error;
    } finally {
      _isSyncing = false;
    }
  }

  /// Restores daily step history (Google users, e.g. new device/reinstall).
  Future<void> _pullSteps() async {
    final snapshot = await _userCollection('steps').get();
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final date = data['date'] as String?;
      final count = data['stepCount'] as int?;
      if (date == null || count == null || count < 0) continue;
      await StepsService.getInstance().mergeCloudStepDay(date, count);
    }
  }

  /// Restores the profile document (username, bio, photo, statistics).
  Future<void> _pullUserProfile() async {
    if (_currentUserId == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUserId!)
        .get();
    if (!doc.exists) return;
    final data = doc.data();
    if (data == null || data.isEmpty) return;
    AuthService.getInstance().mergeCloudProfile(data);
  }

  Future<void> _pullTasks() async {
    final snapshot = await _userCollection('tasks').get();
    final cloudTasks = <TaskModel>[];
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      cloudTasks.add(TaskModel.fromJson(data));
    }

    if (cloudTasks.isEmpty) return;

    final localTasks = _db.getTasks();
    final localMap = {for (final t in localTasks) t.id: t};
    final cloudMap = {for (final t in cloudTasks) t.id: t};

    final merged = <TaskModel>[];

    for (final cloudTask in cloudTasks) {
      final localTask = localMap[cloudTask.id];
      if (localTask == null) {
        merged.add(cloudTask);
      } else {
        merged.add(_resolveConflictTask(localTask, cloudTask));
      }
    }

    for (final localTask in localTasks) {
      if (!cloudMap.containsKey(localTask.id)) {
        merged.add(localTask);
        addToQueue(
          collection: 'tasks',
          documentId: localTask.id,
          operation: SyncOperation.create,
          data: localTask.toJson(),
        );
      }
    }

    await _db.saveTasks(merged);
  }

  Future<void> _pullNotes() async {
    final snapshot = await _userCollection('notes').get();
    final cloudNotes = <NoteModel>[];
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      cloudNotes.add(NoteModel.fromJson(data));
    }

    if (cloudNotes.isEmpty) return;

    final localNotes = _db.getNotes();
    final localMap = {for (final n in localNotes) n.id: n};
    final cloudMap = {for (final n in cloudNotes) n.id: n};

    final merged = <NoteModel>[];

    for (final cloudNote in cloudNotes) {
      final localNote = localMap[cloudNote.id];
      if (localNote == null) {
        merged.add(cloudNote);
      } else {
        merged.add(_resolveConflictNote(localNote, cloudNote));
      }
    }

    for (final localNote in localNotes) {
      if (!cloudMap.containsKey(localNote.id)) {
        merged.add(localNote);
        addToQueue(
          collection: 'notes',
          documentId: localNote.id,
          operation: SyncOperation.create,
          data: localNote.toJson(),
        );
      }
    }

    await _db.saveNotes(merged);
  }

  Future<void> _pullCategories() async {
    final snapshot = await _userCollection('categories').get();
    final cloudCategories = <CategoryModel>[];
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      cloudCategories.add(CategoryModel.fromJson(data));
    }

    if (cloudCategories.isEmpty) return;

    final localCategories = _db.getCategories();
    final localMap = {for (final c in localCategories) c.id: c};
    final cloudMap = {for (final c in cloudCategories) c.id: c};

    final merged = <CategoryModel>[];

    for (final cloudCat in cloudCategories) {
      final localCat = localMap[cloudCat.id];
      if (localCat == null) {
        merged.add(cloudCat);
      } else {
        merged.add(_resolveConflictCategory(localCat, cloudCat));
      }
    }

    for (final localCat in localCategories) {
      if (!cloudMap.containsKey(localCat.id)) {
        merged.add(localCat);
        addToQueue(
          collection: 'categories',
          documentId: localCat.id,
          operation: SyncOperation.create,
          data: localCat.toJson(),
        );
      }
    }

    await _db.saveCategories(merged);
  }

  Future<void> _pullFocusSessions() async {
    final snapshot = await _userCollection('focus_sessions').get();
    final cloudSessions = <FocusSessionModel>[];
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      cloudSessions.add(FocusSessionModel.fromJson(data));
    }

    if (cloudSessions.isEmpty) return;

    final localSessions = _db.getFocusSessions();
    final localMap = {for (final s in localSessions) s.id: s};
    final cloudMap = {for (final s in cloudSessions) s.id: s};

    final merged = <FocusSessionModel>[];

    for (final cloudSession in cloudSessions) {
      final localSession = localMap[cloudSession.id];
      if (localSession == null) {
        merged.add(cloudSession);
      } else {
        merged.add(_resolveConflictFocusSession(localSession, cloudSession));
      }
    }

    for (final localSession in localSessions) {
      if (!cloudMap.containsKey(localSession.id)) {
        merged.add(localSession);
        addToQueue(
          collection: 'focus_sessions',
          documentId: localSession.id,
          operation: SyncOperation.create,
          data: localSession.toJson(),
        );
      }
    }

    await _db.saveFocusSessions(merged);
  }

  // ── Conflict Resolution (Last-Write-Wins) ─────────────────────────

  TaskModel _resolveConflictTask(TaskModel local, TaskModel cloud) {
    if (!local.isSynced && cloud.isSynced) return local;
    if (local.isSynced && !cloud.isSynced) return cloud;
    return local.updatedAt.isAfter(cloud.updatedAt) ? local : cloud;
  }

  NoteModel _resolveConflictNote(NoteModel local, NoteModel cloud) {
    if (!local.isSynced && cloud.isSynced) return local;
    if (local.isSynced && !cloud.isSynced) return cloud;
    return local.updatedAt.isAfter(cloud.updatedAt) ? local : cloud;
  }

  CategoryModel _resolveConflictCategory(
      CategoryModel local, CategoryModel cloud) {
    if (!local.isSynced && cloud.isSynced) return local;
    if (local.isSynced && !cloud.isSynced) return cloud;
    return local.updatedAt.isAfter(cloud.updatedAt) ? local : cloud;
  }

  FocusSessionModel _resolveConflictFocusSession(
      FocusSessionModel local, FocusSessionModel cloud) {
    if (!local.isSynced && cloud.isSynced) return local;
    if (local.isSynced && !cloud.isSynced) return cloud;
    return local.updatedAt.isAfter(cloud.updatedAt) ? local : cloud;
  }

  // ── Full Sync (Push + Pull) ───────────────────────────────────────

  Future<void> fullSync() async {
    if (!_canSync) return;
    await syncPendingData();
    await pullFromCloud();
  }

  // ── Direct Firestore Operations (for immediate sync) ──────────────

  Future<void> saveTaskToFirestore(TaskModel task) async {
    if (!_canSync) {
      addToQueue(
        collection: 'tasks',
        documentId: task.id,
        operation: SyncOperation.update,
        data: task.toJson(),
      );
      return;
    }

    try {
      await _userCollection('tasks').doc(task.id).set(
            task.toJson(),
            SetOptions(merge: true),
          );
      _lastSyncTime = DateTime.now();
      await _prefs!.setString(_lastSyncKey, _lastSyncTime!.toIso8601String());
    } catch (e) {
      addToQueue(
        collection: 'tasks',
        documentId: task.id,
        operation: SyncOperation.update,
        data: task.toJson(),
      );
    }
  }

  Future<void> deleteTaskFromFirestore(String taskId) async {
    if (!_canSync) {
      addToQueue(
        collection: 'tasks',
        documentId: taskId,
        operation: SyncOperation.delete,
      );
      return;
    }

    try {
      await _userCollection('tasks').doc(taskId).delete();
    } catch (e) {
      addToQueue(
        collection: 'tasks',
        documentId: taskId,
        operation: SyncOperation.delete,
      );
    }
  }

  Future<void> saveNoteToFirestore(NoteModel note) async {
    if (!_canSync) {
      addToQueue(
        collection: 'notes',
        documentId: note.id,
        operation: SyncOperation.update,
        data: note.toJson(),
      );
      return;
    }

    try {
      await _userCollection('notes').doc(note.id).set(
            note.toJson(),
            SetOptions(merge: true),
          );
      _lastSyncTime = DateTime.now();
      await _prefs!.setString(_lastSyncKey, _lastSyncTime!.toIso8601String());
    } catch (e) {
      addToQueue(
        collection: 'notes',
        documentId: note.id,
        operation: SyncOperation.update,
        data: note.toJson(),
      );
    }
  }

  Future<void> deleteNoteFromFirestore(String noteId) async {
    if (!_canSync) {
      addToQueue(
        collection: 'notes',
        documentId: noteId,
        operation: SyncOperation.delete,
      );
      return;
    }

    try {
      await _userCollection('notes').doc(noteId).delete();
    } catch (e) {
      addToQueue(
        collection: 'notes',
        documentId: noteId,
        operation: SyncOperation.delete,
      );
    }
  }

  Future<void> saveCategoryToFirestore(CategoryModel category) async {
    if (!_canSync) {
      addToQueue(
        collection: 'categories',
        documentId: category.id,
        operation: SyncOperation.update,
        data: category.toJson(),
      );
      return;
    }

    try {
      await _userCollection('categories').doc(category.id).set(
            category.toJson(),
            SetOptions(merge: true),
          );
    } catch (e) {
      addToQueue(
        collection: 'categories',
        documentId: category.id,
        operation: SyncOperation.update,
        data: category.toJson(),
      );
    }
  }

  Future<void> deleteCategoryFromFirestore(String categoryId) async {
    if (!_canSync) {
      addToQueue(
        collection: 'categories',
        documentId: categoryId,
        operation: SyncOperation.delete,
      );
      return;
    }

    try {
      await _userCollection('categories').doc(categoryId).delete();
    } catch (e) {
      addToQueue(
        collection: 'categories',
        documentId: categoryId,
        operation: SyncOperation.delete,
      );
    }
  }

  Future<void> saveFocusSessionToFirestore(FocusSessionModel session) async {
    if (!_canSync) {
      addToQueue(
        collection: 'focus_sessions',
        documentId: session.id,
        operation: SyncOperation.update,
        data: session.toJson(),
      );
      return;
    }

    try {
      await _userCollection('focus_sessions').doc(session.id).set(
            session.toJson(),
            SetOptions(merge: true),
          );
    } catch (e) {
      addToQueue(
        collection: 'focus_sessions',
        documentId: session.id,
        operation: SyncOperation.update,
        data: session.toJson(),
      );
    }
  }

  Future<void> saveStepDayToFirestore(String date, int stepCount) async {
    if (!_canSync) {
      addToQueue(
        collection: 'steps',
        documentId: date,
        operation: SyncOperation.update,
        data: {'date': date, 'stepCount': stepCount},
      );
      return;
    }

    try {
      await _userCollection('steps').doc(date).set(
            {'date': date, 'stepCount': stepCount},
            SetOptions(merge: true),
          );
    } catch (e) {
      addToQueue(
        collection: 'steps',
        documentId: date,
        operation: SyncOperation.update,
        data: {'date': date, 'stepCount': stepCount},
      );
    }
  }

  Future<void> saveUserToFirestore(Map<String, dynamic> userData) async {
    if (!_canSync) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .set(userData, SetOptions(merge: true));
    } catch (_) {}
  }

  // ── Helpers ────────────────────────────────────────────────────────

  void _loadLastSyncTime() {
    final timeStr = _prefs?.getString(_lastSyncKey);
    if (timeStr != null) {
      try {
        _lastSyncTime = DateTime.parse(timeStr);
      } catch (_) {}
    }
  }

  Future<void> clearUserData() async {
    _syncQueue.clear();
    _pendingCount = 0;
    _lastSyncTime = null;
    _currentUserId = null;
    _cloudEnabled = false;
    await _prefs?.remove(_syncQueueKey);
    await _prefs?.remove(_lastSyncKey);
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}
