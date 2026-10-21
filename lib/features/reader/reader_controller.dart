import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/data_providers.dart';
import '../../domain/domain.dart';
import 'pdf_geometry.dart';
import 'reader_state.dart';

export 'reader_state.dart';

/// Reading position save debounce (flows F4: "debounced 1s").
const Duration kReadingPositionSaveDebounce = Duration(seconds: 1);

/// Zoom limits (reader spec: pinch is continuous 25–800%).
const double kMinZoom = 0.25;
const double kMaxZoom = 8.0;

/// Step-zoom stops (reader spec: 50 … 400%).
const List<double> kZoomSteps = <double>[
  0.5,
  0.75,
  1.0,
  1.25,
  1.5,
  2.0,
  3.0,
  4.0,
];

/// Creates a one-shot timer. Overridden in tests with a manual clock.
typedef ReaderTimerFactory = Timer Function(Duration, void Function());

final readerTimerFactoryProvider = Provider<ReaderTimerFactory>(
  (ref) => Timer.new,
);

/// Wall clock (overridable in tests).
final readerClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// New ids for highlights / figure highlights.
final readerIdFactoryProvider = Provider<String Function()>(
  (ref) => const Uuid().v4,
);

/// The reader for one paper. Auto-disposed when the reader route leaves
/// (the pending reading position is flushed then).
final readerControllerProvider = NotifierProvider.autoDispose
    .family<ReaderController, ReaderState, String>(ReaderController.new);

/// Live highlights of a paper (text). Empty while the data layer is not
/// wired.
final readerHighlightsProvider = StreamProvider.autoDispose
    .family<List<Highlight>, String>((ref, paperId) {
      try {
        return ref.watch(highlightRepositoryProvider).watchHighlights(paperId);
      } on Object {
        return Stream<List<Highlight>>.value(const <Highlight>[]);
      }
    });

/// Live figure highlights of a paper.
final readerFigureHighlightsProvider = StreamProvider.autoDispose
    .family<List<FigureHighlight>, String>((ref, paperId) {
      try {
        return ref
            .watch(highlightRepositoryProvider)
            .watchFigureHighlights(paperId);
      } on Object {
        return Stream<List<FigureHighlight>>.value(const <FigureHighlight>[]);
      }
    });

/// One-shot things the UI shows (snackbars, announcements) or forwards to
/// the side panel (explain / note requests).
sealed class ReaderEvent {
  const ReaderEvent();
}

final class HighlightCreatedEvent extends ReaderEvent {
  const HighlightCreatedEvent(this.highlight);
  final Highlight highlight;
}

final class HighlightDeletedEvent extends ReaderEvent {
  const HighlightDeletedEvent(this.highlight);
  final Highlight highlight;
}

final class HighlightSaveFailedEvent extends ReaderEvent {
  const HighlightSaveFailedEvent(this.retry);
  final Future<void> Function() retry;
}

final class FigureHighlightSavedEvent extends ReaderEvent {
  const FigureHighlightSavedEvent(this.figure);
  final FigureHighlight figure;
}

/// Explain was requested (selection E / popover / picker). The highlight
/// is already saved (flows F5); the side panel opened on Explanation.
final class ExplainRequestedEvent extends ReaderEvent {
  const ExplainRequestedEvent({
    required this.term,
    required this.contextBefore,
    required this.contextAfter,
    this.highlight,
  });
  final String term;
  final String contextBefore;
  final String contextAfter;
  final Highlight? highlight;
}

/// A note was requested for [highlight] (saved first).
final class NoteRequestedEvent extends ReaderEvent {
  const NoteRequestedEvent(this.highlight);
  final Highlight highlight;
}

/// Holds [ReaderState] and every reader command. Pure Dart apart from
/// Riverpod: the viewport reports into it (page, zoom, gestures, selection)
/// and widgets dispatch commands to it (tools, zoom steps, shortcuts).
class ReaderController extends Notifier<ReaderState> {
  ReaderController(this.paperId);

  final String paperId;

  final StreamController<ReaderEvent> _events =
      StreamController<ReaderEvent>.broadcast();
  Timer? _saveTimer;
  ReadingPosition? _pendingPosition;
  ReadingPosition? _lastSaved;
  PaperRepository? _paperRepo;
  int _loadGeneration = 0;
  int _serial = 0;
  bool _positionRestored = false;

  /// UI events (snackbars, announcements, panel requests).
  Stream<ReaderEvent> get events => _events.stream;

  @override
  ReaderState build() {
    ref.onDispose(_onDispose);
    Future<void>.microtask(load);
    return ReaderState(paperId: paperId);
  }

  void _onDispose() {
    final timer = _saveTimer;
    final pending = _pendingPosition;
    if (timer != null && timer.isActive && pending != null) {
      timer.cancel();
      _writePosition(pending);
    }
    _saveTimer = null;
    unawaited(_events.close());
  }

  void _emit(ReaderEvent e) {
    if (!_events.isClosed) _events.add(e);
  }

  int _nextSerial() => ++_serial;

  // ---------------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------------

  /// Resolves the paper and its local PDF. Safe to call again (retry).
  Future<void> load() async {
    if (!ref.mounted) return;
    final gen = ++_loadGeneration;
    bool stale() => !ref.mounted || gen != _loadGeneration;
    state = state.copyWith(phase: const ReaderResolving());

    final PaperRepository repo;
    final Paper? paper;
    try {
      repo = ref.read(paperRepositoryProvider);
      _paperRepo = repo;
      paper = await repo.getPaper(paperId);
    } on Object catch (e) {
      if (stale()) return;
      state = state.copyWith(phase: ReaderLoadError(_errorKindFor(e), e));
      return;
    }
    if (stale()) return;
    if (paper == null) {
      state = state.copyWith(
        phase: const ReaderLoadError(ReaderErrorKind.paperDeleted),
      );
      return;
    }
    state = _restorePosition(state.copyWith(paper: paper), paper);
    unawaited(_ignoreErrors(repo.markOpened(paperId)));

    try {
      final path = await repo.ensureLocalFile(
        paperId,
        onProgress: (p) {
          if (stale()) return;
          state = state.copyWith(phase: ReaderDownloading(p.clamp(0.0, 1.0)));
        },
      );
      if (stale()) return;
      state = state.copyWith(phase: ReaderOpening(path));
    } on Object catch (e) {
      if (stale()) return;
      state = state.copyWith(
        phase: ReaderLoadError(
          e is PaperException
              ? _errorKindFor(e)
              : ReaderErrorKind.downloadFailed,
          e,
        ),
      );
    }
  }

  ReaderState _restorePosition(ReaderState s, Paper paper) {
    if (_positionRestored) return s;
    _positionRestored = true;
    final pos = paper.readingPosition;
    if (pos == null) return s;
    _lastSaved = pos;
    final zoom = pos.zoom;
    return s.copyWith(
      currentPage: pos.pageNumber < 1 ? 1 : pos.pageNumber,
      zoom: zoom == null ? s.zoom : _clampZoom(zoom),
      fit: zoom == null ? ReaderFitMode.width : ReaderFitMode.none,
    );
  }

  static ReaderErrorKind _errorKindFor(Object e) => switch (e) {
    OfflineException() => ReaderErrorKind.offlineNotDownloaded,
    InvalidPdfException() => ReaderErrorKind.invalidPdf,
    NotFoundException() => ReaderErrorKind.paperDeleted,
    ServerException() => ReaderErrorKind.downloadFailed,
    _ => ReaderErrorKind.unknown,
  };

  Future<void> retry() => load();

  /// The viewport opened the document.
  void documentLoaded({required int pageCount, bool hasTextLayer = true}) {
    final path = switch (state.phase) {
      ReaderOpening(:final filePath) => filePath,
      ReaderReady(:final filePath) => filePath,
      _ => null,
    };
    if (path == null) return;
    state = state.copyWith(
      phase: ReaderReady(path),
      pageCount: pageCount,
      currentPage: state.currentPage.clamp(1, pageCount < 1 ? 1 : pageCount),
      hasTextLayer: hasTextLayer,
    );
  }

  /// pdfium could not open / render the file.
  void documentFailed([Object? error]) {
    state = state.copyWith(
      phase: ReaderLoadError(ReaderErrorKind.invalidPdf, error),
    );
  }

  void setTextLayerAvailable(bool available) {
    if (state.hasTextLayer == available) return;
    state = state.copyWith(hasTextLayer: available);
  }

  // ---------------------------------------------------------------------
  // Page + zoom (reported by the viewport, commanded by chrome/shortcuts)
  // ---------------------------------------------------------------------

  /// The viewport reports the page at the viewport centre (throttled).
  void pageChanged(int pageNumber) {
    if (pageNumber < 1 || pageNumber == state.currentPage) return;
    state = state.copyWith(currentPage: pageNumber);
    _schedulePositionSave();
  }

  /// The viewport committed a zoom (gesture end / step zoom settled).
  void zoomCommitted(double zoom, {ReaderFitMode fit = ReaderFitMode.none}) {
    final z = _clampZoom(zoom);
    if ((z - state.zoom).abs() < 1e-3 && fit == state.fit) return;
    state = state.copyWith(zoom: z, fit: fit);
    _schedulePositionSave();
  }

  static double _clampZoom(double z) =>
      z.isNaN ? 1.0 : z.clamp(kMinZoom, kMaxZoom).toDouble();

  void _requestZoom(double zoom, ReaderFitMode fit) {
    final z = _clampZoom(zoom);
    state = state.copyWith(
      zoom: z,
      fit: fit,
      zoomRequest: ReaderZoomRequest(zoom: z, fit: fit, serial: _nextSerial()),
    );
    _schedulePositionSave();
  }

  void setZoom(double zoom) => _requestZoom(zoom, ReaderFitMode.none);

  void zoomIn() {
    final next = kZoomSteps.firstWhere(
      (s) => s > state.zoom + 1e-3,
      orElse: () => kMaxZoom,
    );
    _requestZoom(next, ReaderFitMode.none);
  }

  void zoomOut() {
    final prev = kZoomSteps.lastWhere(
      (s) => s < state.zoom - 1e-3,
      orElse: () => kMinZoom,
    );
    _requestZoom(prev, ReaderFitMode.none);
  }

  void resetZoom() => _requestZoom(1.0, ReaderFitMode.none);
  void fitWidth() => _requestZoom(state.zoom, ReaderFitMode.width);
  void fitPage() => _requestZoom(state.zoom, ReaderFitMode.page);

  void goToPage(int pageNumber, {Rect? rect, bool rememberReturn = false}) {
    final count = state.pageCount;
    final target = count < 1 ? pageNumber : pageNumber.clamp(1, count);
    state = state.copyWith(
      currentPage: target,
      returnPage: rememberReturn ? state.currentPage : state.returnPage,
      navRequest: ReaderNavRequest(
        pageNumber: target,
        rect: rect,
        serial: _nextSerial(),
      ),
    );
    _schedulePositionSave();
  }

  void nextPage() => goToPage(state.currentPage + 1);
  void previousPage() => goToPage(state.currentPage - 1);
  void firstPage() => goToPage(1);
  void lastPage() => goToPage(state.pageCount < 1 ? 1 : state.pageCount);

  /// Jumps to [h], rings it (motion #31) and shows "Back to page N".
  void jumpToHighlight(Highlight h) {
    final page = h.position?.pageNumber ?? h.pageNumber;
    if (page == null) return;
    final rect = h.position == null
        ? null
        : boundsOf(h.position!.rects.map(highlightRectToRect));
    goToPage(page, rect: rect, rememberReturn: page != state.currentPage);
    state = state.copyWith(
      flashHighlightId: h.id,
      flashSerial: state.flashSerial + 1,
    );
  }

  /// "Go to reference" from the citation popover.
  void goToReference(int pageNumber) {
    state = state.copyWith(citation: null);
    goToPage(pageNumber, rememberReturn: true);
  }

  /// "Back to page N" pill.
  void returnToPreviousPage() {
    final page = state.returnPage;
    if (page == null) return;
    state = state.copyWith(returnPage: null);
    goToPage(page);
  }

  void dismissReturnPill() => state = state.copyWith(returnPage: null);

  // ---------------------------------------------------------------------
  // Gestures / overlays
  // ---------------------------------------------------------------------

  void setGestureInProgress(bool value) {
    if (state.gestureInProgress == value) return;
    state = state.copyWith(gestureInProgress: value);
  }

  void setOverlaysHidden(bool value) {
    if (state.overlaysHidden == value) return;
    state = state.copyWith(overlaysHidden: value);
  }

  // ---------------------------------------------------------------------
  // Tools + colour
  // ---------------------------------------------------------------------

  /// Selects [tool]; choosing the active (non-select) tool again returns to
  /// Select (reader spec).
  void setTool(ReaderTool tool) {
    final next = tool == state.tool && tool != ReaderTool.select
        ? ReaderTool.select
        : tool;
    state = state.copyWith(
      tool: next,
      eraser: next == ReaderTool.pen ? state.eraser : false,
      selection: null,
      selectedHighlightId: null,
      selectedHighlightAnchor: null,
      citation: null,
      explainAnchor: null,
    );
  }

  void toggleEraser() => state = state.copyWith(
    eraser: !state.eraser,
    tool: state.tool == ReaderTool.select || state.tool == ReaderTool.figure
        ? ReaderTool.pen
        : state.tool,
  );

  /// First stylus contact on a page in Select mode auto-switches to Pen.
  /// Returns true when it switched (show `StylusModeHint`).
  bool stylusDetected({bool autoSwitch = true}) {
    if (!autoSwitch || state.tool != ReaderTool.select) return false;
    setTool(ReaderTool.pen);
    return true;
  }

  void setHighlightColor(HighlightColor color) {
    if (state.highlightColor == color) return;
    state = state.copyWith(highlightColor: color);
  }

  // ---------------------------------------------------------------------
  // Selection / picker / citation popovers
  // ---------------------------------------------------------------------

  void setSelection(ReaderTextSelection? selection) {
    state = state.copyWith(
      selection: selection,
      selectedHighlightId: selection == null ? state.selectedHighlightId : null,
      selectedHighlightAnchor: selection == null
          ? state.selectedHighlightAnchor
          : null,
      citation: selection == null ? state.citation : null,
      explainAnchor: selection == null ? state.explainAnchor : null,
    );
  }

  void clearSelection() {
    if (state.selection == null) return;
    state = state.copyWith(selection: null);
  }

  void updateSelectionAnchor(ReaderAnchor? anchor) {
    final sel = state.selection;
    if (sel == null || sel.anchor == anchor) return;
    state = state.copyWith(selection: sel.withAnchor(anchor));
  }

  /// Opens the `HighlightPicker` on [highlightId].
  void selectHighlight(String highlightId, {ReaderAnchor? anchor}) {
    state = state.copyWith(
      selectedHighlightId: highlightId,
      selectedHighlightAnchor: anchor,
      selection: null,
      citation: null,
      explainAnchor: null,
    );
  }

  void clearHighlightSelection() {
    if (state.selectedHighlightId == null) return;
    state = state.copyWith(
      selectedHighlightId: null,
      selectedHighlightAnchor: null,
    );
  }

  void updateHighlightAnchor(ReaderAnchor? anchor) {
    if (state.selectedHighlightId == null ||
        state.selectedHighlightAnchor == anchor) {
      return;
    }
    state = state.copyWith(selectedHighlightAnchor: anchor);
  }

  void showCitation(ReaderCitationTarget target) => state = state.copyWith(
    citation: target,
    selection: null,
    selectedHighlightId: null,
    selectedHighlightAnchor: null,
  );

  void dismissCitation() {
    if (state.citation == null) return;
    state = state.copyWith(citation: null);
  }

  void updateCitationAnchor(ReaderAnchor anchor) {
    final c = state.citation;
    if (c == null || c.anchor == anchor) return;
    state = state.copyWith(citation: c.withAnchor(anchor));
  }

  // ---------------------------------------------------------------------
  // Side panel
  // ---------------------------------------------------------------------

  void togglePanel() => state = state.copyWith(
    panelOpen: !state.panelOpen,
    explainAnchor: state.panelOpen ? state.explainAnchor : null,
  );

  /// Opening the panel retires the floating explanation (its card is the
  /// newest one in the Explanation tab).
  void openPanel([ReaderPanelTab? tab]) => state = state.copyWith(
    panelOpen: true,
    panelTab: tab ?? state.panelTab,
    explainAnchor: null,
  );

  /// Closes the floating explanation popover (outside tap, Escape, `×`).
  void dismissExplanation() {
    if (state.explainAnchor == null) return;
    state = state.copyWith(explainAnchor: null);
  }

  void updateExplainAnchor(ReaderAnchor? anchor) {
    if (state.explainAnchor == null || state.explainAnchor == anchor) return;
    state = state.copyWith(explainAnchor: anchor);
  }

  /// Explain from the reader: with the panel visible the card goes to the
  /// top of its Explanation tab; otherwise the floating explanation popover
  /// shows it at [anchor] (reader.md §6) and the tab is selected for later.
  void _showExplanation(ReaderAnchor? anchor) {
    if (state.panelOpen || anchor?.local == null) {
      openPanel(ReaderPanelTab.explanation);
    } else {
      state = state.copyWith(
        panelTab: ReaderPanelTab.explanation,
        explainAnchor: anchor,
      );
    }
  }

  void closePanel() {
    if (!state.panelOpen) return;
    state = state.copyWith(panelOpen: false);
  }

  void setPanelTab(ReaderPanelTab tab) {
    if (state.panelTab == tab && state.panelOpen) return;
    state = state.copyWith(panelTab: tab, panelOpen: true);
  }

  // ---------------------------------------------------------------------
  // Find
  // ---------------------------------------------------------------------

  void openSearch() =>
      state = state.copyWith(search: state.search.copyWith(open: true));

  void closeSearch() =>
      state = state.copyWith(search: const ReaderSearchState());

  void setSearchQuery(String query) => state = state.copyWith(
    search: state.search.copyWith(query: query, total: 0, current: 0),
  );

  void setSearchMatchCase(bool value) => state = state.copyWith(
    search: state.search.copyWith(matchCase: value, total: 0, current: 0),
  );

  void searchNext() => state = state.copyWith(
    search: state.search.copyWith(
      serial: state.search.serial + 1,
      forward: true,
    ),
  );

  void searchPrevious() => state = state.copyWith(
    search: state.search.copyWith(
      serial: state.search.serial + 1,
      forward: false,
    ),
  );

  /// The viewport reports search progress.
  void reportSearchResults({required int total, required int current}) {
    final s = state.search;
    if (s.total == total && s.current == current) return;
    state = state.copyWith(
      search: s.copyWith(total: total, current: current),
    );
  }

  /// Esc: closes the topmost transient (popover -> find bar -> overlay
  /// panel), then returns the tool to Select. Returns false when there was
  /// nothing to close (the route may pop then).
  bool escape({bool panelIsOverlay = false}) {
    if (state.hasPopover) {
      state = state.copyWith(
        selection: null,
        selectedHighlightId: null,
        selectedHighlightAnchor: null,
        citation: null,
        explainAnchor: null,
      );
      return true;
    }
    if (state.search.open) {
      closeSearch();
      return true;
    }
    if (panelIsOverlay && state.panelOpen) {
      closePanel();
      return true;
    }
    if (state.tool != ReaderTool.select || state.eraser) {
      state = state.copyWith(tool: ReaderTool.select, eraser: false);
      return true;
    }
    return false;
  }

  // ---------------------------------------------------------------------
  // Highlights
  // ---------------------------------------------------------------------

  HighlightRepository? _highlightRepo() {
    try {
      return ref.read(highlightRepositoryProvider);
    } on Object {
      return null;
    }
  }

  /// Saves [selection] as a text highlight in [color]. Optimistic and local
  /// first; on failure emits [HighlightSaveFailedEvent] with a retry.
  Future<Highlight?> createTextHighlight(
    ReaderTextSelection selection, {
    HighlightColor? color,
  }) async {
    final paper = state.paper;
    final repo = _highlightRepo();
    if (paper == null || !state.hasTextLayer) return null;
    final hue = color ?? state.highlightColor;
    final now = ref.read(readerClockProvider)().toUtc();
    final highlight = Highlight(
      id: ref.read(readerIdFactoryProvider)(),
      userId: paper.userId,
      paperId: paperId,
      selectedText: selection.text,
      contextBefore: selection.contextBefore.isEmpty
          ? null
          : selection.contextBefore,
      contextAfter: selection.contextAfter.isEmpty
          ? null
          : selection.contextAfter,
      pageNumber: selection.pageNumber,
      position: HighlightPosition(
        pageNumber: selection.pageNumber,
        rects: selection.rects,
        textLayerScale: 1,
      ),
      createdAt: now,
      color: hue,
      localUpdatedAt: now,
      syncState: SyncState.pendingCreate,
    );
    if (state.highlightColor != hue) {
      state = state.copyWith(highlightColor: hue);
    }
    if (repo == null) {
      _emit(HighlightSaveFailedEvent(() => _retryCreate(selection, hue)));
      return null;
    }
    try {
      final saved = await repo.createHighlight(highlight);
      _emit(HighlightCreatedEvent(saved));
      return saved;
    } on Object {
      _emit(HighlightSaveFailedEvent(() => _retryCreate(selection, hue)));
      return null;
    }
  }

  Future<void> _retryCreate(ReaderTextSelection s, HighlightColor c) async {
    await createTextHighlight(s, color: c);
  }

  /// `H` / colour swatch on the SelectionPopover: highlight the current
  /// selection and close the popover.
  Future<Highlight?> highlightSelection([HighlightColor? color]) async {
    final sel = state.selection;
    if (sel == null) return null;
    state = state.copyWith(selection: null);
    return createTextHighlight(sel, color: color);
  }

  /// `E` / Explain: save the highlight (flows F5), show the explanation
  /// (panel tab or floating popover) and emit [ExplainRequestedEvent].
  Future<void> explainSelection() async {
    final sel = state.selection;
    if (sel == null) return;
    state = state.copyWith(selection: null);
    final h = await createTextHighlight(sel);
    _showExplanation(sel.anchor);
    _emit(
      ExplainRequestedEvent(
        term: sel.text,
        contextBefore: sel.contextBefore,
        contextAfter: sel.contextAfter,
        highlight: h,
      ),
    );
  }

  /// `N` / Note: save the highlight, open the Notes tab, emit
  /// [NoteRequestedEvent].
  Future<void> noteForSelection() async {
    final sel = state.selection;
    if (sel == null) return;
    state = state.copyWith(selection: null);
    final h = await createTextHighlight(sel);
    if (h == null) return;
    openPanel(ReaderPanelTab.notes);
    _emit(NoteRequestedEvent(h));
  }

  void explainHighlight(Highlight h) {
    final anchor = state.selectedHighlightId == h.id
        ? state.selectedHighlightAnchor
        : null;
    clearHighlightSelection();
    _showExplanation(anchor);
    _emit(
      ExplainRequestedEvent(
        term: h.selectedText,
        contextBefore: h.contextBefore ?? '',
        contextAfter: h.contextAfter ?? '',
        highlight: h,
      ),
    );
  }

  void noteForHighlight(Highlight h) {
    clearHighlightSelection();
    openPanel(ReaderPanelTab.notes);
    _emit(NoteRequestedEvent(h));
  }

  /// Device-only colour change from the HighlightPicker / keys 1–6.
  Future<void> changeHighlightColor(String id, HighlightColor color) async {
    state = state.copyWith(highlightColor: color);
    final repo = _highlightRepo();
    if (repo == null) return;
    try {
      await repo.updateColor(id, color);
    } on Object {
      // Colour is cosmetic and device-only; nothing to recover.
    }
  }

  Future<void> deleteHighlight(Highlight h) async {
    clearHighlightSelection();
    final repo = _highlightRepo();
    if (repo == null) return;
    try {
      await repo.deleteHighlight(h.id);
      _emit(HighlightDeletedEvent(h));
    } on Object {
      // The highlight stays; the stream keeps showing it.
    }
  }

  /// Undo for create (snackbar `highlightCreatedUndo`).
  Future<void> undoCreate(Highlight h) async {
    final repo = _highlightRepo();
    if (repo == null) return;
    await _ignoreErrors(repo.deleteHighlight(h.id));
  }

  /// Undo for delete (snackbar `highlightDeletedUndo`).
  Future<void> undoDelete(Highlight h) async {
    final repo = _highlightRepo();
    if (repo == null) return;
    await _ignoreErrors(repo.restoreHighlight(h));
  }

  /// Saves a figure crop. [bbox] is page-normalised; [pngBytes] the crop.
  Future<FigureHighlight?> createFigureHighlight({
    required int pageNumber,
    required Rect bbox,
    required Uint8List pngBytes,
    String? note,
  }) async {
    final paper = state.paper;
    final repo = _highlightRepo();
    if (paper == null || repo == null) return null;
    final now = ref.read(readerClockProvider)().toUtc();
    final id = ref.read(readerIdFactoryProvider)();
    final figure = FigureHighlight(
      id: id,
      userId: paper.userId,
      paperId: paperId,
      pageNumber: pageNumber,
      bbox: rectToFigureBBox(bbox),
      // RPR figureStoragePath: `${userId}/${paperId}/${figureId}.png`.
      storagePath: '${paper.userId}/$paperId/$id.png',
      createdAt: now,
      updatedAt: now,
      note: (note == null || note.trim().isEmpty) ? null : note.trim(),
      syncState: SyncState.pendingCreate,
    );
    try {
      final saved = await repo.createFigureHighlight(
        figure,
        pngBytes: pngBytes,
      );
      _emit(FigureHighlightSavedEvent(saved));
      return saved;
    } on Object {
      _emit(
        HighlightSaveFailedEvent(() async {
          await createFigureHighlight(
            pageNumber: pageNumber,
            bbox: bbox,
            pngBytes: pngBytes,
            note: note,
          );
        }),
      );
      return null;
    }
  }

  // ---------------------------------------------------------------------
  // Reading position
  // ---------------------------------------------------------------------

  ReadingPosition _currentPosition() => ReadingPosition(
    pageNumber: state.currentPage,
    zoom: state.fit == ReaderFitMode.width ? null : state.zoom,
    updatedAt: ref.read(readerClockProvider)(),
  );

  void _schedulePositionSave() {
    if (state.paper == null) return;
    _pendingPosition = _currentPosition();
    _saveTimer?.cancel();
    _saveTimer = ref.read(readerTimerFactoryProvider)(
      kReadingPositionSaveDebounce,
      _flushPosition,
    );
  }

  void _flushPosition() {
    final pending = _pendingPosition;
    _pendingPosition = null;
    if (pending != null) _writePosition(pending);
  }

  void _writePosition(ReadingPosition p) {
    final last = _lastSaved;
    if (last != null &&
        last.pageNumber == p.pageNumber &&
        last.zoom == p.zoom) {
      return;
    }
    final repo = _paperRepo;
    if (repo == null) return;
    _lastSaved = p;
    unawaited(_ignoreErrors(repo.saveReadingPosition(paperId, p)));
  }
}

Future<void> _ignoreErrors(Future<void> f) async {
  try {
    await f;
  } on Object {
    // Best effort (device-local bookkeeping).
  }
}
