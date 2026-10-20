import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:paper/domain/domain.dart';
import 'package:paper/features/reader/pdf_geometry.dart';

/// A one-line page "abc def" with 0.02-wide chars starting at x = 0.1.
ReaderPageText linePage(String text, {double y = 0.2, int page = 1}) =>
    ReaderPageText(
      pageNumber: page,
      text: text,
      charRects: <Rect>[
        for (var i = 0; i < text.length; i++)
          Rect.fromLTWH(0.1 + i * 0.02, y, 0.02, 0.02),
      ],
    );

Highlight hl(
  String id,
  HighlightColor color,
  List<HighlightRect> rects, {
  int page = 1,
}) => Highlight(
  id: id,
  userId: 'u',
  paperId: 'p',
  selectedText: id,
  createdAt: DateTime.utc(2026),
  pageNumber: page,
  color: color,
  position: HighlightPosition(
    pageNumber: page,
    rects: rects,
    textLayerScale: 1,
  ),
);

const HighlightRect a = HighlightRect(x: 0.1, y: 0.2, width: 0.3, height: 0.02);
const HighlightRect b = HighlightRect(x: 0.3, y: 0.2, width: 0.3, height: 0.02);
const HighlightRect nextLine = HighlightRect(
  x: 0.1,
  y: 0.25,
  width: 0.3,
  height: 0.02,
);

void main() {
  group('wash rects per hue', () {
    test('overlapping same-hue highlights merge into one rect', () {
      final wash = washRectsByHue(<Highlight>[
        hl('1', HighlightColor.yellow, <HighlightRect>[a]),
        hl('2', HighlightColor.yellow, <HighlightRect>[b]),
      ], 1);
      expect(wash.keys, <HighlightColor>[HighlightColor.yellow]);
      final rects = wash[HighlightColor.yellow]!;
      expect(rects, hasLength(1));
      expect(rects.single.left, closeTo(0.1, 1e-9));
      expect(rects.single.right, closeTo(0.6, 1e-9));
    });

    test('different hues stay in separate layers', () {
      final wash = washRectsByHue(<Highlight>[
        hl('1', HighlightColor.yellow, <HighlightRect>[a]),
        hl('2', HighlightColor.blue, <HighlightRect>[b]),
      ], 1);
      expect(wash.keys, <HighlightColor>[
        HighlightColor.yellow,
        HighlightColor.blue,
      ]);
      expect(wash[HighlightColor.yellow], hasLength(1));
      expect(wash[HighlightColor.blue], hasLength(1));
    });

    test('rects on different lines are not merged', () {
      final wash = washRectsByHue(<Highlight>[
        hl('1', HighlightColor.pink, <HighlightRect>[a, nextLine]),
      ], 1);
      expect(wash[HighlightColor.pink], hasLength(2));
    });

    test('only the requested page is included', () {
      final wash = washRectsByHue(<Highlight>[
        hl('1', HighlightColor.green, <HighlightRect>[a], page: 2),
      ], 1);
      expect(wash, isEmpty);
    });

    test('mergeOverlappingRects is transitive and sorted', () {
      final merged = mergeOverlappingRects(<Rect>[
        const Rect.fromLTWH(0.5, 0.2, 0.1, 0.02),
        const Rect.fromLTWH(0.1, 0.2, 0.2, 0.02),
        const Rect.fromLTWH(0.25, 0.2, 0.3, 0.02),
        const Rect.fromLTWH(0.1, 0.5, 0.1, 0.02),
      ]);
      expect(merged, hasLength(2));
      expect(merged.first.left, closeTo(0.1, 1e-9));
      expect(merged.first.right, closeTo(0.6, 1e-9));
    });
  });

  group('lines from char boxes', () {
    test('chars on one line merge, a new line starts a new rect', () {
      final rects = mergeCharRectsIntoLines(<Rect>[
        const Rect.fromLTWH(0.1, 0.2, 0.02, 0.02),
        const Rect.fromLTWH(0.12, 0.2, 0.02, 0.02),
        Rect.zero, // synthesised line break
        const Rect.fromLTWH(0.1, 0.25, 0.02, 0.02),
      ]);
      expect(rects, hasLength(2));
      expect(rects.first.left, closeTo(0.1, 1e-9));
      expect(rects.first.right, closeTo(0.14, 1e-9));
      expect(rects.last.top, closeTo(0.25, 1e-9));
    });

    test('a jump to another column starts a new rect', () {
      final rects = mergeCharRectsIntoLines(<Rect>[
        const Rect.fromLTWH(0.1, 0.2, 0.02, 0.02),
        const Rect.fromLTWH(0.6, 0.2, 0.02, 0.02),
      ]);
      expect(rects, hasLength(2));
    });
  });

  group('selection capture', () {
    test('builds normalised text, rects and context', () {
      final page = linePage('We use self-\nattention here');
      final start = page.text.indexOf('self');
      final end = page.text.indexOf(' here');
      final sel = selectionFromRange(page, start, end)!;
      expect(sel.text, 'selfattention');
      // Same as RPR extractContext: the separating spaces are kept.
      expect(sel.contextBefore, 'We use ');
      expect(sel.contextAfter, ' here');
      expect(sel.pageNumber, 1);
      expect(sel.rects, isNotEmpty);
      expect(sel.rects.first.y, 0.2);
    });

    test('whitespace-only ranges yield nothing', () {
      final page = linePage('a   b');
      expect(selectionFromRange(page, 1, 4), isNull);
    });

    test('normalizeSelectedText matches RPR', () {
      expect(
        normalizeSelectedText('  self-\n attention  is\tall '),
        'selfattention is all',
      );
      expect(normalizeSelectedText('state-of-the-art'), 'state-of-the-art');
    });

    test('context is capped at 200 chars', () {
      final long = 'x' * 500;
      final ctx = extractContext('$long WORD $long', 501, 505);
      expect(ctx.before.length, lessThanOrEqualTo(200));
      expect(ctx.after.length, lessThanOrEqualTo(200));
    });
  });

  test('stored rects are clamped to the page and rounded to 4 places', () {
    final r = rectToHighlightRect(
      const Rect.fromLTRB(-0.1, 0.123456, 0.5, 1.2),
    );
    expect(r.x, 0);
    expect(r.y, 0.1235);
    expect(r.width, 0.5);
    expect(r.height, 0.8765);
  });

  test('highlightAt returns the topmost hit', () {
    final hits = <Highlight>[
      hl('under', HighlightColor.yellow, <HighlightRect>[a]),
      hl('over', HighlightColor.blue, <HighlightRect>[a]),
    ];
    expect(highlightAt(hits, 1, const Offset(0.2, 0.21))?.id, 'over');
    expect(highlightAt(hits, 1, const Offset(0.9, 0.9)), isNull);
    expect(highlightAt(hits, 2, const Offset(0.2, 0.21)), isNull);
  });

  test('charIndexAt finds the char under a point', () {
    final page = linePage('hello');
    expect(page.charIndexAt(const Offset(0.131, 0.21)), 1);
    expect(page.charIndexAt(const Offset(0.5, 0.9)), -1);
  });
}
