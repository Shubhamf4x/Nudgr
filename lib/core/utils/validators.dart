class InputValidators {
  InputValidators._();

  static const int maxNoteTitleLength = 200;
  static const int maxNoteContentLength = 100000;
  static const int maxTaskTitleLength = 500;
  static const int maxTaskDescriptionLength = 5000;
  static const int maxUsernameLength = 32;
  static const int minUsernameLength = 3;
  static const int maxDisplayNameLength = 100;
  static const int maxBioLength = 500;

  static final _usernameAllowed = RegExp(r'^[a-z0-9._-]+$');

  static String clampLength(String value, int maxLength) =>
      value.length <= maxLength ? value : value.substring(0, maxLength);

  static String sanitizeUsername(String raw) {
    final cleaned = raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9._-]'), '');
    return clampLength(cleaned, maxUsernameLength);
  }

  static bool isValidUsername(String username) {
    if (username.length < minUsernameLength) return false;
    if (username.length > maxUsernameLength) return false;
    return _usernameAllowed.hasMatch(username);
  }

  static String? validateUsername(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return null;
    if (v.length < minUsernameLength) {
      return 'Username must be at least $minUsernameLength characters';
    }
    if (v.length > maxUsernameLength) {
      return 'Username must be at most $maxUsernameLength characters';
    }
    if (!isValidUsername(sanitizeUsername(v)) || sanitizeUsername(v) != v.toLowerCase()) {
      return 'Only letters, numbers, dots, dashes and underscores are allowed';
    }
    return null;
  }

  static String? validateEmail(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Please enter your email';
    if (v.length > 320) return 'Email is too long';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Please enter a password';
    if (v.length < 6) return 'Password must be at least 6 characters';
    if (v.length > 128) return 'Password must be at most 128 characters';
    return null;
  }
}
