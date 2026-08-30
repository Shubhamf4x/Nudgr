class AppException implements Exception {
  final String message;
  final String? code;
  const AppException({required this.message, this.code});
  @override
  String toString() => 'AppException: $message';
}

class AuthException extends AppException {
  const AuthException({required super.message, super.code});
}

class DatabaseException extends AppException {
  const DatabaseException({required super.message, super.code});
}

class NetworkException extends AppException {
  const NetworkException({required super.message, super.code});
}

class ValidationException extends AppException {
  const ValidationException({required super.message, super.code});
}
