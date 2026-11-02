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
  String? _lastSyncError;
  int _pendingCount = 0;
  bool _isSyncing = false;
  bool _isOnline = true;
  final int _maxRetries = 6;
  final List<Future<void> Function()> _pullListeners = [];
  static const int _maxQueueSize = 500;
  static const int _tombstoneMaxAgeDays = 90;
  static const String _syncQueueKey = 'sync_queue';
  static const String _lastSyncKey = 'last_sync_time';
  SyncService._();
  static SyncService getInstance() {
    _instance ??= SyncService._();
    return _instance!;
  }

  SyncStatus get status => _status;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get lastSyncError => _lastSyncError;
  int get pendingCount => _pendingCount;
  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  String? get currentUserId => _currentUserId;
  bool get cloudEnabled => _cloudEnabled;
  bool get _canSync => _cloudEnabled && _currentUserId != null && _isOnline;
  bool get _canQueue => _currentUserId != null;
  void addPullListener(Future<void> Function() listener) {
    _pullListeners.add(listener);
  }

  void removePullListener(Future<void> Function() listener) {
    _pullListeners.remove(listener);
  }

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _loadLastSyncTime();
    await _loadSyncQueue();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      results,
    ) {
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
      unawaited(syncPendingData());
    }
  }

  Future<void> pushPendingBeforeRestore() async {
    await syncPendingData();
  }

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
    if (!_canQueue) return;
    _enqueue(
      collection: collection,
      documentId: documentId,
      operation: operation,
      data: data,
    );
    if (_isOnline && !_isSyncing) {
      syncPendingData();
    }
  }

  void _enqueue({
    required String collection,
    required String documentId,
    required SyncOperation operation,
    Map<String, dynamic>? data,
  }) {
    _syncQueue.removeWhere(
      (q) => q.collection == collection && q.documentId == documentId,
    );
    _syncQueue.add(
      SyncQueueItem(
        id: '${collection}_${documentId}_${DateTime.now().microsecondsSinceEpoch}',
        collection: collection,
        documentId: documentId,
        operation: operation,
        data: data,
      ),
    );
    if (_syncQueue.length > _maxQueueSize) {
      _syncQueue.removeRange(0, _syncQueue.length - _maxQueueSize);
    }
    _pendingCount = _syncQueue.length;
    unawaited(_saveSyncQueue());
  }

  CollectionReference _userCollection(String collection) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUserId)
        .collection(collection);
  }

  Future<void> syncPendingData() async {
    if (_isSyncing || !_canSync) return;
    _isSyncing = true;
    _status = SyncStatus.syncing;
    try {
      final items = List<SyncQueueItem>.from(_syncQueue);
      final failedItems = <SyncQueueItem>[];
      var droppedCount = 0;
      for (final item in items) {
        try {
          await _processQueueItem(item);
          _syncQueue.removeWhere((q) => q.id == item.id);
          _lastSyncError = null;
        } catch (e) {
          _lastSyncError = _describeError(e);
          item.retryCount++;
          if (item.retryCount >= _maxRetries) {
            _syncQueue.removeWhere((q) => q.id == item.id);
            droppedCount++;
          } else {
            failedItems.add(item);
          }
        }
      }
      await _saveSyncQueue();
      if (droppedCount > 0) {
        _lastSyncError =
            '$droppedCount change(s) could not be saved to the cloud and were '
            'discarded. Your data is still on this device.';
        _status = SyncStatus.error;
      } else if (_syncQueue.isEmpty) {
        _lastSyncTime = DateTime.now();
        await _prefs!.setString(_lastSyncKey, _lastSyncTime!.toIso8601String());
        _status = SyncStatus.idle;
        if (failedItems.isEmpty) _lastSyncError = null;
      } else {
        _status = SyncStatus.error;
      }
    } catch (e) {
      _lastSyncError = _describeError(e);
      _status = SyncStatus.error;
    } finally {
      _isSyncing = false;
    }
  }

  String _describeError(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('permission-denied') ||
        text.contains('permission_denied')) {
      return 'Cloud storage rejected the write. Publish the Firestore security rules in the Firebase console.';
    }
    if (text.contains('failed-precondition') || text.contains('not-found')) {
      return 'Cloud Firestore is not created yet. Create it in the Firebase console to enable cloud sync.';
    }
    if (text.contains('unavailable') ||
        text.contains('deadline') ||
        text.contains('network')) {
      return 'Cloud storage is unreachable. Retrying when the connection improves.';
    }
    return 'Cloud sync error. Check your Firebase configuration.';
  }

  Map<String, dynamic> _withOwnership(
    String documentId,
    Map<String, dynamic> data,
  ) {
    final stamped = Map<String, dynamic>.from(data);
    stamped['id'] = documentId;
    final userId = _currentUserId;
    if (userId != null && userId.isNotEmpty) {
      stamped['userId'] = userId;
    } else {
      stamped.remove('userId');
    }
    return stamped;
  }

  Future<void> _markLocalSynced(String collection, String documentId) async {
    switch (collection) {
      case 'tasks':
        await _db.markTaskSynced(documentId);
        break;
      case 'notes':
        await _db.markNoteSynced(documentId);
        break;
      case 'categories':
        await _db.markCategorySynced(documentId);
        break;
      case 'focus_sessions':
        await _db.markFocusSessionSynced(documentId);
        break;
      default:
        break;
    }
  }

  Future<void> _processQueueItem(SyncQueueItem item) async {
    final ref = _userCollection(item.collection).doc(item.documentId);
    switch (item.operation) {
      case SyncOperation.create:
      case SyncOperation.update:
        if (item.data != null) {
          await ref.set(
            _withOwnership(item.documentId, item.data!),
            SetOptions(merge: true),
          );
          await _markLocalSynced(item.collection, item.documentId);
        }
        break;
      case SyncOperation.delete:
        await ref.delete();
        await _writeCloudTombstone(item.collection, item.documentId);
        break;
    }
  }

  Future<void> _writeCloudTombstone(String type, String id) async {
    if (_currentUserId == null) return;
    try {
      await _userCollection('tombstones')
          .doc('$type~$id')
          .set(
            _withOwnership(
              '$type~$id',
              {
                'type': type,
                'id': id,
                'at': DateTime.now().toIso8601String(),
              },
            ),
          );
    } catch (_) {
      final tombstones = _db.getTombstones();
      final missing = !tombstones.any(
        (t) => t['type'] == type && t['id'] == id,
      );
      if (missing) await _db.addTombstone(type, id);
      _enqueue(
        collection: 'tombstones',
        documentId: '$type~$id',
        operation: SyncOperation.update,
        data: {
          'type': type,
          'id': id,
          'at': DateTime.now().toIso8601String(),
        },
      );
    }
  }

  Set<String> _tombstonedIds(String type) {
    return _db
        .getTombstones()
        .where((t) => t['type'] == type)
        .map((t) => '${t['id']}')
        .toSet();
  }

  Future<void> _applyTombstonesToLocal() async {
    final tombstones = _db.getTombstones();
    var queueChanged = false;
    for (final tombstone in tombstones) {
      final type = tombstone['type'] as String?;
      final id = tombstone['id'] as String?;
      if (type == null || id == null) continue;
      try {
        switch (type) {
          case 'tasks':
            await _db.deleteTask(id);
            break;
          case 'notes':
            await _db.deleteNote(id);
            break;
          case 'categories':
            await _db.deleteCategory(id);
            break;
          case 'focus_sessions':
            await _db.deleteFocusSession(id);
            break;
          default:
            break;
        }
      } catch (_) {}
      final before = _syncQueue.length;
      _syncQueue.removeWhere(
        (q) => q.collection == type && q.documentId == id,
      );
      if (_syncQueue.length != before) queueChanged = true;
    }
    if (queueChanged) await _saveSyncQueue();
  }

  Future<void> pullFromCloud() async {
    if (_isSyncing || !_canSync) return;
    final userId = _currentUserId;
    _status = SyncStatus.syncing;
    _isSyncing = true;
    var anyFailure = false;
    try {
      for (final pull in [
        _pullTombstones,
        _pullTasks,
        _pullNotes,
        _pullCategories,
        _pullFocusSessions,
        _pullSteps,
        _pullUserProfile,
      ]) {
        if (_currentUserId != userId) break;
        try {
          await pull();
        } catch (e) {
          anyFailure = true;
          _lastSyncError = _describeError(e);
        }
      }
      if (_currentUserId != userId) {
        return;
      }
      if (!anyFailure) {
        _lastSyncTime = DateTime.now();
        await _prefs!.setString(_lastSyncKey, _lastSyncTime!.toIso8601String());
        _lastSyncError = null;
        _status = SyncStatus.idle;
      } else {
        _status = SyncStatus.error;
      }
      await _notifyPullListeners();
    } catch (e) {
      _lastSyncError = _describeError(e);
      _status = SyncStatus.error;
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _notifyPullListeners() async {
    if (_pullListeners.isEmpty) return;
    for (final listener in List<Future<void> Function()>.of(_pullListeners)) {
      try {
        await listener();
      } catch (_) {}
    }
  }

  Future<void> _pullTombstones() async {
    final snapshot = await _userCollection('tombstones').get();
    if (snapshot.docs.isEmpty) {
      await _applyTombstonesToLocal();
      await _db.pruneTombstones(maxAgeDays: _tombstoneMaxAgeDays);
      return;
    }
    final records = <Map<String, dynamic>>[];
    final staleDocIds = <String>[];
    final cutoff = DateTime.now().subtract(
      const Duration(days: _tombstoneMaxAgeDays),
    );
    for (final doc in snapshot.docs) {
      final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
      final type = data['type'] as String?;
      final id = data['id'] as String?;
      if (type == null || id == null || type.isEmpty || id.isEmpty) {
        staleDocIds.add(doc.id);
        continue;
      }
      if (data['at'] is! String) {
        data['at'] = DateTime.now().toIso8601String();
      }
      records.add(data);
      final at = DateTime.tryParse('${data['at']}');
      if (at == null || at.isBefore(cutoff)) staleDocIds.add(doc.id);
    }
    if (records.isNotEmpty) {
      await _db.addTombstones(records);
      await _applyTombstonesToLocal();
    }
    await _db.pruneTombstones(maxAgeDays: _tombstoneMaxAgeDays);
    for (final docId in staleDocIds) {
      try {
        await _userCollection('tombstones').doc(docId).delete();
      } catch (_) {}
    }
  }

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
    final tombstoned = _tombstonedIds('tasks');
    final cloudTasks = <TaskModel>[];
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final task = TaskModel.fromJson(data);
      if (tombstoned.contains(task.id)) continue;
      cloudTasks.add(task);
    }
    if (cloudTasks.isEmpty) return;
    final localTasks = _db.getTasks();
    final localMap = {for (final t in localTasks) t.id: t};
    final cloudMap = {for (final t in cloudTasks) t.id: t};
    final merged = <TaskModel>[];
    final needsUpload = <TaskModel>[];
    for (final cloudTask in cloudTasks) {
      final localTask = localMap[cloudTask.id];
      if (localTask == null) {
        merged.add(cloudTask);
      } else {
        final resolved = resolveConflictTask(localTask, cloudTask);
        merged.add(resolved);
        if (!resolved.isSynced) needsUpload.add(resolved);
      }
    }
    for (final localTask in localTasks) {
      if (cloudMap.containsKey(localTask.id)) continue;
      if (tombstoned.contains(localTask.id)) continue;
      merged.add(localTask);
      needsUpload.add(localTask);
    }
    await _db.saveTasks(merged);
    _queueForUpload(
      collection: 'tasks',
      records: needsUpload.map((t) => (t.id, t.toJson())),
    );
  }

  Future<void> _pullNotes() async {
    final snapshot = await _userCollection('notes').get();
    final tombstoned = _tombstonedIds('notes');
    final cloudNotes = <NoteModel>[];
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final note = NoteModel.fromJson(data);
      if (tombstoned.contains(note.id)) continue;
      cloudNotes.add(note);
    }
    if (cloudNotes.isEmpty) return;
    final localNotes = _db.getNotes();
    final localMap = {for (final n in localNotes) n.id: n};
    final cloudMap = {for (final n in cloudNotes) n.id: n};
    final merged = <NoteModel>[];
    final needsUpload = <NoteModel>[];
    for (final cloudNote in cloudNotes) {
      final localNote = localMap[cloudNote.id];
      if (localNote == null) {
        merged.add(cloudNote);
      } else {
        final resolved = resolveConflictNote(localNote, cloudNote);
        merged.add(resolved);
        if (!resolved.isSynced) needsUpload.add(resolved);
      }
    }
    for (final localNote in localNotes) {
      if (cloudMap.containsKey(localNote.id)) continue;
      if (tombstoned.contains(localNote.id)) continue;
      merged.add(localNote);
      needsUpload.add(localNote);
    }
    await _db.saveNotes(merged);
    _queueForUpload(
      collection: 'notes',
      records: needsUpload.map((n) => (n.id, n.toJson())),
    );
  }

  Future<void> _pullCategories() async {
    final snapshot = await _userCollection('categories').get();
    final tombstoned = _tombstonedIds('categories');
    final cloudCategories = <CategoryModel>[];
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final category = CategoryModel.fromJson(data);
      if (tombstoned.contains(category.id)) continue;
      cloudCategories.add(category);
    }
    if (cloudCategories.isEmpty) return;
    final localCategories = _db.getCategories();
    final localMap = {for (final c in localCategories) c.id: c};
    final cloudMap = {for (final c in cloudCategories) c.id: c};
    final merged = <CategoryModel>[];
    final needsUpload = <CategoryModel>[];
    for (final cloudCat in cloudCategories) {
      final localCat = localMap[cloudCat.id];
      if (localCat == null) {
        merged.add(cloudCat);
      } else {
        final resolved = resolveConflictCategory(localCat, cloudCat);
        merged.add(resolved);
        if (!resolved.isSynced) needsUpload.add(resolved);
      }
    }
    for (final localCat in localCategories) {
      if (cloudMap.containsKey(localCat.id)) continue;
      if (tombstoned.contains(localCat.id)) continue;
      merged.add(localCat);
      needsUpload.add(localCat);
    }
    await _db.saveCategories(merged);
    _queueForUpload(
      collection: 'categories',
      records: needsUpload.map((c) => (c.id, c.toJson())),
    );
  }

  Future<void> _pullFocusSessions() async {
    final snapshot = await _userCollection('focus_sessions').get();
    final tombstoned = _tombstonedIds('focus_sessions');
    final cloudSessions = <FocusSessionModel>[];
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final session = FocusSessionModel.fromJson(data);
      if (tombstoned.contains(session.id)) continue;
      cloudSessions.add(session);
    }
    if (cloudSessions.isEmpty) return;
    final localSessions = _db.getFocusSessions();
    final localMap = {for (final s in localSessions) s.id: s};
    final cloudMap = {for (final s in cloudSessions) s.id: s};
    final merged = <FocusSessionModel>[];
    final needsUpload = <FocusSessionModel>[];
    for (final cloudSession in cloudSessions) {
      final localSession = localMap[cloudSession.id];
      if (localSession == null) {
        merged.add(cloudSession);
      } else {
        final resolved = resolveConflictFocusSession(
          localSession,
          cloudSession,
        );
        merged.add(resolved);
        if (!resolved.isSynced) needsUpload.add(resolved);
      }
    }
    for (final localSession in localSessions) {
      if (cloudMap.containsKey(localSession.id)) continue;
      if (tombstoned.contains(localSession.id)) continue;
      merged.add(localSession);
      needsUpload.add(localSession);
    }
    await _db.saveFocusSessions(merged);
    _queueForUpload(
      collection: 'focus_sessions',
      records: needsUpload.map((s) => (s.id, s.toJson())),
    );
  }

  void _queueForUpload({
    required String collection,
    required Iterable<(String, Map<String, dynamic>)> records,
  }) {
    for (final (id, data) in records) {
      _enqueue(
        collection: collection,
        documentId: id,
        operation: SyncOperation.update,
        data: data,
      );
    }
  }

  static TaskModel resolveConflictTask(TaskModel local, TaskModel cloud) {
    if (!local.isSynced && cloud.isSynced) return local;
    if (local.isSynced && !cloud.isSynced) return cloud;
    return local.updatedAt.isAfter(cloud.updatedAt) ? local : cloud;
  }

  static NoteModel resolveConflictNote(NoteModel local, NoteModel cloud) {
    if (!local.isSynced && cloud.isSynced) return local;
    if (local.isSynced && !cloud.isSynced) return cloud;
    return local.updatedAt.isAfter(cloud.updatedAt) ? local : cloud;
  }

  static CategoryModel resolveConflictCategory(
    CategoryModel local,
    CategoryModel cloud,
  ) {
    if (!local.isSynced && cloud.isSynced) return local;
    if (local.isSynced && !cloud.isSynced) return cloud;
    return local.updatedAt.isAfter(cloud.updatedAt) ? local : cloud;
  }

  static FocusSessionModel resolveConflictFocusSession(
    FocusSessionModel local,
    FocusSessionModel cloud,
  ) {
    if (!local.isSynced && cloud.isSynced) return local;
    if (local.isSynced && !cloud.isSynced) return cloud;
    return local.updatedAt.isAfter(cloud.updatedAt) ? local : cloud;
  }

  Future<void> fullSync() async {
    if (!_canSync || _isSyncing) return;
    await syncPendingData();
    await pullFromCloud();
  }

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
    if (_tombstonedIds('tasks').contains(task.id)) return;
    try {
      await _userCollection('tasks')
          .doc(task.id)
          .set(_withOwnership(task.id, task.toJson()), SetOptions(merge: true));
      await _markLocalSynced('tasks', task.id);
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
    await _db.addTombstone('tasks', taskId);
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
      await _writeCloudTombstone('tasks', taskId);
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
    if (_tombstonedIds('notes').contains(note.id)) return;
    try {
      await _userCollection('notes')
          .doc(note.id)
          .set(_withOwnership(note.id, note.toJson()), SetOptions(merge: true));
      await _markLocalSynced('notes', note.id);
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
    await _db.addTombstone('notes', noteId);
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
      await _writeCloudTombstone('notes', noteId);
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
    if (_tombstonedIds('categories').contains(category.id)) return;
    try {
      await _userCollection('categories')
          .doc(category.id)
          .set(
            _withOwnership(category.id, category.toJson()),
            SetOptions(merge: true),
          );
      await _markLocalSynced('categories', category.id);
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
    await _db.addTombstone('categories', categoryId);
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
      await _writeCloudTombstone('categories', categoryId);
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
    if (_tombstonedIds('focus_sessions').contains(session.id)) return;
    try {
      await _userCollection('focus_sessions')
          .doc(session.id)
          .set(
            _withOwnership(session.id, session.toJson()),
            SetOptions(merge: true),
          );
      await _markLocalSynced('focus_sessions', session.id);
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
      await _userCollection('steps')
          .doc(date)
          .set(
            _withOwnership(date, {'date': date, 'stepCount': stepCount}),
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
          .set(
            _withOwnership(_currentUserId!, userData),
            SetOptions(merge: true),
          );
    } catch (_) {}
  }

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
    await _db.clearTombstones();
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}
