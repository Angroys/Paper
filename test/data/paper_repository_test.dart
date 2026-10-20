import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paper/data/local_paper_repository.dart';
import 'package:paper/data/remote/remote_data_source.dart';
import 'package:paper/domain/domain.dart';

import 'fakes.dart';

void main() {
  late TestEnv env;
  late FakeRemote remote;
  late LocalPaperRepository repo;

  setUp(() {
    env = TestEnv();
    remote = FakeRemote();
    repo = LocalPaperRepository(
      store: env.store,
      remote: remote,
      currentUserId: () => userId,
    );
  });
  tearDown(() => env.dispose());

  Future<List<SyncOp>> ops() async =>
      (await env.db.select(env.db.syncOutbox).get())
          .map(
            (r) => SyncOp(
              id: r.id,
              entity: SyncEntity.values.byName(r.entity),
              entityId: r.entityId,
              kind: SyncOpKind.values.byName(r.kind),
              createdAt: r.createdAt,
              localUpdatedAt: r.localUpdatedAt,
              deviceId: r.deviceId,
            ),
          )
          .toList();

  test('importFile rejects files over 20 MB', () async {
    final f = File('${env.tmp.path}/big.pdf')..createSync();
    final raf = f.openSync(mode: FileMode.write)
      ..writeFromSync('%PDF-'.codeUnits)
      ..setPositionSync(maxPdfBytes + 1)
      ..writeByteSync(0);
    raf.closeSync();
    expect(
      () => repo.importFile(f.path),
      throwsA(
        isA<FileTooLargeException>().having(
          (e) => e.maxBytes,
          'maxBytes',
          maxPdfBytes,
        ),
      ),
    );
  });

  test('importFile rejects non-PDF bytes', () async {
    final f = File('${env.tmp.path}/x.pdf')..writeAsStringSync('hello');
    expect(() => repo.importFile(f.path), throwsA(isA<InvalidPdfException>()));
  });

  test('importFile stores locally, pendingCreate, queues one create', () async {
    final f = writePdf(env.tmp, 'attention_is_all_you_need.pdf');
    final paper = await repo.importFile(f.path);
    expect(paper.title, 'attention is all you need');
    expect(paper.storagePath, paperStoragePath(userId, paper.id));
    expect(paper.syncState, SyncState.pendingCreate);
    expect(paper.downloadState, DownloadState.downloaded);
    expect(File(paper.localFilePath!).existsSync(), isTrue);
    final list = await repo.watchPapers().first;
    expect(list.single.id, paper.id);
    final queued = await ops();
    expect(queued.single.kind, SyncOpKind.create);
    expect(remote.calls, isEmpty, reason: 'import is local-first');
  });

  test('rename coalesces into the queued create', () async {
    final paper = await repo.importFile(writePdf(env.tmp, 'a.pdf').path);
    await repo.rename(paper.id, '  Better title ');
    expect((await repo.getPaper(paper.id))!.title, 'Better title');
    final queued = await ops();
    expect(queued, hasLength(1));
    expect(queued.single.kind, SyncOpKind.create);
  });

  test('delete hides immediately; undo restores and drops the op', () async {
    final paper = await repo.importFile(writePdf(env.tmp, 'a.pdf').path);
    await repo.delete(paper.id);
    expect(await repo.watchPapers().first, isEmpty);
    expect((await ops()).map((o) => o.kind), contains(SyncOpKind.delete));
    await repo.undoDelete(paper.id);
    expect((await repo.watchPapers().first).single.id, paper.id);
    expect(
      (await ops()).map((o) => o.kind),
      isNot(contains(SyncOpKind.delete)),
    );
  });

  test('device-only writes never enter the outbox', () async {
    final paper = await repo.importFile(writePdf(env.tmp, 'a.pdf').path);
    await env.db.delete(env.db.syncOutbox).go();
    await repo.saveReadingPosition(
      paper.id,
      ReadingPosition(pageNumber: 4, zoom: 1.5, updatedAt: env.clock.now),
    );
    await repo.markOpened(paper.id);
    expect(await ops(), isEmpty);
    final p = (await repo.getPaper(paper.id))!;
    expect(p.readingPosition!.pageNumber, 4);
    expect(p.lastOpenedAt, env.clock.now);
  });

  test('search and sort', () async {
    final a = await repo.importFile(writePdf(env.tmp, 'Zebra.pdf').path);
    env.clock.advance(const Duration(minutes: 1));
    final b = await repo.importFile(writePdf(env.tmp, 'apple.pdf').path);
    expect(
      (await repo.watchPapers(sort: PaperSort.title).first).map((p) => p.id),
      [b.id, a.id],
    );
    expect(
      (await repo.watchPapers(sort: PaperSort.recentlyAdded).first).map(
        (p) => p.id,
      ),
      [b.id, a.id],
    );
    env.clock.advance(const Duration(minutes: 1));
    await repo.markOpened(a.id);
    expect((await repo.watchPapers().first).map((p) => p.id), [a.id, b.id]);
    expect((await repo.watchPapers(query: 'zeb').first).single.id, a.id);
  });

  test('importFromUrl stores the server row; offline throws', () async {
    remote.importResult = {
      'id': '22222222-2222-4222-8222-222222222222',
      'user_id': userId,
      'title': 'Imported',
      'storage_path': '$userId/x.pdf',
      'file_name': 'x.pdf',
      'uploaded_at': '2026-10-20T10:00:00Z',
    };
    final p = await repo.importFromUrl(Uri.parse('https://arxiv.org/x.pdf'));
    expect(p.title, 'Imported');
    expect(p.syncState, SyncState.synced);
    expect(await ops(), isEmpty);
    remote.offline = true;
    expect(
      () => repo.importFromUrl(Uri.parse('https://arxiv.org/y.pdf')),
      throwsA(isA<OfflineException>()),
    );
  });

  test('ensureLocalFile downloads once, removeDownload frees it', () async {
    remote.importResult = {
      'id': '33333333-3333-4333-8333-333333333333',
      'user_id': userId,
      'title': 'Cloud',
      'storage_path': '$userId/c.pdf',
      'uploaded_at': '2026-10-20T10:00:00Z',
    };
    remote.objects['papers/$userId/c.pdf'] = writePdf(
      env.tmp,
      'c.pdf',
    ).readAsBytesSync();
    final p = await repo.importFromUrl(Uri.parse('https://x.org/c.pdf'));
    final progress = <double>[];
    final path = await repo.ensureLocalFile(p.id, onProgress: progress.add);
    expect(File(path).existsSync(), isTrue);
    expect(progress.last, 1);
    expect(
      (await repo.getPaper(p.id))!.downloadState,
      DownloadState.downloaded,
    );
    await repo.ensureLocalFile(p.id);
    expect(remote.calls.where((c) => c.startsWith('download')), hasLength(1));
    await repo.removeDownload(p.id);
    expect(File(path).existsSync(), isFalse);
    expect(
      (await repo.getPaper(p.id))!.downloadState,
      DownloadState.notDownloaded,
    );
    remote.offline = true;
    expect(() => repo.ensureLocalFile(p.id), throwsA(isA<OfflineException>()));
  });
}
