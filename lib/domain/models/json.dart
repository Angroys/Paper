// Small JSON helpers shared by the domain models. Pure Dart.

/// Parses an ISO-8601 timestamp; returns null for null/empty.
DateTime? parseDateOrNull(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value.toUtc();
  final s = value as String;
  if (s.isEmpty) return null;
  return DateTime.parse(s).toUtc();
}

/// Parses a required ISO-8601 timestamp.
DateTime parseDate(Object? value) => parseDateOrNull(value)!;

/// UTC ISO-8601 string, the format Postgres `timestamptz` round-trips.
String? dateToJson(DateTime? value) => value?.toUtc().toIso8601String();

double toDouble(Object? value) => (value as num).toDouble();

double? toDoubleOrNull(Object? value) => (value as num?)?.toDouble();

int? toIntOrNull(Object? value) => (value as num?)?.toInt();

Map<String, Object?> asJsonMap(Object? value) =>
    (value as Map<Object?, Object?>).cast<String, Object?>();

/// Order-sensitive list equality for model `==`.
bool listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Sentinel so `copyWith` can distinguish "not passed" from "set to null".
const Object unset = _Unset();

class _Unset {
  const _Unset();
}
