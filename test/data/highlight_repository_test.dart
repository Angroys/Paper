import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:paper/data/local_highlight_repository.dart';
import 'package:paper/data/local_note_repository.dart';
import 'package:paper/domain/domain.dart';

import 'fakes.dart';

const paperId = '44444444-4444-4444-8444-444444444444';

Highlight highlight(String id) => Highlight(
  id: id,
  userId: '',
  paperId: paperId,
  selectedText: 'softmax',
  pageNumber: 3,
  position: const HighlightPosition(
    pageNumber: 3,
    rects: [HighlightRect(x: 1, y: 2, width: 3, height: 4)],
  ),
  createdAt: DateTime.utc(2026, 10, 20),
);

void main() {
  late TestEnv env;
  late LocalHighlightRepository repo;
  late LocalNoteRepository notes;

  setUp(() {
    env = TestEnv();
    repo = LocalHighlightRepository(
      store: env.store,
      currentUserId: () => userId,
    );
    notes = LocalNoteRepository(store: env.store);
  });
  tearDown(() => env.dispose());

  Future<List<String>> opKinds() async => [
    for (final o in await env.db.select(env.db.syncOutbox).get())
      '${o.entity}.${o.kind}',
  ];

  test('create queues a create with server columns only', () async {
    final h = await repo.createHighlight(highlight('h1'));
    expect(h.userId, userId);
    expect(h.syncState, SyncState.pendingCreate);
    final op = (await env.db.select(env.db.syncOutbox).get()).single;
    expect(op.kind, 'create');
    expect(op.payload, isNot(contains('color')));
    expect(op.payload, isNot(contains('sync_state')));
    expect((await repo.watchHighlights(paperId).first).single.id, 'h1');
  });

  test('colour change is device-only', () async {
    await repo.createHighlight(highlight('h1'));
    await env.db.delete(env.db.syncOutbox).go();
    await repo.updateColor('h1', HighlightColor.pink);
    expect(await opKinds(), isEmpty);
    expect(
      (await repo.watchHighlights(paperId).first).single.color,
      HighlightColor.pink,
    );
  });

  test('delete hides and queues; restore cancels the queued delete', () async {
    final h = await repo.createHighlight(highlight('h1'));
    await repo.deleteHighlight('h1');
    expect(await repo.watchHighlights(paperId).first, isEmpty);
    expect(await opKinds(), ['highlight.create', 'highlight.delete']);
    await repo.restoreHighlight(h);
    expect(await opKinds(), ['highlight.create']);
    expect(
      (await repo.watchHighlights(paperId).first).single.syncState,
      SyncState.pendingCreate,
    );
  });

  test(
    'figure create writes the PNG and queues; note edit coalesces',
    () async {
      final f = await repo.createFigureHighlight(
        FigureHighlight(
          id: 'f1',
          userId: '',
          paperId: paperId,
          pageNumber: 2,
          bbox: const FigureBBox(x: 0.1, y: 0.1, width: 0.5, height: 0.3),
          storagePath: '',
          createdAt: env.clock.now,
          updatedAt: env.clock.now,
        ),
        pngBytes: Uint8List.fromList([137, 80, 78, 71]),
      );
      expect(f.storagePath, '$userId/$paperId/f1.png');
      expect(f.localImagePath, isNotNull);
      await repo.updateFigureNote('f1', 'nice plot');
      expect(await opKinds(), ['figureHighlight.create']);
      expect(
        (await repo.watchFigureHighlights(paperId).first).single.note,
        'nice plot',
      );
    },
  );

  test('notes are local-only, never queued, export as text', () async {
    final now = env.clock.now;
    await notes.upsertNote(
      Note(
        id: 'n1',
        paperId: paperId,
        highlightId: 'h1',
        pageNumber: 3,
        body: 'key insight',
        createdAt: now,
        updatedAt: now,
      ),
    );
    expect(await opKinds(), isEmpty);
    expect(await notes.countLocalOnlyNotes(), 1);
    expect(
      (await notes.watchNotesForHighlight('h1').first).single.body,
      'key insight',
    );
    expect(await notes.exportAllAsText(), contains('p. 3: key insight'));
    await notes.deleteNote('n1');
    expect(await notes.countLocalOnlyNotes(), 0);
  });
}
