import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nudgr/core/services/database_service.dart';
import 'package:nudgr/core/services/notification_service.dart';
import 'package:nudgr/features/chat/models/chat_identity.dart';
import 'package:nudgr/features/chat/services/mesh_protocol.dart';
import 'package:nudgr/features/notes/notes_provider.dart';
import 'package:nudgr/features/steps/steps_provider.dart';
import 'package:nudgr/features/tasks/tasks_provider.dart';
import 'package:nudgr/shared/models/note_model.dart';
import 'package:nudgr/shared/models/task_model.dart';
import 'package:nudgr/shared/providers/theme_provider.dart';

void main() {
  group(
    'MeshProtocol packet round trip (was: writer and parser disagreed)',
    () {
      const sender = 'a1b2c3d4';
      const recipient = 'deadbeef';
      test(
        'a framed packet survives encode -> decode with every field intact',
        () {
          final payload = MeshProtocol.createMessagePayload('hello mesh');
          final packet = MeshProtocol.createPacket(
            type: MeshProtocol.PACKET_TYPE_CHANNEL,
            senderId: sender,
            recipientId: recipient,
            payload: payload,
            ttl: 4,
            hopCount: 2,
          );
          final parsed = MeshProtocol.parsePacket(packet);
          expect(parsed, isNotNull);
          expect(parsed!['type'], MeshProtocol.PACKET_TYPE_CHANNEL);
          expect(parsed['ttl'], 4);
          expect(parsed['hopCount'], 2);
          expect(parsed['senderId'], sender);
          expect(parsed['recipientId'], recipient);
          expect(
            parsed['messageId'],
            hasLength(MeshProtocol.messageIdHexLength),
          );
          expect(
            MeshProtocol.parseMessagePayload(parsed['payload'] as Uint8List),
            'hello mesh',
          );
        },
      );
      test('HEADER_SIZE matches the number of bytes actually written', () {
        final packet = MeshProtocol.createPacket(
          type: MeshProtocol.PACKET_TYPE_CHANNEL,
          senderId: sender,
          payload: Uint8List(0),
        );
        expect(packet.length, MeshProtocol.HEADER_SIZE);
      });
      test('a broadcast packet (no recipient) decodes recipientId as null', () {
        final packet = MeshProtocol.createPacket(
          type: MeshProtocol.PACKET_TYPE_CHANNEL,
          senderId: sender,
          payload: MeshProtocol.createMessagePayload('broadcast'),
        );
        final parsed = MeshProtocol.parsePacket(packet)!;
        expect(parsed['recipientId'], isNull);
      });
      test('an explicitly supplied messageId is preserved (relay path)', () {
        final first = MeshProtocol.createPacket(
          type: MeshProtocol.PACKET_TYPE_CHANNEL,
          senderId: sender,
          payload: MeshProtocol.createMessagePayload('relayed'),
        );
        final originalId =
            MeshProtocol.parsePacket(first)!['messageId'] as String;
        final relay = MeshProtocol.createPacket(
          type: MeshProtocol.PACKET_TYPE_CHANNEL,
          senderId: sender,
          payload: MeshProtocol.createMessagePayload('relayed'),
          messageId: originalId,
          hopCount: 3,
        );
        final parsedRelay = MeshProtocol.parsePacket(relay)!;
        expect(parsedRelay['messageId'], originalId);
        expect(parsedRelay['hopCount'], 3);
        expect(relay.length, first.length);
      });
      test('peer ids are normalised so the self-filter can match', () {
        final packet = MeshProtocol.createPacket(
          type: MeshProtocol.PACKET_TYPE_CHANNEL,
          senderId: sender.toUpperCase(),
          payload: MeshProtocol.createMessagePayload('x'),
        );
        final parsed = MeshProtocol.parsePacket(packet)!;
        expect(parsed['senderId'], sender);
        expect(MeshProtocol.normalizePeerId(sender.toUpperCase()), sender);
      });
    },
  );
  group('MeshProtocol hostile input (was: remote RangeError / DoS)', () {
    test('a short packet is rejected instead of throwing', () {
      expect(MeshProtocol.parsePacket(Uint8List(0)), isNull);
      expect(MeshProtocol.parsePacket(Uint8List(12)), isNull);
      expect(
        MeshProtocol.parsePacket(Uint8List(MeshProtocol.HEADER_SIZE - 1)),
        isNull,
      );
    });
    test(
      'a packet declaring a payload longer than it contains is rejected',
      () {
        final packet = MeshProtocol.createPacket(
          type: MeshProtocol.PACKET_TYPE_CHANNEL,
          senderId: 'a1b2c3d4',
          payload: MeshProtocol.createMessagePayload('hi'),
        );
        final lying = Uint8List.fromList(packet);
        lying[2] = 0xFF;
        lying[3] = 0xFF;
        expect(MeshProtocol.parsePacket(lying), isNull);
      },
    );
    test('a payload larger than the mesh limit cannot be constructed', () {
      expect(
        () => MeshProtocol.createPacket(
          type: MeshProtocol.PACKET_TYPE_CHANNEL,
          senderId: 'a1b2c3d4',
          payload: Uint8List(MeshProtocol.MAX_PAYLOAD_SIZE + 1),
        ),
        throwsArgumentError,
      );
    });
    test('malformed ids and channels are rejected, not silently mangled', () {
      expect(
        () => MeshProtocol.createPacket(
          type: MeshProtocol.PACKET_TYPE_CHANNEL,
          senderId: 'not-hex!!',
          payload: Uint8List(0),
        ),
        throwsArgumentError,
      );
      expect(
        () => MeshProtocol.createPacket(
          type: MeshProtocol.PACKET_TYPE_CHANNEL,
          senderId: 'a1b2c3d4',
          recipientId: 'abc',
          payload: Uint8List(0),
        ),
        throwsArgumentError,
      );
      expect(
        () => MeshProtocol.createChannelMessagePayload('', 'body'),
        throwsArgumentError,
      );
      expect(
        () => MeshProtocol.createChannelMessagePayload('c' * 100, 'body'),
        throwsArgumentError,
      );
    });
    test(
      'truncated / empty channel payloads return null instead of throwing',
      () {
        expect(MeshProtocol.parseChannelMessagePayload(Uint8List(0)), isNull);
        expect(MeshProtocol.parseChannelMessagePayload(Uint8List(1)), isNull);
        expect(
          MeshProtocol.parseChannelMessagePayload(
            Uint8List.fromList([9, 0x6e, 0x65]),
          ),
          isNull,
        );
      },
    );
    test('truncated discovery payloads return null instead of throwing', () {
      expect(MeshProtocol.parseDiscoveryPayload(Uint8List(0)), isNull);
      expect(MeshProtocol.parseDiscoveryPayload(Uint8List(3)), isNull);
    });
  });
  group('MeshProtocol text handling (was: UTF-16 truncation)', () {
    test('non-Latin-1 text survives a channel message round trip', () {
      const content = 'नमस्ते — 中文 🎉';
      final payload = MeshProtocol.createChannelMessagePayload(
        'nearby',
        content,
      );
      final decoded = MeshProtocol.parseChannelMessagePayload(payload);
      expect(decoded, isNotNull);
      expect(decoded!.channelName, 'nearby');
      expect(decoded.content, content);
    });
    test('non-Latin-1 text survives a private message round trip', () {
      const content = 'ünïcödé 中';
      final payload = MeshProtocol.createMessagePayload(content);
      expect(MeshProtocol.parseMessagePayload(payload), content);
    });
    test('the byte length prefix counts UTF-8 bytes, not code units', () {
      final payload = MeshProtocol.createMessagePayload('中');
      final declared = (payload[0] << 8) | payload[1];
      expect(declared, 3);
      expect(payload.length, 5);
    });
    test('a nickname longer than the limit is truncated on a character '
        'boundary', () {
      final payload = MeshProtocol.createDiscoveryPayload('a1b2c3d4', 'ü' * 40);
      final decoded = MeshProtocol.parseDiscoveryPayload(payload)!;
      expect(decoded.nickname, isNotNull);
      expect(
        utf8.encode(decoded.nickname!).length,
        lessThanOrEqualTo(MeshProtocol.maxNicknameLength),
      );
      expect(decoded.nickname, 'ü' * 16);
    });
    test('a message id is random, full width, and collision resistant', () {
      final ids = {
        for (var i = 0; i < 500; i++) MeshProtocol.generateMessageId(),
      };
      expect(ids, hasLength(500));
      for (final id in ids) {
        expect(id, hasLength(MeshProtocol.messageIdHexLength));
        expect(MeshProtocol.isValidMessageId(id), isTrue);
      }
    });
  });
  group('ChatIdentity persistence (was: crash / corrupt identity)', () {
    test('an uppercase stored peerId is normalised to lowercase', () {
      final json = {
        'privateKey': base64Encode(List<int>.filled(32, 7)),
        'publicKey': base64Encode(List<int>.filled(32, 9)),
        'peerId': 'A1B2C3D4',
        'nickname': '  Alex  ',
      };
      final identity = ChatIdentity.fromJson(json);
      expect(identity.peerId, 'a1b2c3d4');
      expect(identity.nickname, 'Alex');
      expect(MeshProtocol.isValidPeerId(identity.peerId), isTrue);
    });
    test('an unusable stored key regenerates a usable identity', () {
      final identity = ChatIdentity.fromJson({
        'privateKey': 'not base64 at all',
        'publicKey': 'short',
        'peerId': 'zzzz',
      });
      expect(MeshProtocol.isValidPeerId(identity.peerId), isTrue);
      expect(identity.privateKey, hasLength(32));
      expect(identity.publicKey, hasLength(32));
    });
    test('sign/verify binds the payload to the signing key', () {
      final identity = ChatIdentity.generate();
      final other = ChatIdentity.generate();
      final payload = Uint8List.fromList([1, 2, 3]);
      final signature = identity.sign(payload);
      expect(signature, hasLength(32));
      expect(identity.verify(payload, signature), isTrue);
      expect(other.verify(payload, signature), isFalse);
      expect(
        identity.verify(Uint8List.fromList([1, 2, 4]), signature),
        isFalse,
      );
    });
  });
  group('TaskModel.completedAt (was: could never be cleared)', () {
    final base = TaskModel(
      id: 't1',
      title: 'Ship it',
      userId: 'uid-1',
      createdAt: DateTime(2026, 8, 1),
      updatedAt: DateTime(2026, 8, 1),
    );
    test('un-completing a task clears completedAt', () {
      final completed = base.copyWith(
        isCompleted: true,
        completedAt: DateTime(2026, 8, 2),
      );
      expect(completed.completedAt, isNotNull);
      final reopened = completed.copyWith(
        isCompleted: false,
        clearCompletedAt: true,
      );
      expect(reopened.completedAt, isNull);
      expect(reopened.isCompleted, isFalse);
    });
    test('an unrelated edit preserves completedAt', () {
      final completed = base.copyWith(
        isCompleted: true,
        completedAt: DateTime(2026, 8, 2),
      );
      final renamed = completed.copyWith(title: 'Renamed');
      expect(renamed.completedAt, completed.completedAt);
    });
  });
  group('TasksState filters (was: filters reset on every keystroke)', () {
    test('updating the search query keeps the selected category', () {
      const state = TasksState();
      final filtered = state.copyWith(selectedCategoryId: 'work');
      final searched = filtered.copyWith(searchQuery: 'report');
      expect(searched.selectedCategoryId, 'work');
      expect(searched.searchQuery, 'report');
    });
    test('the category filter can still be cleared explicitly', () {
      const state = TasksState();
      final filtered = state.copyWith(selectedCategoryId: 'work');
      final cleared = filtered.copyWith(clearCategory: true);
      expect(cleared.selectedCategoryId, isNull);
    });
    test('clearing a filter does not disturb the other filters', () {
      const state = TasksState();
      final filtered = state.copyWith(
        selectedCategoryId: 'work',
        selectedPriority: 'high',
      );
      final cleared = filtered.copyWith(clearCategory: true);
      expect(cleared.selectedCategoryId, isNull);
      expect(cleared.selectedPriority, 'high');
    });
  });
  group('NotesState filters (was: category filter could not be cleared)', () {
    test('selecting a category then clearing it shows all notes again', () {
      const state = NotesState();
      final filtered = state.copyWith(selectedCategoryId: 'work');
      final cleared = filtered.copyWith(clearCategory: true);
      expect(cleared.selectedCategoryId, isNull);
    });
    test('an unrelated update keeps the selected category', () {
      const state = NotesState();
      final filtered = state.copyWith(selectedCategoryId: 'work');
      final sameCategory = filtered.copyWith();
      expect(sameCategory.selectedCategoryId, 'work');
    });
    test('filteredNotes honours the category selection', () {
      final state = NotesState(
        notes: [
          NoteModel(
            id: 'n1',
            title: 'Work note',
            content: 'a',
            categoryId: 'work',
            userId: 'uid-1',
            createdAt: DateTime(2026, 8, 1),
            updatedAt: DateTime(2026, 8, 1),
          ),
          NoteModel(
            id: 'n2',
            title: 'Personal note',
            content: 'b',
            categoryId: 'personal',
            userId: 'uid-1',
            createdAt: DateTime(2026, 8, 2),
            updatedAt: DateTime(2026, 8, 2),
          ),
        ],
      );
      expect(
        state.copyWith(selectedCategoryId: 'work').filteredNotes.length,
        1,
      );
      expect(state.copyWith(clearCategory: true).filteredNotes.length, 2);
    });
  });
  group(
    'ThemeProvider stored index (was: RangeError during provider create)',
    () {
      test('an out-of-range stored theme index falls back to dark', () async {
        SharedPreferences.setMockInitialValues({'app_theme': 99});
        final provider = ThemeProvider();
        await Future<void>.delayed(Duration.zero);
        expect(provider.themeType, AppThemeType.dark);
      });
      test('a negative stored theme index falls back to dark', () async {
        SharedPreferences.setMockInitialValues({'app_theme': -3});
        final provider = ThemeProvider();
        await Future<void>.delayed(Duration.zero);
        expect(provider.themeType, AppThemeType.dark);
      });
      test('a valid stored theme index is still honoured', () async {
        SharedPreferences.setMockInitialValues({
          'app_theme': AppThemeType.ocean.index,
        });
        final provider = ThemeProvider();
        await Future<void>.delayed(Duration.zero);
        expect(provider.themeType, AppThemeType.ocean);
      });
    },
  );
  group('NotificationService stored list (was: unhandled decode error that '
      'left the app on the splash screen)', () {
    test('a corrupt notifications value does not break startup', () async {
      SharedPreferences.setMockInitialValues({'notifications': 'not-json'});
      final service = NotificationService.getInstance();
      await service.initialize();
      expect(service.notifications, isEmpty);
    });
    test('a notifications value of the wrong JSON shape is ignored', () async {
      SharedPreferences.setMockInitialValues({'notifications': '{"a":1}'});
      final service = NotificationService.getInstance();
      await service.initialize();
      expect(service.notifications, isEmpty);
    });
    test('valid entries survive while corrupt siblings are skipped', () async {
      SharedPreferences.setMockInitialValues({
        'notifications': jsonEncode([
          {
            'id': 'n1',
            'title': 'Due',
            'body': 'Task due',
            'type': 'task_due',
            'isRead': false,
            'createdAt': '2026-08-30T10:00:00.000',
          },
          {'id': 'n2'},
          42,
          'garbage',
        ]),
      });
      final service = NotificationService.getInstance();
      await service.initialize();
      expect(service.notifications, hasLength(1));
      expect(service.notifications.single.id, 'n1');
      expect(service.unreadCount, 1);
    });
    test(
      'initialize() completes even when the plugin is unavailable',
      () async {
        SharedPreferences.setMockInitialValues({'notifications': 'not-json'});
        await expectLater(
          NotificationService.getInstance().initialize(),
          completes,
        );
      },
    );
  });
  group(
    'StepsProvider sensor arithmetic (was: a counter reset froze the day and '
    'dropped every later step)',
    () {
      test('a normal reading is the delta against the persisted baseline', () {
        final r = StepsProvider.resolveSensorReading(
          sensorValue: 5200,
          previousBaseline: 5000,
          previousSensorValue: 5100,
          previousStepCount: 200,
        );
        expect(r.steps, 200);
        expect(r.baseline, 5000);
      });
      test('steps keep accumulating as the counter climbs', () {
        final r = StepsProvider.resolveSensorReading(
          sensorValue: 5800,
          previousBaseline: 5000,
          previousSensorValue: 5200,
          previousStepCount: 200,
        );
        expect(r.steps, 800);
      });
      test('a counter reset preserves the steps already banked', () {
        final reset = StepsProvider.resolveSensorReading(
          sensorValue: 5,
          previousBaseline: 5000,
          previousSensorValue: 5000,
          previousStepCount: 5000,
        );
        expect(reset.steps, 5000);
        expect(reset.baseline, 5);
      });
      test('steps recorded after a reset are added, not discarded', () {
        final before = StepsProvider.resolveSensorReading(
          sensorValue: 5,
          previousBaseline: 5000,
          previousSensorValue: 5000,
          previousStepCount: 5000,
        );
        final after = StepsProvider.resolveSensorReading(
          sensorValue: 305,
          previousBaseline: before.baseline,
          previousSensorValue: 5,
          previousStepCount: before.steps,
          baseOffset: before.offset,
        );
        expect(after.steps, 5300);
        expect(after.baseline, 5);
        expect(after.offset, 5000);
      });
      test('a record without a usable anchor keeps the counted total', () {
        final r = StepsProvider.resolveSensorReading(
          sensorValue: 900,
          previousBaseline: 0,
          previousSensorValue: 0,
          previousStepCount: 400,
        );
        expect(r.steps, 400);
        expect(r.baseline, 900);
      });
    },
  );
  group(
    'DatabaseService corrupt records (was: silently erased on next save)',
    () {
      test(
        'an unreadable record is quarantined instead of destroyed',
        () async {
          SharedPreferences.setMockInitialValues({
            'notes':
                '[{"id":"note-1","title":"ok","content":"c",'
                '"userId":"uid-1","createdAt":"2026-08-30T10:00:00.000",'
                '"updatedAt":"2026-08-30T10:00:00.000"},{"id":"broken"}]',
          });
          final db = DatabaseService.getInstance();
          await db.initialize();
          expect(db.getNotes(), hasLength(1));
          expect(db.quarantinedRecordCount, 0);
          await db.saveNote(
            NoteModel(
              id: 'note-2',
              title: 'New',
              content: 'body',
              userId: 'uid-1',
              createdAt: DateTime(2026, 8, 31),
              updatedAt: DateTime(2026, 8, 31),
            ),
          );
          expect(db.quarantinedRecordCount, 1);
        },
      );
      test('a healthy collection leaves nothing quarantined', () async {
        final db = DatabaseService.getInstance();
        SharedPreferences.setMockInitialValues({});
        await db.initialize();
        await db.saveTasks([
          TaskModel(
            id: 't1',
            title: 'Fine',
            userId: 'uid-1',
            createdAt: DateTime(2026, 8, 30),
            updatedAt: DateTime(2026, 8, 30),
          ),
        ]);
        expect(db.getTasks(), hasLength(1));
        expect(db.quarantinedRecordCount, 0);
      });
    },
  );
}
