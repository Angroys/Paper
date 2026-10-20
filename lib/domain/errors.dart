/// Typed failures thrown by repositories / services. UI maps each to an ARB
/// string; never show [Object.toString] to users.
sealed class PaperException implements Exception {
  const PaperException([this.message]);
  final String? message;

  @override
  String toString() => '$runtimeType${message == null ? '' : ': $message'}';
}

/// The build has no Supabase / API config (see lib/core/env.dart).
final class NotConfiguredException extends PaperException {
  const NotConfiguredException([super.message]);
}

/// No connection, or the request could not reach the server.
final class OfflineException extends PaperException {
  const OfflineException([super.message]);
}

/// The session expired or was revoked; the user must sign in again.
final class AuthExpiredException extends PaperException {
  const AuthExpiredException([super.message]);
}

/// Sign-in failed (bad credentials, cancelled, rate-limited...).
final class AuthFailedException extends PaperException {
  const AuthFailedException(this.reason, [super.message]);
  final AuthFailureReason reason;
}

enum AuthFailureReason {
  cancelled,
  invalidCredentials,
  emailNotConfirmed,
  rateLimited,
  exchangeFailed,
  unknown,
}

final class NotFoundException extends PaperException {
  const NotFoundException([super.message]);
}

/// Import rejected: not a PDF / unreadable.
final class InvalidPdfException extends PaperException {
  const InvalidPdfException([super.message]);
}

/// Import rejected: larger than [maxBytes] (`errorFileTooLarge {maxMb}`).
final class FileTooLargeException extends PaperException {
  const FileTooLargeException(this.maxBytes, [super.message]);
  final int maxBytes;
}

/// Local write failed (disk full, DB locked).
final class StorageException extends PaperException {
  const StorageException([super.message]);
}

/// The server answered with an unexpected status.
final class ServerException extends PaperException {
  const ServerException(this.statusCode, [super.message]);
  final int statusCode;
}
