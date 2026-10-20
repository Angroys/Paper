import 'dart:ui' show Rect;

import 'package:meta/meta.dart';

import '../../domain/domain.dart';
import '../panel/panel_tab.dart';

export '../panel/panel_tab.dart';

/// Reader tool modes (`ToolModeSegmented`, shortcuts V / H / P / F).
enum ReaderTool { select, highlight, pen, figure }

/// Zoom fit mode. [none] = the explicit [ReaderState.zoom] applies.
enum ReaderFitMode { none, width, page }

/// Why the reader could not open a paper (`ReaderErrorState` variants).
enum ReaderErrorKind {
  /// Download failed (network / server): `readerDownloadFailed` [Retry].
  downloadFailed,

  /// The file is not a renderable PDF (`InvalidPdfException`, pdfium open
  /// failure): `readerRenderFailed` [Re-download].
  invalidPdf,

  /// The paper is gone (deleted on another device): `readerPaperDeleted`.
  paperDeleted,

  /// Cloud-only paper while offline: `readerUnavailableOffline`.
  offlineNotDownloaded,

  /// Anything else (data layer not wired, storage failure...).
  unknown,
}

/// Load phase of the reader.
@immutable
sealed class ReaderLoadPhase {
  const ReaderLoadPhase();
}

/// Resolving the paper / local file. Cached papers stay here only for a few
/// ms, so no spinner is shown for this phase (reader spec: "first page from
/// cache instantly").
final class ReaderResolving extends ReaderLoadPhase {
  const ReaderResolving();

  @override
  bool operator ==(Object other) => other is ReaderResolving;

  @override
  int get hashCode => 0;
}

/// Downloading the PDF ([progress] 0..1, null = unknown).
final class ReaderDownloading extends ReaderLoadPhase {
  const ReaderDownloading(this.progress);
  final double? progress;

  @override
  bool operator ==(Object other) =>
      other is ReaderDownloading && other.progress == progress;

  @override
  int get hashCode => progress.hashCode;
}

/// The file is local; the viewer is opening it with pdfium.
final class ReaderOpening extends ReaderLoadPhase {
  const ReaderOpening(this.filePath);
  final String filePath;

  @override
  bool operator ==(Object other) =>
      other is ReaderOpening && other.filePath == filePath;

  @override
  int get hashCode => filePath.hashCode;
}

/// The document is open and laid out.
final class ReaderReady extends ReaderLoadPhase {
  const ReaderReady(this.filePath);
  final String filePath;

  @override
  bool operator ==(Object other) =>
      other is ReaderReady && other.filePath == filePath;

  @override
  int get hashCode => filePath.hashCode;
}

final class ReaderLoadError extends ReaderLoadPhase {
  const ReaderLoadError(this.kind, [this.error]);
  final ReaderErrorKind kind;
  final Object? error;

  @override
  bool operator ==(Object other) =>
      other is ReaderLoadError && other.kind == kind;

  @override
  int get hashCode => kind.hashCode;
}

/// A rectangle on a page: [rect] is normalised to the page (0..1, origin top
/// left; the RPR `highlights.position` convention). [local] is the same
/// rectangle in viewer-local logical pixels at the time it was measured
/// (used to anchor popovers); null when it is off-screen or stale.
@immutable
class ReaderAnchor {
  const ReaderAnchor({required this.pageNumber, required this.rect, this.local});

  final int pageNumber;
  final Rect rect;
  final Rect? local;

  ReaderAnchor withLocal(Rect? local) =>
      ReaderAnchor(pageNumber: pageNumber, rect: rect, local: local);

  @override
  bool operator ==(Object other) =>
      other is ReaderAnchor &&
      other.pageNumber == pageNumber &&
      other.rect == rect &&
      other.local == local;

  @override
  int get hashCode => Object.hash(pageNumber, rect, local);
}

/// The current text selection, already reduced to one page (RPR highlights
/// are single-page) and in the stored format.
@immutable
class ReaderTextSelection {
  const ReaderTextSelection({
    required this.pageNumber,
    required this.text,
    required this.rects,
    this.contextBefore = '',
    this.contextAfter = '',
    this.anchor,
  });

  final int pageNumber;

  /// Normalised selected text (whitespace collapsed, hyphenated line breaks
  /// joined): `highlights.selected_text`.
  final String text;

  /// Line rects in page-normalised coordinates (`HighlightPosition.rects`).
  final List<HighlightRect> rects;
  final String contextBefore;
  final String contextAfter;

  /// Where the `SelectionPopover` anchors.
  final ReaderAnchor? anchor;

  ReaderTextSelection withAnchor(ReaderAnchor? anchor) => ReaderTextSelection(
    pageNumber: pageNumber,
    text: text,
    rects: rects,
    contextBefore: contextBefore,
    contextAfter: contextAfter,
    anchor: anchor,
  );

  @override
  bool operator ==(Object other) =>
      other is ReaderTextSelection &&
      other.pageNumber == pageNumber &&
      other.text == text &&
      _listEq(other.rects, rects) &&
      other.contextBefore == contextBefore &&
      other.contextAfter == contextAfter &&
      other.anchor == anchor;

  @override
  int get hashCode => Object.hash(
    pageNumber,
    text,
    Object.hashAll(rects),
    contextBefore,
    contextAfter,
    anchor,
  );
}

/// FindBar state. The viewport runs the search and reports [total] /
/// [current]; [serial] increments on every next/previous request.
@immutable
class ReaderSearchState {
  const ReaderSearchState({
    this.open = false,
    this.query = '',
    this.matchCase = false,
    this.total = 0,
    this.current = 0,
    this.serial = 0,
    this.forward = true,
  });

  final bool open;
  final String query;
  final bool matchCase;

  /// Number of matches found so far.
  final int total;

  /// 1-based index of the current match, 0 = none.
  final int current;

  /// Bumped on every next/previous request.
  final int serial;

  /// Direction of the latest request.
  final bool forward;

  ReaderSearchState copyWith({
    bool? open,
    String? query,
    bool? matchCase,
    int? total,
    int? current,
    int? serial,
    bool? forward,
  }) => ReaderSearchState(
    open: open ?? this.open,
    query: query ?? this.query,
    matchCase: matchCase ?? this.matchCase,
    total: total ?? this.total,
    current: current ?? this.current,
    serial: serial ?? this.serial,
    forward: forward ?? this.forward,
  );

  @override
  bool operator ==(Object other) =>
      other is ReaderSearchState &&
      other.open == open &&
      other.query == query &&
      other.matchCase == matchCase &&
      other.total == total &&
      other.current == current &&
      other.serial == serial &&
      other.forward == forward;

  @override
  int get hashCode =>
      Object.hash(open, query, matchCase, total, current, serial, forward);
}

/// A one-shot navigation command for the viewport (page buttons, jump to
/// highlight / reference). [serial] makes repeated jumps to the same page
/// distinct.
@immutable
class ReaderNavRequest {
  const ReaderNavRequest({
    required this.pageNumber,
    required this.serial,
    this.rect,
  });

  final int pageNumber;

  /// Optional page-normalised rect to bring into view.
  final Rect? rect;
  final int serial;

  @override
  bool operator ==(Object other) =>
      other is ReaderNavRequest &&
      other.pageNumber == pageNumber &&
      other.rect == rect &&
      other.serial == serial;

  @override
  int get hashCode => Object.hash(pageNumber, rect, serial);
}

/// A one-shot zoom command for the viewport (step zoom, fit, reset).
@immutable
class ReaderZoomRequest {
  const ReaderZoomRequest({
    required this.zoom,
    required this.fit,
    required this.serial,
  });

  final double zoom;
  final ReaderFitMode fit;
  final int serial;

  @override
  bool operator ==(Object other) =>
      other is ReaderZoomRequest &&
      other.zoom == zoom &&
      other.fit == fit &&
      other.serial == serial;

  @override
  int get hashCode => Object.hash(zoom, fit, serial);
}

/// Citation popover target.
@immutable
class ReaderCitationTarget {
  const ReaderCitationTarget({
    required this.label,
    required this.anchor,
    this.referenceText,
    this.targetPage,
    this.url,
    this.resolving = false,
  });

  /// Marker as printed (`[12]`, `(Vaswani et al., 2017)`).
  final String label;
  final ReaderAnchor anchor;

  /// Raw reference entry text parsed from the PDF; null = not resolvable.
  final String? referenceText;

  /// Page of the reference entry (link dest or parsed references section).
  final int? targetPage;

  /// External link in the PDF annotation, if any.
  final Uri? url;

  /// The references section is still being parsed (skeleton state).
  final bool resolving;

  ReaderCitationTarget withAnchor(ReaderAnchor anchor) => ReaderCitationTarget(
    label: label,
    anchor: anchor,
    referenceText: referenceText,
    targetPage: targetPage,
    url: url,
    resolving: resolving,
  );

  @override
  bool operator ==(Object other) =>
      other is ReaderCitationTarget &&
      other.resolving == resolving &&
      other.label == label &&
      other.anchor == anchor &&
      other.referenceText == referenceText &&
      other.targetPage == targetPage &&
      other.url == url;

  @override
  int get hashCode =>
      Object.hash(label, anchor, referenceText, targetPage, url, resolving);
}

/// Sentinel for nullable copyWith arguments.
const Object _unset = Object();

/// Everything the reader UI renders. Immutable; owned by `ReaderController`.
@immutable
class ReaderState {
  const ReaderState({
    required this.paperId,
    this.paper,
    this.phase = const ReaderResolving(),
    this.currentPage = 1,
    this.pageCount = 0,
    this.zoom = 1.0,
    this.fit = ReaderFitMode.width,
    this.tool = ReaderTool.select,
    this.eraser = false,
    this.highlightColor = HighlightColor.defaultColor,
    this.selection,
    this.selectedHighlightId,
    this.selectedHighlightAnchor,
    this.citation,
    this.panelOpen = false,
    this.panelTab = ReaderPanelTab.notes,
    this.search = const ReaderSearchState(),
    this.gestureInProgress = false,
    this.overlaysHidden = false,
    this.hasTextLayer = true,
    this.navRequest,
    this.zoomRequest,
    this.returnPage,
    this.flashHighlightId,
    this.flashSerial = 0,
  });

  final String paperId;
  final Paper? paper;
  final ReaderLoadPhase phase;

  /// 1-based page at the viewport centre.
  final int currentPage;
  final int pageCount;

  /// Current zoom factor (1.0 = 100%).
  final double zoom;
  final ReaderFitMode fit;
  final ReaderTool tool;

  /// Eraser toggle (ToolDock) or stylus eraser end in use.
  final bool eraser;

  /// Last used highlight colour (the `H` default).
  final HighlightColor highlightColor;
  final ReaderTextSelection? selection;
  final String? selectedHighlightId;

  /// Where the `HighlightPicker` anchors.
  final ReaderAnchor? selectedHighlightAnchor;
  final ReaderCitationTarget? citation;
  final bool panelOpen;
  final ReaderPanelTab panelTab;
  final ReaderSearchState search;

  /// A pan / pinch / split-drag / stylus stroke is in progress. Popovers
  /// hide and nothing re-lays the viewport while this is true.
  final bool gestureInProgress;

  /// Popovers hidden while the page moves under them (motion #12).
  final bool overlaysHidden;

  /// False for scanned PDFs (`readerNoTextLayer`).
  final bool hasTextLayer;
  final ReaderNavRequest? navRequest;
  final ReaderZoomRequest? zoomRequest;

  /// "Back to page N" pill after a jump; null = hidden.
  final int? returnPage;

  /// Highlight to ring-flash after a jump (motion #31); [flashSerial] bumps.
  final String? flashHighlightId;
  final int flashSerial;

  bool get isReady => phase is ReaderReady;

  /// True while any transient popover is up.
  bool get hasPopover =>
      selection != null || selectedHighlightId != null || citation != null;

  ReaderState copyWith({
    Object? paper = _unset,
    ReaderLoadPhase? phase,
    int? currentPage,
    int? pageCount,
    double? zoom,
    ReaderFitMode? fit,
    ReaderTool? tool,
    bool? eraser,
    HighlightColor? highlightColor,
    Object? selection = _unset,
    Object? selectedHighlightId = _unset,
    Object? selectedHighlightAnchor = _unset,
    Object? citation = _unset,
    bool? panelOpen,
    ReaderPanelTab? panelTab,
    ReaderSearchState? search,
    bool? gestureInProgress,
    bool? overlaysHidden,
    bool? hasTextLayer,
    Object? navRequest = _unset,
    Object? zoomRequest = _unset,
    Object? returnPage = _unset,
    Object? flashHighlightId = _unset,
    int? flashSerial,
  }) => ReaderState(
    paperId: paperId,
    paper: identical(paper, _unset) ? this.paper : paper as Paper?,
    phase: phase ?? this.phase,
    currentPage: currentPage ?? this.currentPage,
    pageCount: pageCount ?? this.pageCount,
    zoom: zoom ?? this.zoom,
    fit: fit ?? this.fit,
    tool: tool ?? this.tool,
    eraser: eraser ?? this.eraser,
    highlightColor: highlightColor ?? this.highlightColor,
    selection: identical(selection, _unset)
        ? this.selection
        : selection as ReaderTextSelection?,
    selectedHighlightId: identical(selectedHighlightId, _unset)
        ? this.selectedHighlightId
        : selectedHighlightId as String?,
    selectedHighlightAnchor: identical(selectedHighlightAnchor, _unset)
        ? this.selectedHighlightAnchor
        : selectedHighlightAnchor as ReaderAnchor?,
    citation: identical(citation, _unset)
        ? this.citation
        : citation as ReaderCitationTarget?,
    panelOpen: panelOpen ?? this.panelOpen,
    panelTab: panelTab ?? this.panelTab,
    search: search ?? this.search,
    gestureInProgress: gestureInProgress ?? this.gestureInProgress,
    overlaysHidden: overlaysHidden ?? this.overlaysHidden,
    hasTextLayer: hasTextLayer ?? this.hasTextLayer,
    navRequest: identical(navRequest, _unset)
        ? this.navRequest
        : navRequest as ReaderNavRequest?,
    zoomRequest: identical(zoomRequest, _unset)
        ? this.zoomRequest
        : zoomRequest as ReaderZoomRequest?,
    returnPage: identical(returnPage, _unset)
        ? this.returnPage
        : returnPage as int?,
    flashHighlightId: identical(flashHighlightId, _unset)
        ? this.flashHighlightId
        : flashHighlightId as String?,
    flashSerial: flashSerial ?? this.flashSerial,
  );
}

bool _listEq<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
