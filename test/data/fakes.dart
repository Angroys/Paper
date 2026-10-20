import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:paper/data/db/app_database.dart';
import 'package:paper/data/file_store.dart';
import 'package:paper/data/local_store.dart';
import 'package:paper/data/remote/remote_data_source.dart';
import 'package:paper/domain/domain.dart';

/// In-memory Supabase stand-in. [offline] makes every call throw
/// `OfflineException`; [failWith] fails the next call.
class FakeRemote implements RemoteDataSource {
  FakeRemote({DateTime Function()? serverClock})
    : serverClock = serverClock ?? (() => DateTime.now().toUtc());

  DateTime Function() serverClock;
  final papers = <String, Map<String, Object?>>{};
  final highlights = <String, Map<String, Object?>>{};
  final figures = <String, Map<String, Object?>>{};
  final objects = <String, Uint8List>{};
  final calls = <String>[];
  bool offline = false;
  PaperException? failWith;

  /// Every map this fake received as a row/fields (device-only leak check).
  final sent = <Map<String, Object?>>[];

  void _gate(String call) {
    calls.add(call);
    if (offline) throw const OfflineException('fake offline');
    final f = failWith;
    if (f != null) {
      failWith = null;
      throw f;
    }
  }

  @override
  Future<List<Map<String, Object?>>> fetchPapers() async {
    _gate('fetchPapers');
    return papers.values.map((r) => {...r}).toList();
  }

  @override
  Future<Map<String, Object?>> upsertPaper(Map<String, Object?> row) async {
    _gate('upsertPaper ${row['id']}');
    sent.add(row);
    papers[row['id']! as String] = {...row};
    return {...row};
  }

  @override
  Future<void> updatePaper(String id, Map<String, Object?> fields) async {
    _gate('updatePaper $id');
    sent.add(fields);
    final row = papers[id];
    if (row == null) throw NotFoundException('paper $id');
    row.addAll(fields);
  }

  @override
  Future<void> deletePaper(String id) async {
    _gate('deletePaper $id');
    papers.remove(id);
    highlights.removeWhere((_, h) => h['paper_id'] == id);
    figures.removeWhere((_, f) => f['paper_id'] == id);
  }

  @override
  Future<List<Map<String, Object?>>> fetchHighlights() async {
    _gate('fetchHighlights');
    return highlights.values.map((r) => {...r}).toList();
  }

  @override
  Future<void> insertHighlight(Map<String, Object?> row) async {
    _gate('insertHighlight ${row['id']}');
    sent.add(row);
    highlights.putIfAbsent(row['id']! as String, () => {...row});
  }

  @override
  Future<void> deleteHighlight(String id) async {
    _gate('deleteHighlight $id');
    highlights.remove(id);
  }

  @override
  Future<List<Map<String, Object?>>> fetchFigureHighlights() async {
    _gate('fetchFigureHighlights');
    return figures.values.map((r) => {...r}).toList();
  }

  @override
  Future<Map<String, Object?>?> fetchFigureHighlight(String id) async {
    _gate('fetchFigureHighlight $id');
    final r = figures[id];
    return r == null ? null : {...r};
  }

  @override
  Future<Map<String, Object?>> upsertFigureHighlight(
    Map<String, Object?> row,
  ) async {
    _gate('upsertFigureHighlight ${row['id']}');
    sent.add(row);
    final stored = {...row, 'updated_at': dateToJsonUtc(serverClock())};
    figures[row['id']! as String] = stored;
    return {...stored};
  }

  @override
  Future<Map<String, Object?>> updateFigureNote(String id, String? note) async {
    _gate('updateFigureNote $id');
    sent.add({'note': note});
    final row = figures[id];
    if (row == null) throw NotFoundException('figure $id');
    row['note'] = note;
    row['updated_at'] = dateToJsonUtc(serverClock());
    return {...row};
  }

  @override
  Future<void> deleteFigureHighlight(String id) async {
    _gate('deleteFigureHighlight $id');
    figures.remove(id);
  }

  @override
  Future<void> uploadObject(
    String bucket,
    String path,
    Uint8List bytes, {
    required String contentType,
  }) async {
    _gate('upload $bucket/$path');
    objects['$bucket/$path'] = bytes;
  }

  @override
  Future<Uint8List> downloadObject(
    String bucket,
    String path, {
    void Function(double progress)? onProgress,
  }) async {
    _gate('download $bucket/$path');
    final bytes = objects['$bucket/$path'];
    if (bytes == null) throw NotFoundException(path);
    onProgress?.call(0.5);
    return bytes;
  }

  Map<String, Object?>? importResult;

  @override
  Future<Map<String, Object?>> importPaperFromUrl(Uri url) async {
    _gate('import $url');
    final r = importResult!;
    papers[r['id']! as String] = {...r};
    return {...r};
  }
}

String dateToJsonUtc(DateTime d) => d.toUtc().toIso8601String();

/// Controllable connectivity.
class FakeConnectivity implements ConnectivityService {
  bool online = true;
  final _c = StreamController<bool>.broadcast();

  void set(bool value) {
    online = value;
    _c.add(value);
  }

  @override
  bool get isOnline => online;

  @override
  Stream<bool> watchOnline() async* {
    yield online;
    yield* _c.stream;
  }

  @override
  Future<bool> check() async => online;
}

/// Mutable test clock.
class TestClock {
  TestClock([DateTime? start]) : now = start ?? DateTime.utc(2026, 10, 20, 12);
  DateTime now;
  DateTime call() => now;
  void advance(Duration d) => now = now.add(d);
}

const userId = '11111111-1111-4111-8111-111111111111';
const signedIn = AuthState.signedIn(AppUser(id: userId, email: 'a@b.c'));

/// In-memory DB + temp file store.
class TestEnv {
  TestEnv() {
    tmp = Directory.systemTemp.createTempSync('paper-test-');
    db = AppDatabase(NativeDatabase.memory());
    store = LocalStore(
      db: db,
      files: FileStore(() async => tmp),
      clock: clock.call,
    );
  }

  final clock = TestClock();
  late final Directory tmp;
  late final AppDatabase db;
  late final LocalStore store;

  Future<void> dispose() async {
    await db.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  }
}

/// A minimal valid-looking PDF on disk.
File writePdf(Directory dir, String name, {int extraBytes = 100}) {
  final f = File('${dir.path}/$name');
  f.writeAsBytesSync([
    ...'%PDF-1.7\n'.codeUnits,
    ...List.filled(extraBytes, 32),
  ]);
  return f;
}
