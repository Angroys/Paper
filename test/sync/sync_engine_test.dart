import 'dart:io' as io;
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:paper/data/local_highlight_repository.dart';
import 'package:paper/data/local_note_repository.dart';
import 'package:paper/data/local_paper_repository.dart';
import 'package:paper/domain/domain.dart';
import 'package:paper/sync/sync_engine.dart';

import '../data/fakes.dart';

void main() {
  late TestEnv env;
  late FakeRemote remote;
  late FakeConnectivity net;
  late SyncEngine engine;
  late LocalPaperRepository papers;
  late LocalHighlightRepository highlights;
  late LocalNoteRepository notes;
  late StreamController<AuthState> auth;
  late AuthState authState;

  setUp(() {
    env = TestEnv();
    remote = FakeRemote(serverClock: () => env.clock.now);
    net = FakeConnectivity();
    auth = StreamController<AuthState>.broadcast();
    authState = signedIn;
    engine = SyncEngine(
      store: env.store,
      remote: remote,
      connectivity: net,
      authStates: auth.stream,
      currentAuth: () => authState,
      // Long timers: tests drive syncNow() explicitly.
      periodicInterval: const Duration(hours: 1),
      writeDebounce: const Duration(hours: 1),
    );
    papers = LocalPaperRepository(
      store: env.store,
      remote: remote,
      currentUserId: () => userId,
      pull: engine.pull,
    );
    highlights = LocalHighlightRepository(
      store: env.store,
      currentUserId: () => userId,
    );
    notes = LocalNoteRepository(store: env.store);
  });

  tearDown(() async {
    await engine.dispose();
    await auth.close();
    await env.dispose();
  });

  Future<int> outboxCount() async =>
      (await env.db.select(env.db.syncOutbox).get()).length;

  Highlight hl(String id, String paperId) => Highlight(
    id: id,
    userId: userId,
    paperId: paperId,
    selectedText: 'attention',
    pageNumber: 2,
    createdAt: env.clock.now,
  );

  Future<FigureHighlight> syncedFigure(String paperId, {String? note}) async {
    final f = await highlights.createFigureHighlight(
      FigureHighlight(
        id: 'fig-1',
        userId: userId,
        paperId: paperId,
        pageNumber: 1,
        bbox: const FigureBBox(x: 0, y: 0, width: 1, height: 1),
        storagePath: '',
        note: note,
        createdAt: env.clock.now,
        updatedAt: env.clock.now,
      ),
      pngBytes: Uint8List.fromList([1, 2, 3]),
    );
    await engine.syncNow();
    return f;
  }

  test('drains the outbox oldest first: upload, row, highlight', () async {
    final p = await papers.importFile(writePdf(env.tmp, 'paper.pdf').path);
    await highlights.createHighlight(hl('h1', p.id));
    await engine.syncNow();
    expect(remote.calls.take(3), [
      'upload papers/${p.storagePath}',
      'upsertPaper ${p.id}',
      'insertHighlight h1',
    ]);
    expect(await outboxCount(), 0);
    expect((await papers.getPaper(p.id))!.syncState, SyncState.synced);
    expect(
      (await highlights.watchHighlights(p.id).first).single.syncState,
      SyncState.synced,
    );
    expect(engine.status.phase, SyncPhase.synced);
    expect(engine.status.lastSyncedAt, env.clock.now);
  });

  test('device-only fields never reach the server', () async {
    final p = await papers.importFile(writePdf(env.tmp, 'paper.pdf').path);
    final h = await highlights.createHighlight(hl('h1', p.id));
    await highlights.updateColor(h.id, HighlightColor.green);
    await papers.saveReadingPosition(
      p.id,
      ReadingPosition(pageNumber: 9, updatedAt: env.clock.now),
    );
    await papers.markOpened(p.id);
    final now = env.clock.now;
    await notes.upsertNote(
      Note(
        id: 'n1',
        paperId: p.id,
        highlightId: h.id,
        body: 'secret',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await engine.syncNow();
    const deviceOnly = {
      'color',
      'local_file_path',
      'download_state',
      'reading_position',
      'last_opened_at',
      'sync_state',
      'local_updated_at',
      'local_image_path',
      '_base_updated_at',
    };
    for (final row in remote.sent) {
      expect(
        row.keys.toSet().intersection(deviceOnly),
        isEmpty,
        reason: '$row',
      );
    }
    expect(remote.sent.toString(), isNot(contains('secret')));
  });

  test('offline: ops wait with backoff, then drain on reconnect', () async {
    final p = await papers.importFile(writePdf(env.tmp, 'paper.pdf').path);
    net.online = false;
    await engine.syncNow();
    expect(remote.calls, isEmpty);
    expect(engine.status.phase, SyncPhase.offline);
    expect(engine.status.pendingCount, 1);

    // Interface says online but requests fail: retry with backoff.
    net.online = true;
    remote.offline = true;
    await engine.syncNow();
    final op = (await env.db.select(env.db.syncOutbox).get()).single;
    expect(op.attempts, 1);
    expect(op.notBefore, env.clock.now.add(const Duration(seconds: 2)));
    expect(engine.status.phase, SyncPhase.offline);

    remote.offline = false;
    await engine.syncNow();
    expect(await outboxCount(), 1, reason: 'still inside backoff');
    env.clock.advance(const Duration(seconds: 3));
    await engine.syncNow();
    expect(await outboxCount(), 0);
    expect(remote.papers, contains(p.id));
    expect(engine.status.phase, SyncPhase.synced);
  });

  test('reconnect event triggers a sync', () async {
    await engine.start();
    net.set(false);
    await papers.importFile(writePdf(env.tmp, 'paper.pdf').path);
    await Future<void>.delayed(Duration.zero);
    expect(remote.papers, isEmpty);
    net.set(true);
    await pumpEventQueue();
    await engine.syncNow();
    expect(remote.papers, hasLength(1));
  });

  test('permanent rejection marks the op failed; retry and discard', () async {
    final p = await papers.importFile(writePdf(env.tmp, 'paper.pdf').path);
    await engine.syncNow();
    await papers.rename(p.id, 'New');
    remote.papers.clear(); // Deleted on another device.
    await engine.syncNow();
    // The pull sees the paper gone but it has a (failed) op: kept locally.
    final op = (await env.db.select(env.db.syncOutbox).get()).single;
    expect(op.failed, isTrue);
    expect(op.lastError, 'notFound');
    expect(engine.status.phase, SyncPhase.error);
    expect(engine.status.failedCount, 1);
    expect((await papers.getPaper(p.id))!.syncState, SyncState.failed);

    await engine.discardOp(op.id);
    await engine.syncNow();
    expect(await outboxCount(), 0);
    expect(await papers.getPaper(p.id), isNull, reason: 'server deleted it');
  });

  test('auth expired stops the round and keeps the outbox', () async {
    await papers.importFile(writePdf(env.tmp, 'paper.pdf').path);
    remote.failWith = const AuthExpiredException('jwt expired');
    await engine.syncNow();
    expect(engine.status.phase, SyncPhase.error);
    expect(engine.status.authExpired, isTrue);
    expect(await outboxCount(), 1);
    await engine.syncNow();
    expect(engine.status.authExpired, isFalse);
    expect(await outboxCount(), 0);
  });

  test('delete waits out the undo window, then purges locally', () async {
    final p = await papers.importFile(writePdf(env.tmp, 'paper.pdf').path);
    await highlights.createHighlight(hl('h1', p.id));
    await engine.syncNow();
    final file = (await papers.getPaper(p.id))!.localFilePath!;
    await papers.delete(p.id);
    await engine.syncNow();
    expect(remote.papers, contains(p.id), reason: 'inside undo window');
    env.clock.advance(deleteUndoWindow + const Duration(seconds: 1));
    await engine.syncNow();
    expect(remote.papers, isEmpty);
    expect(remote.highlights, isEmpty);
    expect(await env.db.select(env.db.highlights).get(), isEmpty);
    expect(await env.db.select(env.db.papers).get(), isEmpty);
    expect(await outboxCount(), 0);
    expect(File2.exists(file), isFalse);
  });

  test('create + delete of a never-pushed highlight cancel out', () async {
    final p = await papers.importFile(writePdf(env.tmp, 'paper.pdf').path);
    await engine.syncNow();
    await highlights.createHighlight(hl('h1', p.id));
    await highlights.deleteHighlight('h1');
    await engine.syncNow();
    expect(remote.calls.where((c) => c.contains('h1')), isEmpty);
    expect(await env.db.select(env.db.highlights).get(), isEmpty);
  });

  test('highlight delete syncs; server-side create appears locally', () async {
    final p = await papers.importFile(writePdf(env.tmp, 'paper.pdf').path);
    await highlights.createHighlight(hl('h1', p.id));
    await engine.syncNow();
    await highlights.deleteHighlight('h1');
    remote.highlights['h2'] = {
      ...hl('h2', p.id).toSupabaseRow(),
      'selected_text': 'from the web',
    };
    await engine.syncNow();
    expect(remote.highlights.keys, ['h2']);
    final local = await highlights.watchHighlights(p.id).first;
    expect(local.single.id, 'h2');
    expect(local.single.color, HighlightColor.yellow);
  });

  test('server-deleted highlight turns its notes into page notes', () async {
    final p = await papers.importFile(writePdf(env.tmp, 'paper.pdf').path);
    await highlights.createHighlight(hl('h1', p.id));
    await engine.syncNow();
    final now = env.clock.now;
    await notes.upsertNote(
      Note(
        id: 'n1',
        paperId: p.id,
        highlightId: 'h1',
        body: 'my note',
        createdAt: now,
        updatedAt: now,
      ),
    );
    remote.highlights.clear();
    await engine.syncNow();
    final n = (await notes.watchNotes(p.id).first).single;
    expect(n.highlightId, isNull);
    expect(n.quotedExcerpt, 'attention');
    expect(n.pageNumber, 2);
    final replaced = await engine.watchReplacedVersions().first;
    expect(replaced.single.entity, SyncEntity.highlight);
    await engine.restoreReplaced(replaced.single.id);
    await engine.syncNow();
    expect(remote.highlights, contains('h1'));
  });

  test('figure note LWW: local newer than server edit wins', () async {
    final p = await papers.importFile(writePdf(env.tmp, 'paper.pdf').path);
    await syncedFigure(p.id, note: 'v0');
    // Another device edits at T+1 min.
    env.clock.advance(const Duration(minutes: 1));
    remote.figures['fig-1']!
      ..['note'] = 'theirs'
      ..['updated_at'] = dateToJsonUtc(env.clock.now);
    // We edit offline at T+2 min.
    env.clock.advance(const Duration(minutes: 1));
    await highlights.updateFigureNote('fig-1', 'mine');
    await engine.syncNow();
    expect(remote.figures['fig-1']!['note'], 'mine');
    expect(await engine.watchReplacedVersions().first, isEmpty);
  });

  test(
    'figure note LWW: newer server edit wins, mine kept as replaced',
    () async {
      final p = await papers.importFile(writePdf(env.tmp, 'paper.pdf').path);
      await syncedFigure(p.id, note: 'v0');
      // We edit offline at T+1 min ...
      env.clock.advance(const Duration(minutes: 1));
      await highlights.updateFigureNote('fig-1', 'mine');
      final mineAt = env.clock.now;
      // ... another device edits later, at T+2 min.
      env.clock.advance(const Duration(minutes: 1));
      remote.figures['fig-1']!
        ..['note'] = 'theirs'
        ..['updated_at'] = dateToJsonUtc(env.clock.now);
      await engine.syncNow();
      expect(remote.figures['fig-1']!['note'], 'theirs');
      final local = (await highlights.watchFigureHighlights(p.id).first).single;
      expect(local.note, 'theirs');
      expect(local.syncState, SyncState.synced);
      final replaced = (await engine.watchReplacedVersions().first).single;
      expect(replaced.mine['note'], 'mine');
      expect(replaced.mineUpdatedAt, mineAt);
      expect(replaced.theirsUpdatedAt, env.clock.now);
      expect(await outboxCount(), 0);

      // Restore mine = a new, newest write.
      env.clock.advance(const Duration(minutes: 1));
      await engine.restoreReplaced(replaced.id);
      await engine.syncNow();
      expect(remote.figures['fig-1']!['note'], 'mine');
      expect(await engine.watchReplacedVersions().first, isEmpty);
    },
  );

  test('figure note: unchanged server version always takes the push', () async {
    final p = await papers.importFile(writePdf(env.tmp, 'paper.pdf').path);
    await syncedFigure(p.id, note: 'v0');
    // Device clock behind the server: still no conflict, base matches.
    env.clock.now = env.clock.now.subtract(const Duration(hours: 1));
    await highlights.updateFigureNote('fig-1', 'mine');
    await engine.syncNow();
    expect(remote.figures['fig-1']!['note'], 'mine');
  });

  test('pull mirrors server renames when nothing is pending', () async {
    final p = await papers.importFile(writePdf(env.tmp, 'paper.pdf').path);
    await engine.syncNow();
    remote.papers[p.id]!['title'] = 'Renamed on web';
    await papers.refresh();
    expect((await papers.getPaper(p.id))!.title, 'Renamed on web');
    // Local pending rename wins over the server value (last push wins).
    await papers.rename(p.id, 'Mine');
    remote.papers[p.id]!['title'] = 'Web again';
    await papers.refresh();
    expect((await papers.getPaper(p.id))!.title, 'Mine');
    await engine.syncNow();
    expect(remote.papers[p.id]!['title'], 'Mine');
  });

  test('a different user signing in wipes local data', () async {
    await engine.start();
    await papers.importFile(writePdf(env.tmp, 'paper.pdf').path);
    authState = const AuthState.signedIn(AppUser(id: 'other-user'));
    auth.add(authState);
    await pumpEventQueue();
    expect(await env.db.select(env.db.papers).get(), isEmpty);
    expect(await outboxCount(), 0);
  });
}

abstract final class File2 {
  static bool exists(String path) => io.File(path).existsSync();
}
