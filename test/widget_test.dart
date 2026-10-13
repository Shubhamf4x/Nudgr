import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nudgr/core/services/auth_service.dart';
import 'package:nudgr/features/calendar/calendar_provider.dart';
import 'package:nudgr/shared/models/task_model.dart';
import 'package:nudgr/core/services/database_service.dart';
import 'package:nudgr/core/utils/validators.dart';
import 'package:nudgr/shared/models/note_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('InputValidators.sanitizeUsername', () {
    test('lowercases and strips disallowed characters', () {
      expect(InputValidators.sanitizeUsername('  Alex Doe! '), 'alexdoe');
    });

    test('keeps allowed separators', () {
      expect(InputValidators.sanitizeUsername('A_B.C-D'), 'a_b.c-d');
    });

    test('caps length at 32 characters', () {
      expect(
        InputValidators.sanitizeUsername('a' * 50).length,
        InputValidators.maxUsernameLength,
      );
    });
  });

  group('InputValidators.isValidUsername', () {
    test('accepts valid usernames', () {
      expect(InputValidators.isValidUsername('alex'), isTrue);
      expect(InputValidators.isValidUsername('a.b_c-d'), isTrue);
    });

    test('rejects too short / too long / invalid charset', () {
      expect(InputValidators.isValidUsername('ab'), isFalse);
      expect(InputValidators.isValidUsername('a' * 33), isFalse);
      expect(InputValidators.isValidUsername('has space'), isFalse);
      expect(InputValidators.isValidUsername('bad!name'), isFalse);
    });
  });

  group('InputValidators.validateEmail', () {
    test('accepts valid email', () {
      expect(InputValidators.validateEmail('user@example.com'), isNull);
    });

    test('rejects malformed email', () {
      expect(InputValidators.validateEmail('not-an-email'), isNotNull);
      expect(InputValidators.validateEmail(''), isNotNull);
    });
  });

  group('InputValidators.validatePassword', () {
    test('requires at least 6 characters', () {
      expect(InputValidators.validatePassword('12345'), isNotNull);
      expect(InputValidators.validatePassword('123456'), isNull);
    });
  });

  group('InputValidators.clampLength', () {
    test('clamps oversized note title to the enforced limit', () {
      final clamped = InputValidators.clampLength(
        'x' * 500,
        InputValidators.maxNoteTitleLength,
      );
      expect(clamped.length, InputValidators.maxNoteTitleLength);
    });
  });

  group('AuthService session restore', () {
    test('restores the stored session on app restart', () async {
      SharedPreferences.setMockInitialValues({
        'auth_version': '2.0',
        'current_user': jsonEncode({
          'id': 'uid-restore-1',
          'email': 'a@example.com',
          'displayName': 'Restore User',
          'username': 'restoreuser',
          'photoUrl': null,
          'bio': null,
          'isOnline': true,
          'lastSeen': '2026-08-30T10:00:00.000',
          'createdAt': '2026-08-30T09:00:00.000',
          'updatedAt': '2026-08-30T10:00:00.000',
          'preferences': <String, dynamic>{},
          'statistics': <String, dynamic>{},
          'isGoogleAccount': false,
        }),
      });

      final auth = AuthService.getInstance();
      await auth.initialize();

      expect(auth.isAuthenticated, isTrue);
      expect(auth.currentUser!.id, 'uid-restore-1');
    });

    test(
      'malformed stored session still restores instead of forcing login',
      () async {
        SharedPreferences.setMockInitialValues({
          'auth_version': '2.0',
          'current_user': '{"id":"uid-2","email":"b@example.com","displayName":"User B","lastSeen":null,"createdAt":null,"updatedAt":null,"preferences":null,"statistics":null}',
        });

        final auth = AuthService.getInstance();
        await auth.initialize();

        expect(auth.isAuthenticated, isTrue);
        expect(auth.currentUser!.displayName, 'User B');
      },
    );

    test(
      'no session and no local accounts leaves the user unauthenticated',
      () async {
        SharedPreferences.setMockInitialValues({'auth_version': '2.0'});

        final auth = AuthService.getInstance();
        await auth.initialize();

        expect(auth.isAuthenticated, isFalse);
      },
    );

    test('explicit logout keeps the user logged out across restarts', () async {
      SharedPreferences.setMockInitialValues({
        'auth_version': '2.0',
        'session_ended': true,
        'registered_users': jsonEncode([
          {
            'id': 'uid-old',
            'email': 'old@example.com',
            'displayName': 'Old User',
            'lastSeen': '2026-08-30T10:00:00.000',
            'createdAt': '2026-08-30T09:00:00.000',
            'updatedAt': '2026-08-30T10:00:00.000',
          },
        ]),
      });

      final auth = AuthService.getInstance();
      await auth.initialize();

      expect(auth.isAuthenticated, isFalse);
    });

    test(
      'last active local account is restored when storage session is gone',
      () async {
        SharedPreferences.setMockInitialValues({
          'auth_version': '2.0',
          'registered_users': jsonEncode([
            {
              'id': 'uid-a',
              'email': 'a@example.com',
              'displayName': 'User A',
              'lastSeen': '2026-08-29T10:00:00.000',
              'createdAt': '2026-08-29T09:00:00.000',
              'updatedAt': '2026-08-29T10:00:00.000',
            },
            {
              'id': 'uid-b',
              'email': 'b@example.com',
              'displayName': 'User B',
              'lastSeen': '2026-08-30T18:00:00.000',
              'createdAt': '2026-08-30T09:00:00.000',
              'updatedAt': '2026-08-30T18:00:00.000',
            },
          ]),
        });

        final auth = AuthService.getInstance();
        await auth.initialize();

        expect(auth.isAuthenticated, isTrue);
        expect(auth.currentUser!.id, 'uid-b');
      },
    );
  });

  group('DatabaseService tolerant decoding', () {
    test(
      'skips corrupt records instead of losing the whole collection',
      () async {
        final good = jsonEncode({
          'id': 'task-1',
          'title': 'Valid task',
          'userId': 'uid-1',
          'createdAt': '2026-08-30T10:00:00.000',
          'updatedAt': '2026-08-30T10:00:00.000',
        });
        SharedPreferences.setMockInitialValues({
          'tasks': '[$good, {"id": null}, 42, "broken"]',
        });

        final db = DatabaseService.getInstance();
        await db.initialize();

        final tasks = db.getTasks();
        expect(tasks.length, 1);
        expect(tasks.first.id, 'task-1');
      },
    );

    test('returns an empty list when the stored value is not JSON', () async {
      SharedPreferences.setMockInitialValues({'notes': 'not-json-at-all'});

      final db = DatabaseService.getInstance();
      await db.initialize();

      expect(db.getNotes(), isEmpty);
    });

    test('saving still works after a corrupt entry exists', () async {
      SharedPreferences.setMockInitialValues({'notes': '["garbage"]'});

      final db = DatabaseService.getInstance();
      await db.initialize();

      await db.saveNote(
        NoteModel(
          id: 'note-1',
          title: 'Recovered',
          content: 'body',
          userId: 'uid-1',
          createdAt: DateTime(2026, 8, 30),
          updatedAt: DateTime(2026, 8, 30),
        ),
      );

      final notes = db.getNotes();
      expect(notes.length, 1);
      expect(notes.first.id, 'note-1');
    });

    test('data owner marker can be cleared on logout', () async {
      SharedPreferences.setMockInitialValues({});

      final db = DatabaseService.getInstance();
      await db.initialize();

      await db.setDataOwnerUid('uid-1');
      expect(db.getDataOwnerUid(), 'uid-1');

      await db.clearDataOwner();
      expect(db.getDataOwnerUid(), isNull);
    });
  });

  group('CalendarState grouping', () {
    test('groups tasks by due date and finds the selected day', () {
      final state = CalendarState(
        selectedDate: DateTime(2026, 8, 30),
        focusedDate: DateTime(2026, 8, 30),
        isLoading: false,
        tasks: [
          TaskModel(
            id: 't1',
            title: 'Due today',
            userId: 'uid-1',
            dueDate: DateTime(2026, 8, 30, 9),
            createdAt: DateTime(2026, 8, 1),
            updatedAt: DateTime(2026, 8, 1),
          ),
          TaskModel(
            id: 't2',
            title: 'Due today later',
            userId: 'uid-1',
            dueDate: DateTime(2026, 8, 30, 18),
            createdAt: DateTime(2026, 8, 1),
            updatedAt: DateTime(2026, 8, 1),
          ),
          TaskModel(
            id: 't3',
            title: 'Tomorrow',
            userId: 'uid-1',
            dueDate: DateTime(2026, 8, 31),
            createdAt: DateTime(2026, 8, 1),
            updatedAt: DateTime(2026, 8, 1),
          ),
          TaskModel(
            id: 't4',
            title: 'No due date',
            userId: 'uid-1',
            createdAt: DateTime(2026, 8, 1),
            updatedAt: DateTime(2026, 8, 1),
          ),
        ],
      );

      expect(state.tasksForSelectedDate.length, 2);
      expect(state.tasksByDate[DateTime(2026, 8, 31)]!.single.id, 't3');
      expect(state.tasksByDate.values.expand((e) => e).length, 3);
    });
  });
}
