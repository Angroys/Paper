import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:paper/data/local_highlight_repository.dart';
import 'package:paper/data/local_note_repository.dart';
import 'package:paper/data/local_paper_repository.dart';
import 'package:paper/domain/domain.dart';
import 'package:paper/sync/guest_merge.dart';
import 'package:paper/sync/sync_engine.dart';

import '../data/fakes.dart';

/// Guest → account merge (optional sign-in): guest rows are re-owned,
/// queued and uploaded once, nothing is lost or duplicated.
void main() {
  late TestEnv env;
  late FakeRemote remote;
  late SyncEngine engine;
  late StreamController<AuthState> auth;
  late AuthState authState;
  late String? Function() owner;
  late LocalPaperRepository papers;
  late LocalHighlightRepository highlights;
  late LocalNoteRepository notes;

  setUp(() {
    env = TestEnv();
    remote = FakeRemote(serverClock: () => env.clock.now);
    auth = StreamController<AuthState>.broadcast();
    authState = const AuthState.signedOut();
    // Same rule as the app: the account, else the guest.
    owner = () => authState.user?.id ?? kGuestUserId;
    engine = SyncEngine(
      store: env.store,
      remote: remote,
      connectivity: FakeConnectivity(),
      authStates: auth.stream,
      currentAuth: () => authState,
      periodicInterval: const Duration(hours: 1),
      writeDebounce: const Duration(hours: 1),
    );
    papers = LocalPaperRepository(
      store: env.store,
      remote: remote,
      currentUserId: () => owner(),
      pull: engine.pull,
    );
    highlights = LocalHighlightRepository(
      store: env.store,
      currentUserId: () => owner(),
    );
    notes = LocalNoteRepository(store: env.store);
  });

  tearDown(() async {
    await engine.dispose();
    await auth.close();
    await env.dispose();
  });

  Future<void> signIn(String id) async {
    authState = AuthState.signedIn(AppUser(id: id));
    auth.add(authState);
    await pumpEventQueue();
  }

  Highlight hl(String id, Paper p) => Highlight(
    id: id,
    userId: p.userId,
    paperId: p.id,
    selectedText: 'attention',
    pageNumber: 1,
    createdAt: env.clock.now,
  );

  Future<FigureHighlight> figure(String id, Paper p) =>
      highlights.createFigureHighlight(
        FigureHighlight(
          id: id,
          userId: p.userId,
          paperId: p.id,
          pageNumber: 1,
          bbox: const FigureBBox(x: 0, y: 0, width: 1, height: 1),
          storagePath: '',
          createdAt: env.clock.now,
          updatedAt: env.clock.now,
        ),
        pngBytes: Uint8List.fromList(<int>[1, 2, 3]),
      );

  test('guest writes stay local and are never pushed', () async {
    final p = await papers.importFile(writePdf(env.tmp, 'a.pdf').path);
    expect(p.userId, kGuestUserId);
    expect(p.storagePath, '$kGuestUserId/${p.id}.pdf');
    await highlights.createHighlight(hl('h1', p));
    await engine.syncNow();
    expect(remote.calls, isEmpty);
    expect((await env.db.select(env.db.syncOutbox).get()).length, 2);
  });

  test('signing in re-owns guest rows and uploads them to '
      '<user_id>/<uuid>.pdf, once', () async {
    final p = await papers.importFile(writePdf(env.tmp, 'a.pdf').path);
    await highlights.createHighlight(hl('h1', p));
    await figure('f1', p);
    await notes.upsertNote(
      Note(
        id: 'n1',
        paperId: p.id,
        body: 'mine',
        createdAt: env.clock.now,
        updatedAt: env.clock.now,
      ),
    );
    await papers.rename(p.id, 'Renamed');

    await engine.start();
    await signIn(userId);
    await engine.syncNow();

    // Storage path and rows moved to the account.
    expect(remote.objects.keys, <String>[
      'papers/$userId/${p.id}.pdf',
      'figures/$userId/${p.id}/f1.png',
    ]);
    expect(remote.papers.keys, <String>[p.id]);
    expect(remote.papers[p.id]!['user_id'], userId);
    expect(remote.papers[p.id]!['storage_path'], '$userId/${p.id}.pdf');
    expect(remote.papers[p.id]!['title'], 'Renamed');
    expect(remote.highlights['h1']!['user_id'], userId);
    expect(remote.figures['f1']!['user_id'], userId);
    expect(remote.figures['f1']!['storage_path'], '$userId/${p.id}/f1.png');
    // No guest id ever reached the server.
    expect(jsonEncode(remote.sent), isNot(contains(kGuestUserId)));

    // Local rows: owned, synced, nothing lost, nothing queued.
    final local = (await papers.getPaper(p.id))!;
    expect(local.userId, userId);
    expect(local.syncState, SyncState.synced);
    expect(local.localFilePath, isNotNull);
    expect(await env.db.select(env.db.syncOutbox).get(), isEmpty);
    expect((await env.db.select(env.db.notes).get()).single.body, 'mine');

    // Idempotent: another merge + sync changes and sends nothing.
    final calls = remote.calls.length;
    final again = await GuestDataMerge(env.store).prepareFor(userId);
    expect(again.changed, isFalse);
    await engine.syncNow();
    expect(
      remote.calls.skip(calls).where((c) => !c.startsWith('fetch')),
      isEmpty,
    );
    expect(remote.papers.length, 1);
    expect(remote.highlights.length, 1);
  });

  test('a re-owned row without an op is queued; ops are not doubled', () async {
    final p = await papers.importFile(writePdf(env.tmp, 'a.pdf').path);
    await highlights.createHighlight(hl('h1', p));
    // Lose the highlight's op (e.g. an interrupted write): the merge must
    // queue it, and must not queue the paper twice.
    await env.store.removeOpsFor(SyncEntity.highlight, 'h1');

    final merge = GuestDataMerge(env.store);
    final first = await merge.prepareFor(userId);
    expect(first.adoptedPapers, 1);
    expect(first.adoptedHighlights, 1);
    expect(first.queuedCreates, 1);
    final ops = await env.db.select(env.db.syncOutbox).get();
    expect(ops.map((o) => '${o.entity}:${o.kind}'), <String>[
      'paper:create',
      'highlight:create',
    ]);
    for (final o in ops) {
      expect(o.payload, isNot(contains(kGuestUserId)));
    }

    final second = await merge.prepareFor(userId);
    expect(second.changed, isFalse);
    expect((await env.db.select(env.db.syncOutbox).get()).length, 2);
  });

  test('a guest delete that cancels a guest create sends nothing', () async {
    final p = await papers.importFile(writePdf(env.tmp, 'a.pdf').path);
    await highlights.createHighlight(hl('h1', p));
    await highlights.deleteHighlight('h1');
    await signIn(userId);
    await engine.syncNow();
    expect(remote.highlights, isEmpty);
    expect(remote.papers.keys, <String>[p.id]);
  });

  test('sign-out keeping papers, then another account signs in: the first '
      "account's papers are removed, the guest's are merged", () async {
    // Account A's synced paper, downloaded, plus one only in the cloud.
    await signIn(userId);
    final a = await papers.importFile(writePdf(env.tmp, 'a.pdf').path);
    await engine.syncNow();
    remote.papers['cloud'] = <String, Object?>{
      ...remote.papers[a.id]!,
      'id': 'cloud',
      'storage_path': '$userId/cloud.pdf',
    };
    await engine.syncNow();
    expect((await env.db.select(env.db.papers).get()).length, 2);

    // Sign out, keeping device copies: the cloud-only paper goes.
    authState = const AuthState.signedOut();
    auth.add(authState);
    final dropped = await GuestDataMerge(env.store).keepDeviceCopiesForGuest();
    expect(dropped, 1);
    expect((await papers.getPaper(a.id))!.userId, userId);

    // The guest adds a paper.
    final g = await papers.importFile(writePdf(env.tmp, 'g.pdf').path);
    expect(g.userId, kGuestUserId);

    // Account B signs in (RLS: B's pulls never see A's rows).
    remote.papers.clear();
    const other = '22222222-2222-4222-8222-222222222222';
    await signIn(other);
    await engine.syncNow();
    final left = await env.db.select(env.db.papers).get();
    expect(left.map((r) => r.id), <String>[g.id]);
    expect(left.single.userId, other);
    expect(remote.papers[g.id]!['user_id'], other);
    expect(remote.objects.keys, contains('papers/$other/${g.id}.pdf'));
  });

  test('the same account signing back in keeps its kept papers', () async {
    await signIn(userId);
    final a = await papers.importFile(writePdf(env.tmp, 'a.pdf').path);
    await engine.syncNow();
    authState = const AuthState.signedOut();
    auth.add(authState);
    await GuestDataMerge(env.store).keepDeviceCopiesForGuest();
    // Guest highlight on the kept paper inherits the paper's owner.
    final kept = (await papers.getPaper(a.id))!;
    await highlights.createHighlight(hl('h2', kept));

    await signIn(userId);
    await engine.syncNow();
    expect((await papers.getPaper(a.id))!.syncState, SyncState.synced);
    expect(remote.highlights['h2']!['user_id'], userId);
    expect(await env.db.select(env.db.syncOutbox).get(), isEmpty);
  });

  test('reownPath only moves guest paths', () {
    expect(GuestDataMerge.reownPath('$kGuestUserId/p.pdf', 'u'), 'u/p.pdf');
    expect(GuestDataMerge.reownPath('x/p.pdf', 'u'), 'x/p.pdf');
    expect(GuestDataMerge.reownPath(null, 'u'), isNull);
  });

  test('URL import needs an account', () async {
    expect(
      () => papers.importFromUrl(Uri.parse('https://arxiv.org/pdf/1')),
      throwsA(isA<AuthExpiredException>()),
    );
  });
}
