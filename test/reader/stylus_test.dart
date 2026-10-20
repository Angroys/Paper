import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:paper/domain/domain.dart';
import 'package:paper/features/reader/pdf_geometry.dart';
import 'package:paper/features/reader/reader_state.dart';
import 'package:paper/features/reader/stylus.dart';

/// Two lines: "first line" at y 0.20–0.22 and "second one" at 0.25–0.27,
/// joined by a synthesised newline without a box.
ReaderPageText twoLines() {
  const l1 = 'first line';
  const l2 = 'second one';
  final rects = <Rect>[
    for (var i = 0; i < l1.length; i++)
      Rect.fromLTWH(0.1 + i * 0.02, 0.20, 0.02, 0.02),
    Rect.zero,
    for (var i = 0; i < l2.length; i++)
      Rect.fromLTWH(0.1 + i * 0.02, 0.25, 0.02, 0.02),
  ];
  return ReaderPageText(pageNumber: 1, text: '$l1\n$l2', charRects: rects);
}

const double half = 0.01; // stroke half-height (normalised)

void main() {
  group('snapStrokeToText', () {
    test('a stroke along a line snaps to the chars under it', () {
      final page = twoLines();
      final range = snapStrokeToText(
        const <Offset>[Offset(0.105, 0.21), Offset(0.185, 0.21)],
        page,
        halfWidth: half,
      )!;
      expect(page.text.substring(range.start, range.end), 'first');
    });

    test('a sparse fast stroke is densified (no gaps)', () {
      final page = twoLines();
      final range = snapStrokeToText(
        const <Offset>[Offset(0.1, 0.21), Offset(0.3, 0.21)],
        page,
        halfWidth: half,
      )!;
      expect(page.text.substring(range.start, range.end), 'first line');
    });

    test('a diagonal stroke spans both lines in text order', () {
      final page = twoLines();
      final range = snapStrokeToText(
        const <Offset>[Offset(0.25, 0.21), Offset(0.15, 0.26)],
        page,
        halfWidth: half,
      )!;
      expect(page.text.substring(range.start, range.end), 'line\nseco');
    });

    test('a stroke grazing the gap between lines selects nothing', () {
      final page = twoLines();
      final range = snapStrokeToText(
        const <Offset>[Offset(0.1, 0.235), Offset(0.3, 0.235)],
        page,
        halfWidth: 0.004,
      );
      expect(range, isNull);
    });

    test('a stroke over a figure (no text) is freeform ink', () {
      expect(
        snapStrokeToText(
          const <Offset>[Offset(0.5, 0.7), Offset(0.8, 0.75)],
          twoLines(),
          halfWidth: half,
        ),
        isNull,
      );
      expect(
        snapStrokeToText(const <Offset>[], twoLines(), halfWidth: half),
        isNull,
      );
    });

    test('the snapped range becomes a stored highlight selection', () {
      final page = twoLines();
      final range = snapStrokeToText(
        const <Offset>[Offset(0.1, 0.26), Offset(0.3, 0.26)],
        page,
        halfWidth: half,
      )!;
      final sel = selectionFromRange(page, range.start, range.end)!;
      expect(sel.text, 'second one');
      expect(sel.rects, hasLength(1));
      expect(sel.rects.single.y, 0.25);
      expect(sel.contextBefore, 'first line ');
    });
  });

  test('densifyStroke inserts points', () {
    final pts = densifyStroke(
      const <Offset>[Offset.zero, Offset(1, 0)],
      step: 0.25,
    );
    expect(pts, hasLength(5));
    expect(pts.last, const Offset(1, 0));
  });

  test('eraser finds highlights under the stroke', () {
    final h = Highlight(
      id: 'h1',
      userId: 'u',
      paperId: 'p',
      selectedText: 'x',
      createdAt: DateTime.utc(2026),
      pageNumber: 1,
      position: const HighlightPosition(
        pageNumber: 1,
        rects: <HighlightRect>[
          HighlightRect(x: 0.1, y: 0.2, width: 0.2, height: 0.02),
        ],
      ),
    );
    expect(
      highlightsUnderStroke(
        const <Offset>[Offset(0.15, 0.1), Offset(0.15, 0.3)],
        <Highlight>[h],
        1,
        halfWidth: 0.005,
      ),
      <String>['h1'],
    );
    expect(
      highlightsUnderStroke(
        const <Offset>[Offset(0.5, 0.1), Offset(0.5, 0.3)],
        <Highlight>[h],
        1,
        halfWidth: 0.005,
      ),
      isEmpty,
    );
  });

  group('palm rejection', () {
    test('touch is rejected while the stylus is down and 300 ms after', () {
      final palm = PalmRejection();
      const t0 = Duration(seconds: 1);
      expect(palm.shouldRejectTouch(t0), isFalse);
      palm.stylusDown(7);
      expect(palm.shouldRejectTouch(t0), isTrue);
      palm.stylusUp(7, t0);
      expect(
        palm.shouldRejectTouch(t0 + const Duration(milliseconds: 299)),
        isTrue,
      );
      expect(
        palm.shouldRejectTouch(t0 + const Duration(milliseconds: 301)),
        isFalse,
      );
    });

    test('hovering stylus (proximity) also rejects touch', () {
      final palm = PalmRejection()..stylusHover(const Duration(seconds: 2));
      expect(
        palm.shouldRejectTouch(const Duration(milliseconds: 2100)),
        isTrue,
      );
    });
  });

  group('routePointer', () {
    InputRoute route(
      ReaderTool tool,
      PointerDeviceKind kind, {
      bool eraser = false,
      bool reject = false,
    }) => routePointer(
      tool: tool,
      kind: kind,
      eraser: eraser,
      rejectTouch: reject,
    );

    test('pen mode: stylus inks, finger and mouse go to the viewer', () {
      expect(route(ReaderTool.pen, PointerDeviceKind.stylus), InputRoute.ink);
      expect(route(ReaderTool.pen, PointerDeviceKind.touch), InputRoute.viewer);
      expect(route(ReaderTool.pen, PointerDeviceKind.mouse), InputRoute.viewer);
      expect(
        route(ReaderTool.pen, PointerDeviceKind.stylus, eraser: true),
        InputRoute.erase,
      );
    });

    test('inverted stylus erases outside figure mode', () {
      expect(
        route(ReaderTool.select, PointerDeviceKind.invertedStylus),
        InputRoute.erase,
      );
      expect(
        route(ReaderTool.figure, PointerDeviceKind.invertedStylus),
        InputRoute.figure,
      );
    });

    test('palm-rejected touches are dropped in every mode', () {
      for (final tool in ReaderTool.values) {
        expect(
          route(tool, PointerDeviceKind.touch, reject: true),
          InputRoute.reject,
        );
      }
    });

    test('highlight and figure modes capture finger + mouse drags', () {
      expect(route(ReaderTool.highlight, PointerDeviceKind.touch), InputRoute.ink);
      expect(route(ReaderTool.highlight, PointerDeviceKind.mouse), InputRoute.ink);
      expect(route(ReaderTool.figure, PointerDeviceKind.mouse), InputRoute.figure);
      expect(
        route(ReaderTool.figure, PointerDeviceKind.trackpad),
        InputRoute.viewer,
      );
      expect(route(ReaderTool.select, PointerDeviceKind.stylus), InputRoute.viewer);
    });
  });
}
