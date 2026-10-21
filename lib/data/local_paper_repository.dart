import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../domain/domain.dart';
import '../domain/models/json.dart';
import 'db/app_database.dart';
import 'local_store.dart';
import 'mappers.dart';
import 'remote/remote_data_source.dart';

/// Import size cap. RPR enforces 20 MB (`MAX_PDF_BYTES`); keep in sync.
const int maxPdfBytes = 20 * 1024 * 1024;

/// How long a deleted paper stays restorable before the delete is pushed
/// (the undo snackbar shows 8 s; 2 s slack).
const Duration deleteUndoWindow = Duration(seconds: 10);

/// True when [head] starts with the `%PDF-` magic.
bool hasPdfMagic(List<int> head) =>
    head.length >= 5 &&
    head[0] == 0x25 &&
    head[1] == 0x50 &&
    head[2] == 0x44 &&
    head[3] == 0x46 &&
    head[4] == 0x2D;

/// Title from a file name, like RPR's `cleanFileNameTitle` (drop `.pdf`,
/// turn `_`/`-` runs into spaces, collapse whitespace).
String titleFromFileName(String fileName) {
  var t = fileName.trim();
  if (t.toLowerCase().endsWith('.pdf')) t = t.substring(0, t.length - 4);
  t = t.replaceAll(RegExp(r'[_]+'), ' ').replaceAll(RegExp(r'\s+'), ' ');
  t = t.trim();
  return t.isEmpty ? 'Untitled paper' : t;
}

/// Local-first [PaperRepository]: reads stream from SQLite, writes go to
/// SQLite and the outbox; [refresh] and URL import talk to the server.
class LocalPaperRepository implements PaperRepository {
  LocalPaperRepository({
    required this._store,
    required this._remote,
    required String? Function() currentUserId,
    this._pull,
  }) : _userId = currentUserId;

  final LocalStore _store;
  final RemoteDataSource _remote;
  final String? Function() _userId;

  /// Server pull (the sync engine's); used by [refresh].
  final Future<void> Function()? _pull;

  AppDatabase get _db => _store.db;

  String _requireUser() {
    final id = _userId();
    if (id == null) throw const AuthExpiredException('Not signed in');
    return id;
  }

  /// URL import runs on the server: it needs an account, not the guest.
  void _requireAccount() {
    if (isGuestUserId(_requireUser())) {
      throw const AuthExpiredException('Sign in to import from a link');
    }
  }

  @override
  Stream<List<Paper>> watchPapers({
    String query = '',
    PaperSort sort = PaperSort.recentlyOpened,
  }) {
    final papers = _db.papers;
    final positions = _db.readingPositions;
    final q = _db.select(papers).join([
      leftOuterJoin(positions, positions.paperId.equalsExp(papers.id)),
    ])..where(papers.deletedAt.isNull());
    final needle = query.trim();
    if (needle.isNotEmpty) {
      final pattern =
          '%${needle.replaceAll('%', r'\%').replaceAll('_', r'\_')}%';
      q.where(
        papers.title.like(pattern, escapeChar: r'\') |
            papers.fileName.like(pattern, escapeChar: r'\'),
      );
    }
    switch (sort) {
      case PaperSort.recentlyOpened:
        q.orderBy([
          OrderingTerm.desc(
            coalesce<int>([papers.lastOpenedAt, papers.uploadedAt]),
          ),
        ]);
      case PaperSort.recentlyAdded:
        q.orderBy([OrderingTerm.desc(papers.uploadedAt)]);
      case PaperSort.title:
        q.orderBy([OrderingTerm.asc(papers.title.collate(Collate.noCase))]);
    }
    return q.watch().map(
      (rows) => [
        for (final r in rows)
          paperFromRow(
            r.readTable(papers),
            position: r.readTableOrNull(positions),
          ),
      ],
    );
  }

  @override
  Stream<Paper?> watchPaper(String paperId) {
    final papers = _db.papers;
    final positions = _db.readingPositions;
    final q = _db.select(papers).join([
      leftOuterJoin(positions, positions.paperId.equalsExp(papers.id)),
    ])..where(papers.id.equals(paperId) & papers.deletedAt.isNull());
    return q.watchSingleOrNull().map(
      (r) => r == null
          ? null
          : paperFromRow(
              r.readTable(papers),
              position: r.readTableOrNull(positions),
            ),
    );
  }

  @override
  Future<Paper?> getPaper(String paperId) => watchPaper(paperId).first;

  @override
  Future<void> refresh() async {
    try {
      await _pull?.call();
    } on OfflineException {
      // No-op offline (the library is served from SQLite).
    }
  }

  @override
  Future<Paper> importFromUrl(Uri url) async {
    _requireAccount();
    if (!(url.isScheme('http') || url.isScheme('https')) || url.host.isEmpty) {
      throw const InvalidPdfException('Not an http(s) URL');
    }
    final row = await _remote.importPaperFromUrl(url);
    await _db
        .into(_db.papers)
        .insertOnConflictUpdate(
          paperServerColumns(row).copyWith(
            syncState: Value(SyncState.synced.name),
            downloadState: Value(DownloadState.notDownloaded.name),
          ),
        );
    return (await getPaper(row['id']! as String))!;
  }

  @override
  Future<Paper> importFile(String filePath, {String? fileName}) async {
    final userId = _requireUser();
    final file = File(filePath);
    if (!file.existsSync()) throw NotFoundException(filePath);
    final length = await file.length();
    if (length > maxPdfBytes) throw const FileTooLargeException(maxPdfBytes);
    if (length == 0) throw const InvalidPdfException('Empty file');
    final head = await _readHead(file);
    if (!hasPdfMagic(head)) throw const InvalidPdfException('Not a PDF');

    final id = _store.newId();
    final name = fileName ?? p.basename(filePath);
    final dest = await _store.files.pdfPath(id);
    try {
      await file.copy(dest);
    } on FileSystemException catch (e) {
      throw StorageException(e.message);
    }
    final now = _store.now();
    final paper = Paper(
      id: id,
      userId: userId,
      title: titleFromFileName(name),
      // Same object id as the paper id: `<user_id>/<paper_id>.pdf`.
      storagePath: paperStoragePath(userId, id),
      fileName: name,
      uploadedAt: now,
      localFilePath: dest,
      downloadState: DownloadState.downloaded,
      syncState: SyncState.pendingCreate,
      localUpdatedAt: now,
    );
    await _db.transaction(() async {
      await _db
          .into(_db.papers)
          .insert(
            paperServerColumns(paper.toSupabaseRow()).copyWith(
              localFilePath: Value(dest),
              downloadState: Value(DownloadState.downloaded.name),
              syncState: Value(SyncState.pendingCreate.name),
              localUpdatedAt: Value(now),
            ),
          );
      await _store.enqueue(
        entity: SyncEntity.paper,
        entityId: id,
        kind: SyncOpKind.create,
        payload: paper.toSupabaseRow(),
        paperId: id,
      );
    });
    return paper;
  }

  static Future<List<int>> _readHead(File file) async {
    final raf = await file.open();
    try {
      return await raf.read(5);
    } finally {
      await raf.close();
    }
  }

  Future<PaperRow> _row(String paperId) async {
    final row = await (_db.select(
      _db.papers,
    )..where((t) => t.id.equals(paperId))).getSingleOrNull();
    if (row == null) throw NotFoundException('paper $paperId');
    return row;
  }

  /// Applies a server-column edit locally and queues it.
  Future<void> _edit(
    String paperId,
    PapersCompanion local,
    Map<String, Object?> serverFields,
  ) async {
    await _db.transaction(() async {
      final row = await _row(paperId);
      final now = _store.now();
      final state = SyncState.fromName(row.syncState);
      await (_db.update(_db.papers)..where((t) => t.id.equals(paperId))).write(
        local.copyWith(
          localUpdatedAt: Value(now),
          syncState: Value(
            state == SyncState.pendingCreate
                ? state.name
                : SyncState.pendingUpdate.name,
          ),
        ),
      );
      await _store.enqueue(
        entity: SyncEntity.paper,
        entityId: paperId,
        kind: SyncOpKind.update,
        payload: serverFields,
        paperId: paperId,
      );
    });
  }

  @override
  Future<void> rename(String paperId, String title) {
    final t = title.trim();
    if (t.isEmpty) throw ArgumentError.value(title, 'title', 'empty');
    return _edit(paperId, PapersCompanion(title: Value(t)), {'title': t});
  }

  @override
  Future<void> setRead(String paperId, {required bool read}) {
    final at = read ? _store.now() : null;
    return _edit(paperId, PapersCompanion(readAt: Value(at)), {
      'read_at': dateToJson(at),
    });
  }

  @override
  Future<void> dismissMatchNotice(String paperId) {
    final at = _store.now();
    return _edit(paperId, PapersCompanion(matchNoticeDismissedAt: Value(at)), {
      'match_notice_dismissed_at': dateToJson(at),
    });
  }

  @override
  Future<void> delete(String paperId) async {
    await _db.transaction(() async {
      await _row(paperId);
      final now = _store.now();
      await (_db.update(_db.papers)..where((t) => t.id.equals(paperId))).write(
        PapersCompanion(deletedAt: Value(now)),
      );
      await (_db.update(_db.notes)..where((t) => t.paperId.equals(paperId)))
          .write(NotesCompanion(deletedAt: Value(now)));
      await _store.enqueue(
        entity: SyncEntity.paper,
        entityId: paperId,
        kind: SyncOpKind.delete,
        payload: const {},
        paperId: paperId,
        notBefore: now.add(deleteUndoWindow),
      );
    });
  }

  @override
  Future<void> undoDelete(String paperId) async {
    await _db.transaction(() async {
      final row = await _row(paperId);
      if (row.deletedAt == null) return;
      final ops = await _store.opsFor(SyncEntity.paper, paperId);
      final deletes = ops.where((o) => o.kind == SyncOpKind.delete.name);
      if (deletes.isEmpty) {
        throw NotFoundException('delete of $paperId already committed');
      }
      for (final op in deletes) {
        await _store.removeOp(op.id);
      }
      await (_db.update(_db.papers)..where((t) => t.id.equals(paperId))).write(
        const PapersCompanion(deletedAt: Value(null)),
      );
      await (_db.update(_db.notes)..where((t) => t.paperId.equals(paperId)))
          .write(const NotesCompanion(deletedAt: Value(null)));
    });
  }

  @override
  Future<String> ensureLocalFile(
    String paperId, {
    void Function(double progress)? onProgress,
  }) async {
    final row = await _row(paperId);
    final existing = row.localFilePath;
    if (existing != null && File(existing).existsSync()) {
      onProgress?.call(1);
      return existing;
    }
    final storagePath = row.storagePath;
    if (storagePath == null) {
      throw const NotFoundException('Paper has no PDF (linkless)');
    }
    await _setDownload(paperId, DownloadState.downloading);
    try {
      final Uint8List bytes = await _remote.downloadObject(
        papersBucket,
        storagePath,
        onProgress: onProgress,
      );
      final dest = await _store.files.pdfPath(paperId);
      await File(dest).writeAsBytes(bytes, flush: true);
      await (_db.update(_db.papers)..where((t) => t.id.equals(paperId))).write(
        PapersCompanion(
          localFilePath: Value(dest),
          downloadState: Value(DownloadState.downloaded.name),
        ),
      );
      onProgress?.call(1);
      return dest;
    } on OfflineException {
      await _setDownload(paperId, DownloadState.notDownloaded);
      rethrow;
    } on Object {
      await _setDownload(paperId, DownloadState.failed);
      rethrow;
    }
  }

  Future<void> _setDownload(String paperId, DownloadState state) =>
      (_db.update(_db.papers)..where((t) => t.id.equals(paperId))).write(
        PapersCompanion(downloadState: Value(state.name)),
      );

  @override
  Future<void> removeDownload(String paperId) async {
    final row = await _row(paperId);
    // A file import that has not been uploaded yet: the cached copy is the
    // only copy, so it stays.
    if (row.syncState == SyncState.pendingCreate.name) return;
    await _store.files.deleteQuietly(row.localFilePath);
    await (_db.update(_db.papers)..where((t) => t.id.equals(paperId))).write(
      PapersCompanion(
        localFilePath: const Value(null),
        downloadState: Value(DownloadState.notDownloaded.name),
      ),
    );
  }

  @override
  Future<void> saveReadingPosition(String paperId, ReadingPosition position) =>
      _db
          .into(_db.readingPositions)
          .insertOnConflictUpdate(
            ReadingPositionsCompanion.insert(
              paperId: paperId,
              pageNumber: position.pageNumber,
              zoom: Value(position.zoom),
              scrollOffset: Value(position.scrollOffset),
              updatedAt: position.updatedAt,
            ),
          );

  @override
  Future<void> markOpened(String paperId) =>
      (_db.update(_db.papers)..where((t) => t.id.equals(paperId))).write(
        PapersCompanion(lastOpenedAt: Value(_store.now())),
      );
}
