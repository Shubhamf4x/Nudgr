import 'package:flutter_test/flutter_test.dart';
import 'package:nudgr/core/utils/validators.dart';

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
}
