import 'package:drift/drift.dart';

import 'converters.dart';

part 'app_database.g.dart';

// Local SQLite mirror (drift). The local DB is the source of truth for the
// UI; Supabase is reached only through the sync outbox and refresh pulls.
//
// All timestamps are stored as UTC microseconds since epoch (see
// [UtcMicrosConverter]) so last-write-wins comparisons keep full precision.
// Server columns use the same names as RPR's `public.*` tables; device-only
// columns are commented as such.

/// Mirror of `public.papers` + device-only columns.
@DataClassName('PaperRow')
class Papers extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get title => text()();
  TextColumn get storagePath => text().nullable()();
  TextColumn get fileName => text().nullable()();
  IntColumn get uploadedAt => integer().map(const UtcMicrosConverter())();
  IntColumn get readAt =>
      integer().map(const UtcMicrosConverter()).nullable()();
  TextColumn get addedFromPaperId => text().nullable()();
  TextColumn get sourceUrl => text().nullable()();
  BoolColumn get autoMatched => boolean().withDefault(const Constant(false))();
  IntColumn get matchNoticeDismissedAt =>
      integer().map(const UtcMicrosConverter()).nullable()();

  // Device-only.
  TextColumn get localFilePath => text().nullable()();
  TextColumn get downloadState =>
      text().withDefault(const Constant('notDownloaded'))();
  IntColumn get lastOpenedAt =>
      integer().map(const UtcMicrosConverter()).nullable()();
  TextColumn get syncState => text().withDefault(const Constant('synced'))();
  IntColumn get localUpdatedAt =>
      integer().map(const UtcMicrosConverter()).nullable()();

  /// Soft delete: set while the delete is in its undo window / outbox.
  IntColumn get deletedAt =>
      integer().map(const UtcMicrosConverter()).nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Mirror of `public.highlights` + device-only colour.
@DataClassName('HighlightRow')
@TableIndex(name: 'highlights_paper_id_idx', columns: {#paperId})
class Highlights extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get paperId => text()();
  TextColumn get selectedText => text()();
  TextColumn get contextBefore => text().nullable()();
  TextColumn get contextAfter => text().nullable()();
  IntColumn get pageNumber => integer().nullable()();

  /// `position` jsonb, stored as JSON text.
  TextColumn get position => text().nullable()();
  IntColumn get createdAt => integer().map(const UtcMicrosConverter())();

  // Device-only.
  TextColumn get color => text().withDefault(const Constant('yellow'))();
  IntColumn get localUpdatedAt =>
      integer().map(const UtcMicrosConverter()).nullable()();
  TextColumn get syncState => text().withDefault(const Constant('synced'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Mirror of `public.figure_highlights` (note syncs LWW on updated_at).
@DataClassName('FigureHighlightRow')
@TableIndex(name: 'figure_highlights_paper_id_idx', columns: {#paperId})
class FigureHighlights extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get paperId => text()();
  IntColumn get pageNumber => integer()();

  /// `bbox` jsonb, stored as JSON text.
  TextColumn get bbox => text()();
  TextColumn get label => text().nullable()();
  TextColumn get caption => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get storagePath => text()();
  IntColumn get createdAt => integer().map(const UtcMicrosConverter())();

  /// LWW clock: local edit time while pending, server `updated_at` once
  /// accepted.
  IntColumn get updatedAt => integer().map(const UtcMicrosConverter())();

  // Device-only.
  TextColumn get localImagePath => text().nullable()();
  TextColumn get syncState => text().withDefault(const Constant('synced'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Device-only notes (no server table in v1, option A).
@DataClassName('NoteRow')
@TableIndex(name: 'notes_paper_id_idx', columns: {#paperId})
@TableIndex(name: 'notes_highlight_id_idx', columns: {#highlightId})
class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get paperId => text()();
  TextColumn get highlightId => text().nullable()();
  IntColumn get pageNumber => integer().nullable()();
  TextColumn get body => text()();
  TextColumn get quotedExcerpt => text().nullable()();
  IntColumn get createdAt => integer().map(const UtcMicrosConverter())();
  IntColumn get updatedAt => integer().map(const UtcMicrosConverter())();

  /// Soft delete for the paper-delete undo window.
  IntColumn get deletedAt =>
      integer().map(const UtcMicrosConverter()).nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Device-only last page / zoom per paper.
@DataClassName('ReadingPositionRow')
class ReadingPositions extends Table {
  TextColumn get paperId => text()();
  IntColumn get pageNumber => integer()();
  RealColumn get zoom => real().nullable()();
  RealColumn get scrollOffset => real().nullable()();
  IntColumn get updatedAt => integer().map(const UtcMicrosConverter())();

  @override
  Set<Column<Object>> get primaryKey => {paperId};
}

/// The sync outbox (`SyncOp`), drained oldest first.
@DataClassName('SyncOpRow')
@TableIndex(name: 'sync_outbox_entity_idx', columns: {#entity, #entityId})
class SyncOutbox extends Table {
  TextColumn get id => text()();
  TextColumn get entity => text()();
  TextColumn get entityId => text()();

  /// Paper the op belongs to (for grouping in SyncSheet); may be null.
  TextColumn get paperId => text().nullable()();
  TextColumn get kind => text()();

  /// JSON object of server columns.
  TextColumn get payload => text()();
  IntColumn get createdAt => integer().map(const UtcMicrosConverter())();
  IntColumn get localUpdatedAt => integer().map(const UtcMicrosConverter())();
  TextColumn get deviceId => text()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();

  /// Not pushed before this time (retry backoff, delete undo window).
  IntColumn get notBefore =>
      integer().map(const UtcMicrosConverter()).nullable()();

  /// Rejected permanently; waits for the user to retry or discard.
  BoolColumn get failed => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Local values that lost a last-write-wins conflict (kept 30 days).
@DataClassName('ReplacedVersionRow')
class ReplacedVersions extends Table {
  TextColumn get id => text()();
  TextColumn get entity => text()();
  TextColumn get entityId => text()();
  TextColumn get mine => text()();
  IntColumn get mineUpdatedAt => integer().map(const UtcMicrosConverter())();
  IntColumn get theirsUpdatedAt => integer().map(const UtcMicrosConverter())();
  IntColumn get replacedAt => integer().map(const UtcMicrosConverter())();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Small key/value store: device id, DB owner, sync cursor, AI cache.
@DataClassName('KvRow')
class Kv extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    Papers,
    Highlights,
    FigureHighlights,
    Notes,
    ReadingPositions,
    SyncOutbox,
    ReplacedVersions,
    Kv,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<String?> readKv(String key) async {
    final row = await (select(
      kv,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> writeKv(String key, String value) =>
      into(kv)
          .insertOnConflictUpdate(KvCompanion.insert(key: key, value: value));

  Future<void> deleteKv(String key) =>
      (delete(kv)..where((t) => t.key.equals(key))).go();

  /// Wipes every table (sign-out / different user signed in).
  Future<void> clearAll() => transaction(() async {
    for (final table in allTables) {
      await delete(table).go();
    }
  });
}
