import 'package:meta/meta.dart';

/// Whether AI features can run right now.
///
/// The UI must tell [offline] apart from [unavailable]: when the user is
/// online but the API refuses us (e.g. RPR AI routes don't accept a bearer
/// token), show the `aiUnavailable*` state, never "you're offline".
enum AiAvailability { available, offline, unavailable }

/// Why an AI call could not run.
enum AiUnavailableReason {
  /// No connection. Requests may be queued and retried on reconnect.
  offline,

  /// Build has no Supabase / API config.
  notConfigured,

  /// Signed out or the session expired.
  signedOut,

  /// The API rejected our credentials (401/403 with a valid session).
  rejected,
}

/// Result of an [AiService] call. Exhaustive `switch` over the three cases.
@immutable
sealed class AiResult<T> {
  const AiResult();
}

final class AiSuccess<T> extends AiResult<T> {
  const AiSuccess(this.value);
  final T value;

  @override
  bool operator ==(Object other) =>
      other is AiSuccess<T> && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// AI cannot run at all for [reason] (maps to `AiOfflineState` variants).
final class AiUnavailable<T> extends AiResult<T> {
  const AiUnavailable(this.reason);
  final AiUnavailableReason reason;

  @override
  bool operator ==(Object other) =>
      other is AiUnavailable<T> && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;
}

/// The call ran and failed (5xx, timeout, bad output). [retryable] drives
/// the Retry button.
final class AiFailure<T> extends AiResult<T> {
  const AiFailure(this.message, {this.retryable = true, this.statusCode});
  final String message;
  final bool retryable;
  final int? statusCode;

  @override
  bool operator ==(Object other) =>
      other is AiFailure<T> &&
      other.message == message &&
      other.retryable == retryable &&
      other.statusCode == statusCode;

  @override
  int get hashCode => Object.hash(message, retryable, statusCode);
}
