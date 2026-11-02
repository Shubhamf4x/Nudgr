import 'package:flutter_test/flutter_test.dart';
import 'package:nudgr/core/services/database_service.dart';
import 'package:nudgr/core/services/sync_service.dart';
import 'package:nudgr/shared/models/category_model.dart';
import 'package:nudgr/shared/models/focus_session_model.dart';
import 'package:nudgr/shared/models/note_model.dart';
import 'package:nudgr/shared/models/task_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

TaskModel task(
  String id, {
  bool isSynced = true,
  DateTime? updatedAt,
  bool isRecurring = false,
  String? recurrencePattern,
  DateTime? dueDate,
  List<SubTaskModel> subtasks = const [],
  DateTime? reminderTime,
}) {
  final at = updatedAt ?? DateTime(2026, 8, 29, 10);
  return TaskModel(
    id: id,
    title: 'Task $id',
    userId: 'uid-1',
    createdAt: at,
    updatedAt: at,
    isSynced: isSynced,
    isRecurring: isRecurring,
    recurrencePattern: recurrencePattern,
    dueDate: dueDate,
    subtasks: subtasks,
    reminderTime: reminderTime,
  );
}

NoteModel note(String id, {bool isSynced = true, DateTime? updatedAt}) {
  final at = updatedAt ?? DateTime(2026, 8, 29, 10);
  return NoteModel(
    id: id,
    title: 'Note $id',
    content: 'body',
    userId: 'uid-1',
    createdAt: at,
    updatedAt: at,
    isSynced: isSynced,
  );
}

void main() {
  group('SyncService conflict resolvers (was: private, untestable)', () {
    test('an unsynced local edit wins over a synced cloud copy', () {
      final local = task('t1', isSynced: false);
      final cloud = task('t1', isSynced: true, updatedAt: DateTime(2026, 9, 1));
      expect(SyncService.resolveConflictTask(local, cloud), same(local));
    });
    test('a synced local copy loses to an unsynced cloud copy', () {
      final local = task('t1', isSynced: true);
      final cloud = task('t1', isSynced: false, updatedAt: DateTime(2026, 8, 1));
      expect(SyncService.resolveConflictTask(local, cloud), same(cloud));
    });
    test('two synced copies resolve newest-first', () {
      final old = task('t1', updatedAt: DateTime(2026, 8, 1));
      final newer = task(
        't1',
        isSynced: false,
        updatedAt: DateTime(2026, 8, 2),
      );
      expect(
        SyncService.resolveConflictTask(old, newer),
        same(newer),
      );
    });
    test('the note resolver mirrors the task resolver', () {
      final local = note('n1', isSynced: false);
      final cloud = note('n1', isSynced: true, updatedAt: DateTime(2026, 9, 1));
      expect(SyncService.resolveConflictNote(local, cloud), same(local));
    });
    test('the category and focus resolvers mirror the task resolver', () {
      final now = DateTime(2026, 8, 29, 10);
      final localCat = CategoryModel(
        id: 'c1',
        name: 'Work',
        colorIndex: 0,
        userId: 'uid-1',
        createdAt: now,
        updatedAt: now,
        isSynced: false,
      );
      final cloudCat = localCat.copyWith(isSynced: true);
      expect(
        SyncService.resolveConflictCategory(localCat, cloudCat),
        same(localCat),
      );
      final localSession = FocusSessionModel(
        id: 'f1',
        userId: 'uid-1',
        durationMinutes: 25,
        startTime: now,
        createdAt: now,
        isSynced: false,
      );
      final cloudSession = localSession.copyWith(isSynced: true);
      expect(
        SyncService.resolveConflictFocusSession(localSession, cloudSession),
        same(localSession),
      );
    });
  });

  group(
    'TaskRecurrence.nextOccurrence (was: recurring tasks stayed completed '
    'forever)',
    () {
      test("a recurring daily task creates tomorrow's copy with a new id", () {
        final base = task(
          't1',
          isRecurring: true,
          recurrencePattern: 'daily',
          dueDate: DateTime(2026, 8, 29),
        );
        final next = base.nextOccurrence('t-next');
        expect(next, isNotNull);
        expect(next!.id, 't-next');
        expect(next.dueDate, DateTime(2026, 8, 30));
        expect(next.isCompleted, isFalse);
        expect(next.completedAt, isNull);
        expect(next.isRecurring, isTrue);
        expect(next.recurrencePattern, 'daily');
        expect(next.isSynced, isFalse);
      });
      test('a weekly task advances exactly one week', () {
        final base = task(
          't1',
          isRecurring: true,
          recurrencePattern: 'weekly',
          dueDate: DateTime(2026, 8, 26),
        );
        expect(base.nextOccurrence('t2')!.dueDate, DateTime(2026, 9, 2));
      });
      test('a monthly task clamps to the last short month day', () {
        final base = task(
          't1',
          isRecurring: true,
          recurrencePattern: 'monthly',
          dueDate: DateTime(2026, 1, 31),
        );
        expect(base.nextOccurrence('t2')!.dueDate, DateTime(2026, 2, 28));
      });
      test('the reminder shifts with the occurrence', () {
        final base = task(
          't1',
          isRecurring: true,
          recurrencePattern: 'weekly',
          dueDate: DateTime(2026, 8, 26),
          reminderTime: DateTime(2026, 8, 26, 8),
        );
        expect(
          base.nextOccurrence('t2')!.reminderTime,
          DateTime(2026, 9, 2, 8),
        );
      });
      test('subtasks are reset and given fresh ids', () {
        final base = task(
          't1',
          isRecurring: true,
          recurrencePattern: 'daily',
          dueDate: DateTime(2026, 8, 29),
          subtasks: [
            SubTaskModel(
              id: 's1',
              title: 'child',
              isCompleted: true,
              createdAt: DateTime(2026, 8, 28),
            ),
          ],
        );
        final next = base.nextOccurrence('t2')!;
        expect(next.subtasks, hasLength(1));
        expect(next.subtasks.first.isCompleted, isFalse);
        expect(next.subtasks.first.id, startsWith('s1_'));
      });
      test('non-recurring and unknown patterns produce nothing', () {
        expect(task('t1').nextOccurrence('t2'), isNull);
        final unknown = TaskModel(
          id: 't1',
          title: 't1',
          userId: 'uid-1',
          createdAt: DateTime(2026, 8, 29),
          updatedAt: DateTime(2026, 8, 29),
          isRecurring: true,
          recurrencePattern: 'fortnightly',
        );
        expect(unknown.nextOccurrence('t2'), isNull);
      });
    },
  );

  group('DatabaseService tombstones (was: deletes resurrected on pull)', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final db = DatabaseService.getInstance();
      await db.initialize();
      await db.clearAll();
    });

    test('addTombstone records a type/id pair with a timestamp', () async {
      final db = DatabaseService.getInstance();
      await db.addTombstone('tasks', 't1');
      final tombstones = db.getTombstones();
      expect(tombstones, hasLength(1));
      expect(tombstones.single['type'], 'tasks');
      expect(tombstones.single['id'], 't1');
      expect(DateTime.tryParse('${tombstones.single['at']}'), isNotNull);
    });

    test('records dedupe by type/id, keeping the newest timestamp', () async {
      final db = DatabaseService.getInstance();
      await db.addTombstones([
        {'id': 't1', 'type': 'tasks', 'at': '2026-01-01T00:00:00.000'},
      ]);
      await db.addTombstones([
        {'id': 't1', 'type': 'tasks', 'at': '2026-02-01T00:00:00.000'},
        {'id': 't1', 'type': 'tasks', 'at': '2025-06-01T00:00:00.000'},
        {'id': 'n1', 'type': 'notes', 'at': '2026-03-01T00:00:00.000'},
      ]);
      final tombstones = db.getTombstones();
      expect(tombstones, hasLength(2));
      final taskEntry = tombstones.firstWhere((t) => t['id'] == 't1');
      expect(taskEntry['at'], '2026-02-01T00:00:00.000');
    });

    test('malformed entries are ignored', () async {
      final db = DatabaseService.getInstance();
      await db.addTombstones([
        {'id': '', 'type': 'tasks'},
        {'id': 't1'},
        {'type': 'tasks'},
      ]);
      expect(db.getTombstones(), isEmpty);
    });

    test('removeTombstone drops exactly the requested pair', () async {
      final db = DatabaseService.getInstance();
      await db.addTombstone('tasks', 't1');
      await db.addTombstone('notes', 'n1');
      await db.removeTombstone('tasks', 't1');
      final tombstones = db.getTombstones();
      expect(tombstones, hasLength(1));
      expect(tombstones.single['type'], 'notes');
    });

    test('pruneTombstones keeps only entries newer than the cutoff',
        () async {
      final db = DatabaseService.getInstance();
      final now = DateTime.now();
      await db.addTombstones([
        {
          'id': 'fresh',
          'type': 'tasks',
          'at': now.subtract(const Duration(days: 10)).toIso8601String(),
        },
        {
          'id': 'stale',
          'type': 'tasks',
          'at': now.subtract(const Duration(days: 91)).toIso8601String(),
        },
      ]);
      await db.pruneTombstones(maxAgeDays: 90);
      final tombstones = db.getTombstones();
      expect(tombstones, hasLength(1));
      expect(tombstones.single['id'], 'fresh');
    });

    test('clearTombstones empties the list', () async {
      final db = DatabaseService.getInstance();
      await db.addTombstone('tasks', 't1');
      await db.clearTombstones();
      expect(db.getTombstones(), isEmpty);
    });
  });

  group('DatabaseService sync flags (was: uploaded edits stayed unsynced '
      'and re-uploaded forever)', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final db = DatabaseService.getInstance();
      await db.initialize();
      await db.clearAll();
    });

    test('markTaskSynced flips the flag for a known task', () async {
      final db = DatabaseService.getInstance();
      final unsynced = task('t1', isSynced: false);
      await db.saveTask(unsynced);
      expect(db.getTasks().single.isSynced, isFalse);
      await db.markTaskSynced('t1');
      expect(db.getTasks().single.isSynced, isTrue);
    });

    test('markTaskSynced ignores unknown ids', () async {
      final db = DatabaseService.getInstance();
      await db.markTaskSynced('missing');
      expect(db.getTasks(), isEmpty);
    });

    test('markNoteSynced / markCategorySynced / markFocusSessionSynced flip '
        'their flags', () async {
      final db = DatabaseService.getInstance();
      final now = DateTime(2026, 8, 29, 10);
      await db.saveNote(note('n1', isSynced: false));
      await db.saveCategory(
        CategoryModel(
          id: 'c1',
          name: 'Work',
          colorIndex: 0,
          userId: 'uid-1',
          createdAt: now,
          updatedAt: now,
          isSynced: false,
        ),
      );
      await db.saveFocusSession(
        FocusSessionModel(
          id: 'f1',
          userId: 'uid-1',
          durationMinutes: 25,
          startTime: now,
          createdAt: now,
          isSynced: false,
        ),
      );
      await db.markNoteSynced('n1');
      await db.markCategorySynced('c1');
      await db.markFocusSessionSynced('f1');
      expect(db.getNotes().single.isSynced, isTrue);
      expect(db.getCategories().single.isSynced, isTrue);
      expect(db.getFocusSessions().single.isSynced, isTrue);
    });
  });

  group('DatabaseService focus sessions (was: no delete API)', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final db = DatabaseService.getInstance();
      await db.initialize();
      await db.clearAll();
    });

    test('deleteFocusSession removes one session by id', () async {
      final db = DatabaseService.getInstance();
      final now = DateTime(2026, 8, 29, 10);
      await db.saveFocusSession(
        FocusSessionModel(
          id: 'f1',
          userId: 'uid-1',
          durationMinutes: 25,
          startTime: now,
          createdAt: now,
        ),
      );
      await db.saveFocusSession(
        FocusSessionModel(
          id: 'f2',
          userId: 'uid-1',
          durationMinutes: 5,
          startTime: now,
          createdAt: now,
        ),
      );
      await db.deleteFocusSession('f1');
      expect(
        db.getFocusSessions().map((s) => s.id),
        ['f2'],
      );
    });
  });
}
