import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:paper/domain/domain.dart';

/// Encodes to a JSON string and back, like SQLite/HTTP storage would.
Map<String, Object?> _wire(Map<String, Object?> json) =>
    (jsonDecode(jsonEncode(json)) as Map<String, Object?>);

final _t0 = DateTime.utc(2026, 10, 1, 12, 30);
final _t1 = DateTime.utc(2026, 10, 2, 8);

void main() {
  test('Paper round-trips with device-only fields', () {
    final paper = Paper(
      id: 'p1',
      userId: 'u1',
      title: 'Attention Is All You Need',
      storagePath: 'u1/p1.pdf',
      fileName: 'attention.pdf',
      uploadedAt: _t0,
      readAt: _t1,
      sourceUrl: 'https://doi.org/10.1/x',
      autoMatched: true,
      localFilePath: '/data/p1.pdf',
      downloadState: DownloadState.downloaded,
      readingPosition: ReadingPosition(
        pageNumber: 4,
        zoom: 1.25,
        updatedAt: _t1,
      ),
      lastOpenedAt: _t1,
      syncState: SyncState.pendingUpdate,
      localUpdatedAt: _t1,
    );
    expect(Paper.fromJson(_wire(paper.toJson())), paper);
    expect(paper.showMatchNotice, isTrue);
  });

  test('Paper reads a Supabase row and writes only server columns', () {
    final row = <String, Object?>{
      'id': 'p2',
      'user_id': 'u1',
      'title': 'Linkless',
      'storage_path': null,
      'file_name': null,
      'uploaded_at': '2026-10-01T12:30:00+00:00',
      'read_at': null,
      'added_from_paper_id': 'p1',
      'source_url': null,
      'auto_matched': false,
      'match_notice_dismissed_at': null,
    };
    final paper = Paper.fromJson(row);
    expect(paper.isLinkless, isTrue);
    expect(paper.uploadedAt, _t0);
    expect(paper.syncState, SyncState.synced);
    expect(paper.downloadState, DownloadState.notDownloaded);
    expect(paper.toSupabaseRow().keys, unorderedEquals(row.keys));
  });

  test('Highlight round-trips; server rows default to yellow', () {
    final h = Highlight(
      id: 'h1',
      userId: 'u1',
      paperId: 'p1',
      selectedText: 'self-attention',
      contextBefore: 'we use ',
      contextAfter: ' layers',
      pageNumber: 3,
      position: const HighlightPosition(
        pageNumber: 3,
        rects: <HighlightRect>[
          HighlightRect(x: 10, y: 20.5, width: 100, height: 12),
        ],
        textLayerScale: 1.5,
      ),
      createdAt: _t0,
      color: HighlightColor.purple,
      localUpdatedAt: _t1,
      syncState: SyncState.pendingCreate,
    );
    expect(Highlight.fromJson(_wire(h.toJson())), h);

    final serverRow = _wire(h.toSupabaseRow());
    expect(serverRow.containsKey('color'), isFalse);
    final fromServer = Highlight.fromJson(serverRow);
    expect(fromServer.color, HighlightColor.yellow);
    expect(fromServer.position, h.position);
  });

  test('FigureHighlight round-trips', () {
    final f = FigureHighlight(
      id: 'f1',
      userId: 'u1',
      paperId: 'p1',
      pageNumber: 2,
      bbox: const FigureBBox(x: 0.1, y: 0.2, width: 0.5, height: 0.3),
      label: 'Figure 1',
      caption: 'The Transformer',
      note: 'encoder left',
      storagePath: 'u1/f1.png',
      createdAt: _t0,
      updatedAt: _t1,
      localImagePath: '/data/f1.png',
      syncState: SyncState.pendingUpdate,
    );
    expect(FigureHighlight.fromJson(_wire(f.toJson())), f);
    expect(f.copyWith(note: null).note, isNull);
  });

  test('Note round-trips and defaults to localOnly', () {
    final n = Note(
      id: 'n1',
      paperId: 'p1',
      highlightId: 'h1',
      pageNumber: 3,
      body: 'Check eq. 2',
      createdAt: _t0,
      updatedAt: _t1,
    );
    expect(n.syncState, SyncState.localOnly);
    expect(Note.fromJson(_wire(n.toJson())), n);
    final orphan = n.copyWith(highlightId: null, quotedExcerpt: 'self-attn');
    expect(orphan.isPageNote, isTrue);
    expect(Note.fromJson(_wire(orphan.toJson())), orphan);
  });

  test('GlossaryTerm round-trips (null rating = unrated)', () {
    final g = GlossaryTerm(
      id: 'g1',
      userId: 'u1',
      paperId: 'p1',
      highlightId: 'h1',
      term: 'Softmax',
      normalizedTerm: 'softmax',
      explanation: 'Turns scores into probabilities.',
      tags: const <String>['method', 'nlp'],
      createdAt: _t0,
    );
    expect(GlossaryTerm.fromJson(_wire(g.toJson())), g);
    expect(g.rating, isNull);
  });

  test('Explanation and VisualAid round-trip; request body is camelCase', () {
    final e = Explanation(
      term: 'BLEU',
      explanation: 'A translation score.',
      createdAt: _t0,
      paperId: 'p1',
      fromCache: true,
    );
    expect(Explanation.fromJson(_wire(e.toJson())), e);
    const v = VisualAid(term: 'BLEU', videoUrl: 'https://x/v.mp4');
    expect(VisualAid.fromJson(_wire(v.toJson())), v);
    expect(
      const ExplanationRequest(term: 'BLEU', contextBefore: 'the').toApiJson(),
      <String, Object?>{'term': 'BLEU', 'contextBefore': 'the'},
    );
  });

  test('SyncOp and ReplacedVersion round-trip', () {
    final op = SyncOp(
      id: 'o1',
      entity: SyncEntity.figureHighlight,
      entityId: 'f1',
      kind: SyncOpKind.update,
      payload: const <String, Object?>{
        'note': 'x',
        'bbox': <String, Object?>{'x': 0.1},
      },
      createdAt: _t0,
      localUpdatedAt: _t1,
      deviceId: 'd1',
      attempts: 2,
      lastError: '500',
    );
    expect(SyncOp.fromJson(_wire(op.toJson())), op);

    final r = ReplacedVersion(
      id: 'r1',
      entity: SyncEntity.paper,
      entityId: 'p1',
      mine: const <String, Object?>{'title': 'Mine'},
      mineUpdatedAt: _t0,
      theirsUpdatedAt: _t1,
      replacedAt: _t1,
    );
    expect(ReplacedVersion.fromJson(_wire(r.toJson())), r);
  });

  test('SyncState names are stable', () {
    expect(SyncState.fromName('pendingDelete'), SyncState.pendingDelete);
    expect(SyncState.fromName(null), SyncState.synced);
    expect(SyncState.pendingCreate.isPending, isTrue);
    expect(SyncState.localOnly.isPending, isFalse);
  });

  test('AiResult is exhaustively switchable', () {
    String describe(AiResult<int> r) => switch (r) {
      AiSuccess(:final value) => 'ok $value',
      AiUnavailable(:final reason) => 'unavailable ${reason.name}',
      AiFailure(:final message) => 'failed $message',
    };
    expect(describe(const AiSuccess(1)), 'ok 1');
    expect(
      describe(const AiUnavailable(AiUnavailableReason.rejected)),
      'unavailable rejected',
    );
  });
}
