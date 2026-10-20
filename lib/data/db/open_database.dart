import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'app_database.dart';

/// Opens the on-device database (`paper.sqlite` in the app support dir).
AppDatabase openAppDatabase() => AppDatabase(
  driftDatabase(
    name: 'paper',
    native: const DriftNativeOptions(
      databaseDirectory: getApplicationSupportDirectory,
    ),
  ),
);

/// For tests: `AppDatabase(NativeDatabase.memory())`.
AppDatabase appDatabaseFor(QueryExecutor executor) => AppDatabase(executor);
