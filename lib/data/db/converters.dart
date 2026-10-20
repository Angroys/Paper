import 'package:drift/drift.dart';

/// Stores a [DateTime] as UTC microseconds since epoch (full precision,
/// unlike drift's default seconds encoding).
class UtcMicrosConverter extends TypeConverter<DateTime, int> {
  const UtcMicrosConverter();

  @override
  DateTime fromSql(int fromDb) =>
      DateTime.fromMicrosecondsSinceEpoch(fromDb, isUtc: true);

  @override
  int toSql(DateTime value) => value.toUtc().microsecondsSinceEpoch;
}
