import 'dart:async';

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper/domain/domain.dart';
import 'package:paper/features/reader/reader_controller.dart';

import 'reader_fakes.dart';

Future<void> settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late FakePaperRepository papers;
  late FakeHighlightRepository highlights;
  late ManualTimers timers;
  late ProviderContainer container;
  late ProviderSubscription<ReaderState> sub;

  final provider = readerControllerProvider('p1');
  ReaderState state() => container.read(provider);
  ReaderController ctrl() => container.read(provider.notifier);

  void boot() {
    container = ProviderContainer(
      overrides: readerTestOverrides(
        papers: papers,
        highlights: highlights,
        timers: timers,
        fakeViewport: false,
      ),
    );
    sub = container.listen(provider, (_, _) {});
  }

  setUp(() {
    papers = FakePaperRepository(paper: testPaper());
    highlights = FakeHighlightRepository();
    timers = ManualTimers();
  });

  tearDown(() {
    sub.close();
    container.dispose();
  });

  group('load phases', () {
    test('resolving -> opening -> ready', () async {
      boot();
      expect(state().phase, const ReaderResolving());
      await settle();
      expect(state().phase, const ReaderOpening('/tmp/paper.pdf'));
      expect(state().paper?.title, 'Attention Is All You Need');
      expect(papers.opened, 1);
      ctrl().documentLoaded(pageCount: 12);
      expect(state().phase, const ReaderReady('/tmp/paper.pdf'));
      expect(state().pageCount, 12);
      expect(state().isReady, isTrue);
    });

    test('reports download progress, then opens', () async {
      papers.download = Completer<String>();
      boot();
      await settle();
      papers.lastProgress!(0.25);
      expect(state().phase, const ReaderDownloading(0.25));
      papers.lastProgress!(1.4);
      expect(state().phase, const ReaderDownloading(1.0));
      papers.download!.complete('/cache/p1.pdf');
      await settle();
      expect(state().phase, const ReaderOpening('/cache/p1.pdf'));
    });

    test('missing paper -> paperDeleted', () async {
      papers.paper = null;
      boot();
      await settle();
      expect(
        state().phase,
        const ReaderLoadError(ReaderErrorKind.paperDeleted),
      );
    });

    test('offline and not downloaded -> offlineNotDownloaded', () async {
      papers.ensureError = const OfflineException();
      boot();
      await settle();
      expect(
        state().phase,
        const ReaderLoadError(ReaderErrorKind.offlineNotDownloaded),
      );
    });

    test('InvalidPdfException -> invalidPdf; retry recovers', () async {
      papers.ensureError = const InvalidPdfException();
      boot();
      await settle();
      expect(state().phase, const ReaderLoadError(ReaderErrorKind.invalidPdf));
      papers.ensureError = null;
      await ctrl().retry();
      expect(state().phase, const ReaderOpening('/tmp/paper.pdf'));
    });

    test('network failure -> downloadFailed', () async {
      papers.ensureError = const ServerException(503);
      boot();
      await settle();
      expect(
        state().phase,
        const ReaderLoadError(ReaderErrorKind.downloadFailed),
      );
    });

    test('pdfium open failure -> invalidPdf', () async {
      boot();
      await settle();
      ctrl().documentFailed(Exception('bad xref'));
      expect(state().phase, const ReaderLoadError(ReaderErrorKind.invalidPdf));
    });

    test('restores the reading position', () async {
      papers.paper = testPaper(
        position: ReadingPosition(
          pageNumber: 7,
          zoom: 1.5,
          updatedAt: DateTime.utc(2026),
        ),
      );
      boot();
      await settle();
      expect(state().currentPage, 7);
      expect(state().zoom, 1.5);
      expect(state().fit, ReaderFitMode.none);
      ctrl().documentLoaded(pageCount: 5);
      expect(state().currentPage, 5, reason: 'clamped to the page count');
    });
  });

  group('tools', () {
    setUp(boot);

    test('choosing the active tool again returns to Select', () {
      ctrl().setTool(ReaderTool.pen);
      expect(state().tool, ReaderTool.pen);
      ctrl().setTool(ReaderTool.pen);
      expect(state().tool, ReaderTool.select);
      ctrl().setTool(ReaderTool.select);
      expect(state().tool, ReaderTool.select);
    });

    test('switching tools clears popovers', () {
      ctrl().setSelection(_selection());
      expect(state().selection, isNotNull);
      ctrl().setTool(ReaderTool.figure);
      expect(state().selection, isNull);
      expect(state().tool, ReaderTool.figure);
    });

    test('stylus auto-switches Select to Pen once', () {
      expect(ctrl().stylusDetected(), isTrue);
      expect(state().tool, ReaderTool.pen);
      expect(ctrl().stylusDetected(), isFalse);
    });

    test('eraser toggles into Pen and Esc resets', () {
      ctrl().toggleEraser();
      expect(state().eraser, isTrue);
      expect(state().tool, ReaderTool.pen);
      expect(ctrl().escape(), isTrue);
      expect(state().eraser, isFalse);
      expect(state().tool, ReaderTool.select);
      expect(ctrl().escape(), isFalse);
    });

    test('Esc closes popover, then find bar, then overlay panel', () {
      ctrl()
        ..setSelection(_selection())
        ..openSearch()
        ..openPanel(ReaderPanelTab.glossary);
      expect(ctrl().escape(panelIsOverlay: true), isTrue);
      expect(state().selection, isNull);
      expect(state().search.open, isTrue);
      expect(ctrl().escape(panelIsOverlay: true), isTrue);
      expect(state().search.open, isFalse);
      expect(ctrl().escape(panelIsOverlay: true), isTrue);
      expect(state().panelOpen, isFalse);
    });
  });

  group('zoom', () {
    setUp(boot);

    test('clamps to 25–800%', () {
      ctrl().setZoom(20);
      expect(state().zoom, kMaxZoom);
      ctrl().setZoom(0.01);
      expect(state().zoom, kMinZoom);
      ctrl().zoomCommitted(double.nan);
      expect(state().zoom, 1.0);
    });

    test('steps through the zoom stops', () {
      ctrl().setZoom(1.0);
      ctrl().zoomIn();
      expect(state().zoom, 1.25);
      ctrl().zoomOut();
      ctrl().zoomOut();
      expect(state().zoom, 0.75);
      ctrl().setZoom(0.5);
      ctrl().zoomOut();
      expect(state().zoom, kMinZoom);
      ctrl().setZoom(4);
      ctrl().zoomIn();
      expect(state().zoom, kMaxZoom);
      ctrl().setZoom(1.1);
      ctrl().zoomIn();
      expect(state().zoom, 1.25, reason: 'from between stops to the next');
    });

    test('commands become one-shot viewport requests', () {
      ctrl().fitPage();
      final r1 = state().zoomRequest!;
      expect(r1.fit, ReaderFitMode.page);
      ctrl().resetZoom();
      final r2 = state().zoomRequest!;
      expect(r2.zoom, 1.0);
      expect(r2.fit, ReaderFitMode.none);
      expect(r2.serial, isNot(r1.serial));
    });
  });

  group('reading position save', () {
    test('debounces 1 s and saves the latest page + zoom once', () async {
      boot();
      await settle();
      ctrl().documentLoaded(pageCount: 20);
      ctrl().pageChanged(2);
      ctrl().pageChanged(3);
      ctrl().zoomCommitted(1.5);
      expect(papers.saved, isEmpty);
      expect(timers.active, hasLength(1));
      expect(timers.active.single.duration, kReadingPositionSaveDebounce);
      timers.active.single.fire();
      await settle();
      expect(papers.saved, hasLength(1));
      expect(papers.saved.single.pageNumber, 3);
      expect(papers.saved.single.zoom, 1.5);

      // Same position again: not re-saved.
      ctrl().pageChanged(4);
      ctrl().pageChanged(3);
      timers.active.single.fire();
      await settle();
      expect(papers.saved, hasLength(1));
    });

    test('fit width is stored as zoom null', () async {
      boot();
      await settle();
      ctrl().documentLoaded(pageCount: 20);
      ctrl().fitWidth();
      ctrl().pageChanged(9);
      timers.active.single.fire();
      await settle();
      expect(papers.saved.single.pageNumber, 9);
      expect(papers.saved.single.zoom, isNull);
    });

    test('a pending save is flushed on dispose', () async {
      boot();
      await settle();
      ctrl().documentLoaded(pageCount: 20);
      ctrl().pageChanged(6);
      sub.close();
      container.dispose();
      await settle();
      expect(papers.saved.single.pageNumber, 6);
      // tearDown disposes again: give it fresh objects.
      boot();
    });
  });

  group('highlights', () {
    setUp(boot);

    test('selection -> highlight in the stored RPR format', () async {
      await settle();
      final events = <ReaderEvent>[];
      final s = ctrl().events.listen(events.add);
      ctrl().setSelection(_selection());
      final h = await ctrl().highlightSelection(HighlightColor.green);
      await settle();
      expect(h, isNotNull);
      expect(state().selection, isNull);
      expect(state().highlightColor, HighlightColor.green);
      final saved = highlights.highlights.single;
      expect(saved.userId, 'u1');
      expect(saved.paperId, 'p1');
      expect(saved.selectedText, 'self-attention');
      expect(saved.pageNumber, 3);
      expect(saved.position!.pageNumber, 3);
      expect(saved.position!.textLayerScale, 1);
      expect(saved.position!.rects.single.x, 0.1);
      expect(saved.color, HighlightColor.green);
      expect(saved.contextBefore, 'We use');
      expect(saved.contextAfter, isNull);
      expect(events.single, isA<HighlightCreatedEvent>());
      await s.cancel();
    });

    test('save failure emits a retry event', () async {
      await settle();
      highlights.failCreate = true;
      final events = <ReaderEvent>[];
      final s = ctrl().events.listen(events.add);
      ctrl().setSelection(_selection());
      await ctrl().highlightSelection();
      await settle();
      expect(events.single, isA<HighlightSaveFailedEvent>());
      highlights.failCreate = false;
      await (events.single as HighlightSaveFailedEvent).retry();
      expect(highlights.highlights, hasLength(1));
      await s.cancel();
    });

    test('explain saves the highlight and opens the Explanation tab', () async {
      await settle();
      final events = <ReaderEvent>[];
      final s = ctrl().events.listen(events.add);
      ctrl().setSelection(_selection());
      await ctrl().explainSelection();
      await settle();
      expect(highlights.highlights, hasLength(1));
      expect(state().panelOpen, isTrue);
      expect(state().panelTab, ReaderPanelTab.explanation);
      final explain = events.whereType<ExplainRequestedEvent>().single;
      expect(explain.term, 'self-attention');
      expect(explain.highlight, isNotNull);
      await s.cancel();
    });

    test('jump to highlight remembers the return page and flashes', () async {
      await settle();
      ctrl().documentLoaded(pageCount: 20);
      ctrl().pageChanged(10);
      ctrl().jumpToHighlight(
        Highlight(
          id: 'h9',
          userId: 'u1',
          paperId: 'p1',
          selectedText: 'x',
          createdAt: DateTime.utc(2026),
          pageNumber: 2,
          position: const HighlightPosition(
            pageNumber: 2,
            rects: <HighlightRect>[
              HighlightRect(x: 0.1, y: 0.2, width: 0.3, height: 0.02),
            ],
          ),
        ),
      );
      expect(state().navRequest!.pageNumber, 2);
      expect(
        state().navRequest!.rect,
        const Rect.fromLTWH(0.1, 0.2, 0.3, 0.02),
      );
      expect(state().returnPage, 10);
      expect(state().flashHighlightId, 'h9');
      ctrl().returnToPreviousPage();
      expect(state().navRequest!.pageNumber, 10);
      expect(state().returnPage, isNull);
    });
  });
}

ReaderTextSelection _selection() => const ReaderTextSelection(
  pageNumber: 3,
  text: 'self-attention',
  rects: <HighlightRect>[
    HighlightRect(x: 0.1, y: 0.2, width: 0.3, height: 0.02),
  ],
  contextBefore: 'We use',
);
