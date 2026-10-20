import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/domain.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/motion_extras.dart';
import '../../theme/paper_tokens.dart';
import '../../theme/theme_x.dart';
import 'citations.dart';
import 'pdf_geometry.dart';
import 'reader_controller.dart';
import 'stylus.dart';
import 'widgets/figure_popover.dart';
import 'widgets/highlight_layer.dart';
import 'widgets/input_capture.dart';
import 'widgets/page_overlay.dart';

/// What the reader screen hands the viewport.
@immutable
class ReaderViewportArgs {
  const ReaderViewportArgs({
    required this.paperId,
    required this.filePath,
    this.onScrollDelta,
  });

  final String paperId;
  final String filePath;

  /// Vertical content movement in logical px (positive = content moved up,
  /// i.e. the user scrolled down). Drives toolbar auto-hide (motion #26).
  final ValueChanged<double>? onScrollDelta;

  @override
  bool operator ==(Object other) =>
      other is ReaderViewportArgs &&
      other.paperId == paperId &&
      other.filePath == filePath;

  @override
  int get hashCode => Object.hash(paperId, filePath);
}

/// Builds the PDF viewport. The default is the pdfrx implementation; widget
/// tests override this provider with a fake (pdfium does not run there).
typedef ReaderViewportBuilder =
    Widget Function(BuildContext context, ReaderViewportArgs args);

final readerViewportBuilderProvider = Provider<ReaderViewportBuilder>(
  (ref) =>
      (context, args) => PdfReaderViewport(key: ValueKey(args), args: args),
);

/// Ink stroke height at 100% zoom (components.md InkLayer).
const double kInkStrokeWidth = 14;

/// Page-indicator update throttle during scroll (reader spec: ≤ every 100ms).
const Duration kPageIndicatorThrottle = Duration(milliseconds: 100);

/// Popovers reappear this long after the page stops moving (motion #12).
const Duration kOverlaySettle = Duration(milliseconds: 150);

/// The pdfrx-backed `PdfViewport` (reader spec region 2).
///
/// Performance contract (motion.md §1):
/// - The whole viewer sits behind one [RepaintBoundary] (B1) inside a fixed
///   size box from the parent's `LayoutBuilder`, so chrome never relayouts
///   it. pdfrx keeps page rasters as cached images and draws them through
///   its transform during pan / pinch (no pdfium call mid-gesture) and
///   re-renders tiles after the gesture settles.
/// - Highlight washes are a static per-page layer ([HighlightWashLayer]),
///   flashes / rings a separate per-page layer ([PageInteractionOverlay],
///   B3), the live stroke its own layer ([InkLayer], B4).
/// - No Opacity / BackdropFilter / ShaderMask / Hero anywhere in here.
class PdfReaderViewport extends ConsumerStatefulWidget {
  const PdfReaderViewport({super.key, required this.args});

  final ReaderViewportArgs args;

  @override
  ConsumerState<PdfReaderViewport> createState() => _PdfReaderViewportState();
}

class _PdfReaderViewportState extends ConsumerState<PdfReaderViewport> {
  final PdfViewerController _pdf = PdfViewerController();
  late final PdfTextSearcher _searcher = PdfTextSearcher(_pdf)
    ..addListener(_onSearchChanged);
  final LiveStroke _stroke = LiveStroke();
  final PalmRejection _palm = PalmRejection();
  final Map<int, ReaderPageText> _texts = <int, ReaderPageText>{};
  final Map<int, Future<ReaderPageText?>> _textLoads =
      <int, Future<ReaderPageText?>>{};
  Future<List<ReferenceEntry>>? _references;

  Timer? _pageThrottle;
  int? _pendingPage;
  Timer? _settleTimer;
  Timer? _pickerAutoHide;
  Matrix4? _lastMatrix;
  double? _lastAppliedZoom;
  bool _ready = false;
  int _initialPage = 1;
  Offset? _lastDownLocal;
  bool _stylusHintShown = false;

  /// Figure rectangle awaiting Save / Cancel (page + normalised bbox).
  ({int page, Rect bbox})? _pendingFigure;
  Rect? _pendingFigureLocal;

  // Wash cache: recomputed only when the highlight lists change.
  List<Highlight>? _washSourceHighlights;
  List<FigureHighlight>? _washSourceFigures;
  final Map<int, PageWash> _washCache = <int, PageWash>{};

  ReaderController get _ctrl =>
      ref.read(readerControllerProvider(widget.args.paperId).notifier);
  ReaderState get _state =>
      ref.read(readerControllerProvider(widget.args.paperId));

  @override
  void initState() {
    super.initState();
    _initialPage = _state.currentPage;
    _pdf.addListener(_onMatrixChanged);
  }

  @override
  void dispose() {
    _pdf.removeListener(_onMatrixChanged);
    _pageThrottle?.cancel();
    _settleTimer?.cancel();
    _pickerAutoHide?.cancel();
    _searcher
      ..removeListener(_onSearchChanged)
      ..dispose();
    _stroke.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------
  // Viewer callbacks
  // -------------------------------------------------------------------

  /// pdfrx may call back while it is building / laying out; provider state
  /// must not change then, so viewer-originated updates go through here.
  void _defer(VoidCallback f) => scheduleMicrotask(() {
    if (mounted) f();
  });

  void _onViewerReady(PdfDocument document, PdfViewerController controller) {
    _ready = true;
    _defer(() {
      _ctrl.documentLoaded(pageCount: document.pages.length);
      final s = _state;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_applyZoom(s.zoom, s.fit, animate: false));
      });
      unawaited(_detectTextLayer(document.pages.length));
    });
  }

  Future<void> _detectTextLayer(int pageCount) async {
    final probe = math.min(3, pageCount);
    for (var p = 1; p <= probe; p++) {
      final t = await _pageText(p);
      if (t != null && !t.isEmpty) {
        _ctrl.setTextLayerAvailable(true);
        return;
      }
    }
    if (mounted) _ctrl.setTextLayerAvailable(false);
  }

  void _onPageChanged(int? page) {
    if (page == null) return;
    _pendingPage = page;
    if (_pageThrottle?.isActive ?? false) return;
    _defer(() => _ctrl.pageChanged(page));
    _pageThrottle = Timer(kPageIndicatorThrottle, () {
      final p = _pendingPage;
      if (p != null && mounted) _ctrl.pageChanged(p);
    });
    // Prefetch text for hit-testing citations / strokes on nearby pages.
    for (final p in <int>[page, page + 1, page - 1]) {
      if (p >= 1 && _ready && p <= _pdf.pageCount) unawaited(_pageText(p));
    }
  }

  void _onMatrixChanged() {
    if (!_ready) return;
    final m = _pdf.value;
    final last = _lastMatrix;
    _lastMatrix = m.clone();
    if (last != null) {
      final dy = last.getTranslation().y - m.getTranslation().y;
      if (dy != 0) widget.args.onScrollDelta?.call(dy);
    }
    final s = _state;
    if (s.hasPopover && !s.overlaysHidden) {
      _defer(() => _ctrl.setOverlaysHidden(true));
    }
    _settleTimer?.cancel();
    _settleTimer = Timer(kOverlaySettle, _onSettled);
  }

  /// The page stopped moving: re-anchor popovers, commit wheel zoom.
  void _onSettled() {
    if (!mounted || !_ready) return;
    final s = _state;
    final zoom = _pdf.currentZoom;
    final applied = _lastAppliedZoom;
    if (!s.gestureInProgress &&
        (applied == null || (zoom - applied).abs() > 0.01)) {
      _lastAppliedZoom = zoom;
      _ctrl.zoomCommitted(zoom);
    }
    _refreshAnchors();
    if (s.overlaysHidden) _ctrl.setOverlaysHidden(false);
  }

  void _onInteractionStart(ScaleStartDetails d) {
    _ctrl.setGestureInProgress(true);
  }

  void _onInteractionEnd(ScaleEndDetails d) {
    _ctrl.setGestureInProgress(false);
    final zoom = _pdf.currentZoom;
    if ((zoom - (_lastAppliedZoom ?? _state.zoom)).abs() > 0.01) {
      _lastAppliedZoom = zoom;
      _ctrl.zoomCommitted(zoom);
    }
  }

  // -------------------------------------------------------------------
  // Coordinates
  // -------------------------------------------------------------------

  Rect? _pageLayout(int pageNumber) {
    if (!_ready || pageNumber < 1 || pageNumber > _pdf.pageCount) return null;
    return _pdf.layout.pageLayouts[pageNumber - 1];
  }

  /// Page-normalised rect -> viewer-local rect.
  Rect? _normToLocal(int pageNumber, Rect norm) {
    final pl = _pageLayout(pageNumber);
    if (pl == null) return null;
    final doc = Rect.fromLTRB(
      pl.left + norm.left * pl.width,
      pl.top + norm.top * pl.height,
      pl.left + norm.right * pl.width,
      pl.top + norm.bottom * pl.height,
    );
    return Rect.fromPoints(
      _pdf.documentToLocal(doc.topLeft),
      _pdf.documentToLocal(doc.bottomRight),
    );
  }

  /// Viewer-local point -> (page, page-normalised point), or null off-page.
  ({int page, Offset point})? _localToNorm(Offset local, {int? page}) {
    if (!_ready) return null;
    final doc = _pdf.localToDocument(local);
    final layouts = _pdf.layout.pageLayouts;
    var index = -1;
    if (page != null) {
      index = page - 1;
    } else {
      for (var i = 0; i < layouts.length; i++) {
        if (layouts[i].contains(doc)) {
          index = i;
          break;
        }
      }
    }
    if (index < 0 || index >= layouts.length) return null;
    final pl = layouts[index];
    return (
      page: index + 1,
      point: Offset(
        (doc.dx - pl.left) / pl.width,
        (doc.dy - pl.top) / pl.height,
      ),
    );
  }

  ReaderAnchor _anchor(int page, Rect norm) => ReaderAnchor(
    pageNumber: page,
    rect: norm,
    local: _normToLocal(page, norm),
  );

  void _refreshAnchors() {
    final s = _state;
    final sel = s.selection;
    if (sel?.anchor != null) {
      final a = sel!.anchor!;
      _ctrl.updateSelectionAnchor(_anchor(a.pageNumber, a.rect));
    }
    final ha = s.selectedHighlightAnchor;
    if (ha != null) _ctrl.updateHighlightAnchor(_anchor(ha.pageNumber, ha.rect));
    final c = s.citation;
    if (c != null) {
      _ctrl.updateCitationAnchor(_anchor(c.anchor.pageNumber, c.anchor.rect));
    }
    final f = _pendingFigure;
    if (f != null) {
      setState(() => _pendingFigureLocal = _normToLocal(f.page, f.bbox));
    }
  }

  // -------------------------------------------------------------------
  // Page text
  // -------------------------------------------------------------------

  Future<ReaderPageText?> _pageText(int pageNumber) {
    final cached = _texts[pageNumber];
    if (cached != null) return Future<ReaderPageText?>.value(cached);
    return _textLoads[pageNumber] ??= _loadText(pageNumber);
  }

  Future<ReaderPageText?> _loadText(int pageNumber) async {
    try {
      final page = _pdf.pages[pageNumber - 1];
      final text = await page.loadStructuredText();
      final t = _toReaderText(page, text);
      _texts[pageNumber] = t;
      return t;
    } on Object {
      return null;
    } finally {
      _textLoads.remove(pageNumber)?.ignore();
    }
  }

  ReaderPageText _toReaderText(PdfPage page, PdfPageText text) {
    final n = math.min(text.fullText.length, text.charRects.length);
    final rects = List<Rect>.generate(n, (i) {
      final r = text.charRects[i].toRect(page: page);
      return Rect.fromLTRB(
        r.left / page.width,
        r.top / page.height,
        r.right / page.width,
        r.bottom / page.height,
      );
    });
    return ReaderPageText(
      pageNumber: page.pageNumber,
      text: text.fullText.substring(0, n),
      charRects: rects,
    );
  }

  Future<List<ReferenceEntry>> _loadReferences() async {
    final count = _pdf.pageCount;
    final pages = <({int pageNumber, String text})>[];
    // References live at the end; read up to 20 trailing pages.
    for (var p = math.max(1, count - 19); p <= count; p++) {
      final t = await _pageText(p);
      if (t != null) pages.add((pageNumber: p, text: t.text));
    }
    return parseReferences(pages);
  }

  // -------------------------------------------------------------------
  // Selection (Select tool, pdfrx text selection)
  // -------------------------------------------------------------------

  Future<void> _onTextSelectionChange(PdfTextSelection selection) async {
    if (!selection.hasSelectedText) {
      _ctrl.clearSelection();
      return;
    }
    final ranges = await selection.getSelectedTextRanges();
    if (!mounted || ranges.isEmpty) return;
    // RPR highlights are single-page: keep the page with the most text.
    final range = ranges.reduce(
      (a, b) => (b.end - b.start) > (a.end - a.start) ? b : a,
    );
    final page = _pdf.pages[range.pageNumber - 1];
    final text = _texts[range.pageNumber] ??= _toReaderText(
      page,
      range.pageText,
    );
    final sel = selectionFromRange(text, range.start, range.end);
    if (sel == null) {
      _ctrl.clearSelection();
      return;
    }
    final a = sel.anchor!;
    _ctrl.setSelection(sel.withAnchor(_anchor(a.pageNumber, a.rect)));
  }

  // -------------------------------------------------------------------
  // Taps: highlights, citations
  // -------------------------------------------------------------------

  bool _onGeneralTap(
    BuildContext context,
    PdfViewerController controller,
    PdfViewerGeneralTapHandlerDetails details,
  ) {
    if (details.type != PdfViewerGeneralTapType.tap) return false;
    final hit = _localToNorm(details.localPosition);
    final s = _state;
    if (hit == null) {
      if (s.hasPopover) _ctrl.escape();
      return false;
    }
    final highlights = _highlights();
    final h = highlightAt(highlights, hit.page, hit.point);
    if (h != null) {
      final bounds = boundsOf(highlightRectsOnPage(h, hit.page))!;
      _ctrl.selectHighlight(h.id, anchor: _anchor(hit.page, bounds));
      return true;
    }
    final text = _texts[hit.page];
    if (text == null) {
      unawaited(_pageText(hit.page));
    } else if (s.hasTextLayer) {
      final index = text.charIndexAt(hit.point);
      final marker = index < 0 ? null : citationMarkerAt(text.text, index);
      if (marker != null) {
        unawaited(_showCitation(text, marker));
        return true;
      }
    }
    if (s.hasPopover) {
      _ctrl.escape();
      return true;
    }
    return false;
  }

  Future<void> _showCitation(
    ReaderPageText text,
    CitationMarker marker, {
    int? linkPage,
    Uri? url,
  }) async {
    final rects = mergeCharRectsIntoLines(
      text.charRects.sublist(marker.start, marker.end),
    );
    final bounds = boundsOf(rects) ?? Rect.zero;
    final anchor = _anchor(text.pageNumber, bounds);
    final loading = _references == null;
    _ctrl.showCitation(
      ReaderCitationTarget(
        label: marker.raw,
        anchor: anchor,
        targetPage: linkPage,
        url: url,
        resolving: loading,
      ),
    );
    final refs = await (_references ??= _loadReferences());
    if (!mounted) return;
    final entries = resolveCitation(marker, refs);
    final current = _state.citation;
    if (current == null || current.label != marker.raw) return;
    _ctrl.showCitation(
      ReaderCitationTarget(
        label: marker.raw,
        anchor: current.anchor,
        referenceText: entries.isEmpty
            ? null
            : entries.map((e) => e.text).join('\n\n'),
        targetPage: linkPage ?? entries.firstOrNull?.pageNumber,
        url: url,
      ),
    );
  }

  void _onLinkTap(PdfLink link) {
    final down = _lastDownLocal;
    final hit = down == null ? null : _localToNorm(down);
    final dest = link.dest;
    if (hit != null) {
      final text = _texts[hit.page];
      final index = text?.charIndexAt(hit.point) ?? -1;
      final marker = (text == null || index < 0)
          ? null
          : citationMarkerAt(text.text, index);
      if (text != null && marker != null) {
        unawaited(
          _showCitation(text, marker, linkPage: dest?.pageNumber, url: link.url),
        );
        return;
      }
    }
    if (dest != null) {
      _ctrl.goToPage(dest.pageNumber, rememberReturn: true);
    } else if (link.url != null) {
      unawaited(launchUrl(link.url!, mode: LaunchMode.externalApplication));
    }
  }

  // -------------------------------------------------------------------
  // Strokes (pen / highlighter / eraser / figure)
  // -------------------------------------------------------------------

  InputRoute _route(PointerDownEvent e) {
    _lastDownLocal = e.localPosition;
    final s = _state;
    if (isStylus(e.kind)) _palm.stylusDown(e.pointer);
    if (!_ready) return InputRoute.viewer;
    final route = routePointer(
      tool: s.tool,
      kind: e.kind,
      eraser: s.eraser,
      rejectTouch: _palm.shouldRejectTouch(e.timeStamp),
    );
    // Text strokes need a text layer; erasing / figures don't.
    if (route == InputRoute.ink && !s.hasTextLayer) {
      return e.kind == PointerDeviceKind.touch
          ? InputRoute.viewer
          : InputRoute.reject;
    }
    if (route == InputRoute.figure && _pendingFigure != null) {
      setState(() {
        _pendingFigure = null;
        _pendingFigureLocal = null;
      });
    }
    return route;
  }

  void _onStylusSeen(PointerEvent e) {
    if (e is PointerHoverEvent) {
      _palm.stylusHover(e.timeStamp);
      return;
    }
    if (e is PointerDownEvent && _ctrl.stylusDetected() && !_stylusHintShown) {
      _stylusHintShown = true;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(l10n.readerStylusHint)));
    }
  }

  void _onStylusUp(PointerEvent e) => _palm.stylusUp(e.pointer, e.timeStamp);

  void _onStrokeEnd(
    InputRoute route,
    List<Offset> points,
    PointerDeviceKind kind,
  ) {
    if (points.isEmpty) return;
    final start = _localToNorm(points.first);
    if (start == null) return;
    final pl = _pageLayout(start.page)!;
    final norm = <Offset>[
      for (final p in points) _localToNorm(p, page: start.page)!.point,
    ];
    switch (route) {
      case InputRoute.ink:
        unawaited(_snapInk(start.page, norm, kInkStrokeWidth / 2 / pl.height));
      case InputRoute.erase:
        final ids = highlightsUnderStroke(
          norm,
          _highlights(),
          start.page,
          halfWidth: 8 / pl.height,
        );
        for (final h in _highlights().where((h) => ids.contains(h.id))) {
          unawaited(_ctrl.deleteHighlight(h));
        }
      case InputRoute.figure:
        final rect = Rect.fromPoints(norm.first, norm.last);
        final clamped = Rect.fromLTRB(
          rect.left.clamp(0.0, 1.0),
          rect.top.clamp(0.0, 1.0),
          rect.right.clamp(0.0, 1.0),
          rect.bottom.clamp(0.0, 1.0),
        );
        if (clamped.width < 0.01 || clamped.height < 0.01) return;
        setState(() {
          _pendingFigure = (page: start.page, bbox: clamped);
          _pendingFigureLocal = _normToLocal(start.page, clamped);
        });
      case InputRoute.viewer:
      case InputRoute.reject:
        break;
    }
  }

  Future<void> _snapInk(int page, List<Offset> stroke, double halfWidth) async {
    final text = await _pageText(page);
    if (text == null || !mounted) return;
    final range = snapStrokeToText(stroke, text, halfWidth: halfWidth);
    if (range == null) return; // Freeform ink: not persisted in v1.
    final sel = selectionFromRange(text, range.start, range.end);
    if (sel == null) return;
    final h = await _ctrl.createTextHighlight(sel);
    if (h == null || !mounted) return;
    if (_state.tool == ReaderTool.highlight) {
      // HighlightPicker floats for 2 s after a drag-highlight (motion #11).
      final bounds = boundsOf(sel.rects.map(highlightRectToRect))!;
      _ctrl.selectHighlight(h.id, anchor: _anchor(page, bounds));
      _pickerAutoHide?.cancel();
      _pickerAutoHide = Timer(const Duration(seconds: 2), () {
        if (mounted && _state.selectedHighlightId == h.id) {
          _ctrl.clearHighlightSelection();
        }
      });
    }
  }

  Future<void> _saveFigure({String? note}) async {
    final f = _pendingFigure;
    if (f == null) return;
    setState(() {
      _pendingFigure = null;
      _pendingFigureLocal = null;
    });
    final png = await renderFigurePng(_pdf.pages[f.page - 1], f.bbox);
    if (png == null) return;
    await _ctrl.createFigureHighlight(
      pageNumber: f.page,
      bbox: f.bbox,
      pngBytes: png,
      note: note,
    );
  }

  // -------------------------------------------------------------------
  // Commands from the controller (zoom, navigation, search)
  // -------------------------------------------------------------------

  Duration _motion(Duration d) => PaperMotion.of(context, d);

  Future<void> _applyZoom(
    double zoom,
    ReaderFitMode fit, {
    bool animate = true,
  }) async {
    if (!_ready) return;
    final page = _state.currentPage.clamp(1, _pdf.pageCount);
    final duration = animate ? _motion(PaperMotion.base) : Duration.zero;
    switch (fit) {
      case ReaderFitMode.width:
        await _pdf.goTo(
          _pdf.calcMatrixFitWidthForPage(pageNumber: page),
          duration: duration,
        );
      case ReaderFitMode.page:
        await _pdf.goTo(_pdf.calcMatrixForFit(pageNumber: page), duration: duration);
      case ReaderFitMode.none:
        await _pdf.setZoom(_pdf.centerPosition, zoom, duration: duration);
    }
    if (!mounted) return;
    _lastAppliedZoom = _pdf.currentZoom;
    _ctrl.zoomCommitted(_pdf.currentZoom, fit: fit);
  }

  Future<void> _applyNav(ReaderNavRequest nav) async {
    if (!_ready) return;
    final page = nav.pageNumber.clamp(1, _pdf.pageCount);
    final target = _pageLayout(page)!;
    final visible = _pdf.visibleRect;
    // Programmatic scroll: animate within one viewport, jump beyond (#32).
    final near =
        (target.top - visible.top).abs() <=
        visible.height * kAnimatedScrollMaxDistance;
    final duration = near ? _motion(PaperMotion.slow) : Duration.zero;
    final rect = nav.rect;
    if (rect != null) {
      final p = _pdf.pages[page - 1];
      final pdfRect = Rect.fromLTRB(
        rect.left * p.width,
        rect.top * p.height,
        rect.right * p.width,
        rect.bottom * p.height,
      ).toPdfRect(page: p);
      await _pdf.goToRectInsidePage(
        pageNumber: page,
        rect: pdfRect,
        anchor: PdfPageAnchor.center,
        duration: duration,
      );
    } else {
      await _pdf.goToPage(
        pageNumber: page,
        anchor: PdfPageAnchor.top,
        duration: duration,
      );
    }
  }

  void _applySearch(ReaderSearchState prev, ReaderSearchState next) {
    if (!next.open || next.query.isEmpty) {
      if (prev.open && (!next.open || next.query.isEmpty)) {
        _searcher.resetTextSearch();
      }
      return;
    }
    if (next.query != prev.query || next.matchCase != prev.matchCase) {
      _searcher.startTextSearch(next.query, caseInsensitive: !next.matchCase);
    } else if (next.serial != prev.serial) {
      unawaited(
        next.forward ? _searcher.goToNextMatch() : _searcher.goToPrevMatch(),
      );
    }
  }

  void _onSearchChanged() {
    if (!mounted) return;
    final total = _searcher.matches.length;
    final index = _searcher.currentIndex;
    _ctrl.reportSearchResults(
      total: total,
      current: index == null ? 0 : index + 1,
    );
  }

  // -------------------------------------------------------------------
  // Overlays
  // -------------------------------------------------------------------

  List<Highlight> _highlights() =>
      ref.read(readerHighlightsProvider(widget.args.paperId)).value ??
      const <Highlight>[];

  PageWash _washFor(
    int page,
    List<Highlight> highlights,
    List<FigureHighlight> figures,
  ) {
    if (!identical(highlights, _washSourceHighlights) ||
        !identical(figures, _washSourceFigures)) {
      _washSourceHighlights = highlights;
      _washSourceFigures = figures;
      _washCache.clear();
    }
    return _washCache[page] ??= PageWash.of(highlights, figures, page);
  }

  List<Widget> _pageOverlays(
    BuildContext context,
    Rect pageRect,
    PdfPage page,
    List<Highlight> highlights,
    List<FigureHighlight> figures,
    ReaderState s,
  ) {
    final n = page.pageNumber;
    final wash = _washFor(n, highlights, figures);
    final selected = s.selectedHighlightId == null
        ? null
        : highlights.where((h) => h.id == s.selectedHighlightId).firstOrNull;
    final flash = s.flashHighlightId == null
        ? null
        : highlights.where((h) => h.id == s.flashHighlightId).firstOrNull;
    final ringRects = selected == null
        ? const <Rect>[]
        : highlightRectsOnPage(selected, n);
    final flashRects = flash == null
        ? const <Rect>[]
        : highlightRectsOnPage(flash, n);
    final figure = _pendingFigure?.page == n ? _pendingFigure!.bbox : null;
    return <Widget>[
      if (!wash.isEmpty)
        Positioned.fill(
          key: ValueKey<String>('wash-$n'),
          child: HighlightWashLayer(
            wash: wash,
            pageSize: Size(page.width, page.height),
            colors: context.paperHighlights,
          ),
        ),
      if (ringRects.isNotEmpty || flashRects.isNotEmpty || figure != null)
        Positioned.fill(
          key: ValueKey<String>('overlay-$n'),
          child: PageInteractionOverlay(
            ringRects: ringRects,
            ringColor: selected == null ? null : paperHue(selected.color).ring,
            flashRects: flashRects,
            flashSerial: s.flashSerial,
            figureDraft: figure,
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final paperId = widget.args.paperId;
    final provider = readerControllerProvider(paperId);
    ref.listen<ReaderState>(provider, (prev, next) {
      if (prev == null) return;
      if (next.navRequest != null && next.navRequest != prev.navRequest) {
        unawaited(_applyNav(next.navRequest!));
      }
      if (next.zoomRequest != null && next.zoomRequest != prev.zoomRequest) {
        final z = next.zoomRequest!;
        unawaited(_applyZoom(z.zoom, z.fit));
      }
      if (next.search != prev.search) _applySearch(prev.search, next.search);
      if (prev.selection != null && next.selection == null) {
        final delegate = _ready ? _pdf.textSelectionDelegate : null;
        if (delegate != null && delegate.hasSelectedText) {
          unawaited(delegate.clearTextSelection());
        }
      }
    });
    final s = ref.watch(
      provider.select(
        (s) => (
          tool: s.tool,
          eraser: s.eraser,
          hasText: s.hasTextLayer,
          selectedId: s.selectedHighlightId,
          flashId: s.flashHighlightId,
          flashSerial: s.flashSerial,
          color: s.highlightColor,
        ),
      ),
    );
    final highlights =
        ref.watch(readerHighlightsProvider(paperId)).value ??
        const <Highlight>[];
    final figures =
        ref.watch(readerFigureHighlightsProvider(paperId)).value ??
        const <FigureHighlight>[];
    final c = context.paper;
    final hl = context.paperHighlights;
    final l10n = AppLocalizations.of(context);
    final textSelectionOn =
        s.tool == ReaderTool.select && s.hasText && !_stroke.isActive;
    final zoom = _ready ? _pdf.currentZoom : 1.0;

    final viewer = PdfViewer.file(
      widget.args.filePath,
      controller: _pdf,
      initialPageNumber: _initialPage,
      params: PdfViewerParams(
        margin: PaperSpacing.lg,
        backgroundColor: c.readerBackdrop,
        sizeDelegateProvider: const PdfViewerSizeDelegateProviderLegacy(
          minScale: kMinZoom,
          maxScale: kMaxZoom,
          useAlternativeFitScaleAsMinScale: false,
        ),
        // Render visible pages first, then ±1 viewport (motion.md §1.6).
        horizontalCacheExtent: 1.0,
        verticalCacheExtent: 1.0,
        maxImageBytesCachedOnMemory: 160 * 1024 * 1024,
        // Pinch/zoom draws the cached page images through the transform;
        // the sharp re-render waits until the scale has settled for
        // kRerasterIdle (≈ gesture end), so no pdfium work runs mid-pinch.
        behaviorControlParams: const PdfViewerBehaviorControlParams(
          partialImageLoadingDelay: kRerasterIdle,
        ),
        enableKeyboardNavigation: false,
        scrollByMouseWheel: 0.2,
        onViewerReady: _onViewerReady,
        onDocumentLoadFinished: (ref, ok) {
          if (!ok) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _ctrl.documentFailed();
            });
          }
        },
        errorBannerBuilder: (context, error, stackTrace, documentRef) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _ctrl.documentFailed(error);
          });
          return const SizedBox.shrink();
        },
        loadingBannerBuilder: (context, done, total) => const SizedBox.shrink(),
        onPageChanged: _onPageChanged,
        onInteractionStart: _onInteractionStart,
        onInteractionEnd: _onInteractionEnd,
        onGeneralTap: _onGeneralTap,
        textSelectionParams: PdfTextSelectionParams(
          enabled: textSelectionOn,
          showContextMenuAutomatically: false,
          onTextSelectionChange: (sel) => unawaited(_onTextSelectionChange(sel)),
          onSelectionHandlePanStart: (_) => _ctrl.setOverlaysHidden(true),
          onSelectionHandlePanEnd: (_) {
            _ctrl.setOverlaysHidden(false);
            _refreshAnchors();
          },
        ),
        // The SelectionPopover replaces pdfrx's context menu.
        buildContextMenu: (context, params) => null,
        linkHandlerParams: PdfLinkHandlerParams(
          onLinkTap: _onLinkTap,
          linkColor: const Color(0x00000000),
          linkHoverColor: PaperReaderMark.citation.wash.withValues(
            alpha: PaperReaderMark.restAlpha,
          ),
        ),
        pagePaintCallbacks: <PdfViewerPagePaintCallback>[
          _searcher.pageTextMatchPaintCallback,
        ],
        matchTextColor: PaperReaderMark.term.wash.withValues(alpha: 0.35),
        activeMatchTextColor: PaperReaderMark.term.active,
        pageOverlaysBuilder: (context, pageRect, page) => _pageOverlays(
          context,
          pageRect,
          page,
          highlights,
          figures,
          ref.read(provider),
        ),
      ),
    );

    return RepaintBoundary(
      // B1: the whole page list. Chrome animations never repaint it.
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Listener(
              behavior: HitTestBehavior.translucent,
              onPointerUp: (e) {
                if (isStylus(e.kind)) _onStylusUp(e);
              },
              onPointerCancel: (e) {
                if (isStylus(e.kind)) _onStylusUp(e);
              },
              child: ReaderInputCapture(
                router: _route,
                stroke: _stroke,
                onStrokeEnd: _onStrokeEnd,
                onStylusSeen: _onStylusSeen,
                onActiveChanged: _ctrl.setGestureInProgress,
                child: MouseRegion(
                  cursor: switch (s.tool) {
                    ReaderTool.figure => SystemMouseCursors.precise,
                    ReaderTool.pen ||
                    ReaderTool.highlight => SystemMouseCursors.precise,
                    ReaderTool.select => MouseCursor.defer,
                  },
                  child: viewer,
                ),
              ),
            ),
            InkLayer(
              stroke: _stroke,
              inkColor: hl.ink(paperHue(s.color)),
              strokeWidth: kInkStrokeWidth * zoom,
              figureColor: c.focusRingOnPaper,
              eraserColor: c.textPrimary,
            ),
            if (_pendingFigureLocal != null)
              FigurePopover(
                anchor: _pendingFigureLocal!,
                l10n: l10n,
                onSave: () => unawaited(_saveFigure()),
                onAddNote: () async {
                  final note = await showFigureNoteDialog(context);
                  if (note != null) await _saveFigure(note: note);
                },
                onCancel: () => setState(() {
                  _pendingFigure = null;
                  _pendingFigureLocal = null;
                }),
              ),
          ],
        ),
      ),
    );
  }
}

/// Renders the page region [bbox] (page-normalised) to PNG at ~144 dpi for a
/// figure highlight. Returns null when pdfium cannot render it.
Future<Uint8List?> renderFigurePng(PdfPage page, Rect bbox) async {
  const scale = 2.0; // 144 dpi
  final fullW = page.width * scale;
  final fullH = page.height * scale;
  final x = (bbox.left * fullW).floor();
  final y = (bbox.top * fullH).floor();
  final w = math.max(1, (bbox.width * fullW).ceil());
  final h = math.max(1, (bbox.height * fullH).ceil());
  PdfImage? image;
  ui.Image? uiImage;
  try {
    image = await page.render(
      x: x,
      y: y,
      width: w,
      height: h,
      fullWidth: fullW,
      fullHeight: fullH,
      backgroundColor: 0xFFFFFFFF,
    );
    if (image == null) return null;
    uiImage = await image.createImage();
    final data = await uiImage.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  } on Object {
    return null;
  } finally {
    image?.dispose();
    uiImage?.dispose();
  }
}
