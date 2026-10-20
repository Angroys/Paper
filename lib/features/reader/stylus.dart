// Pure stylus logic: snapping a pen stroke to text, eraser hit-testing and
// palm rejection. No widgets; unit-tested in test/reader/stylus_test.dart.

import 'dart:math' as math;
import 'dart:ui' show Offset, PointerDeviceKind, Rect;

import '../../domain/domain.dart';
import 'pdf_geometry.dart';
import 'reader_state.dart';

/// Palm-rejection window after the stylus lifts (layout-system.md §6).
const Duration kPalmRejectionWindow = Duration(milliseconds: 300);

/// A char range `[start, end)` in a page's text.
typedef TextRange = ({int start, int end});

/// Snaps a pen stroke to the text under it.
///
/// [stroke] is the polyline in page-normalised coordinates. A char is hit
/// when its box comes within [halfWidth] (normalised, half the stroke's
/// visual height) of the stroke and at least [minCoverage] of its height
/// lies inside the stroke band, so grazing the line above or below does not
/// select it. The result spans the first to the last hit char in text order
/// (the same range a drag selection would give), or null when the stroke
/// crosses no text (then it is a freeform ink mark).
TextRange? snapStrokeToText(
  List<Offset> stroke,
  ReaderPageText page, {
  required double halfWidth,
  double minCoverage = 0.35,
}) {
  if (stroke.isEmpty || page.charRects.isEmpty) return null;
  final points = densifyStroke(stroke, step: math.max(halfWidth * 0.5, 1e-4));
  var first = -1;
  var last = -1;
  for (var i = 0; i < page.charRects.length; i++) {
    final r = page.charRects[i];
    if (r.isEmpty || page.text.codeUnitAt(i) <= 0x20) continue;
    if (_strokeCoversChar(points, r, halfWidth, minCoverage)) {
      if (first < 0) first = i;
      last = i;
    }
  }
  if (first < 0) return null;
  return (start: first, end: last + 1);
}

bool _strokeCoversChar(
  List<Offset> points,
  Rect r,
  double halfWidth,
  double minCoverage,
) {
  for (final p in points) {
    if (p.dx < r.left - halfWidth * 0.25 || p.dx > r.right + halfWidth * 0.25) {
      continue;
    }
    final bandTop = p.dy - halfWidth;
    final bandBottom = p.dy + halfWidth;
    final covered = math.min(bandBottom, r.bottom) - math.max(bandTop, r.top);
    if (covered >= r.height * minCoverage) return true;
  }
  return false;
}

/// Inserts points so consecutive points are at most [step] apart (pointer
/// events are sparse on fast strokes).
List<Offset> densifyStroke(List<Offset> stroke, {required double step}) {
  if (stroke.length < 2) return List<Offset>.of(stroke);
  final out = <Offset>[stroke.first];
  for (var i = 1; i < stroke.length; i++) {
    final a = stroke[i - 1];
    final b = stroke[i];
    final d = (b - a).distance;
    final n = (d / step).ceil();
    for (var k = 1; k <= n; k++) {
      out.add(Offset.lerp(a, b, k / n)!);
    }
  }
  return out;
}

/// Ids of the highlights an eraser stroke crosses on [pageNumber].
List<String> highlightsUnderStroke(
  List<Offset> stroke,
  Iterable<Highlight> highlights,
  int pageNumber, {
  required double halfWidth,
}) {
  final points = densifyStroke(stroke, step: math.max(halfWidth * 0.5, 1e-4));
  final hits = <String>[];
  for (final h in highlights) {
    final rects = highlightRectsOnPage(h, pageNumber);
    final hit = rects.any(
      (r) => points.any((p) => r.inflate(halfWidth).contains(p)),
    );
    if (hit) hits.add(h.id);
  }
  return hits;
}

/// What a pointer down should do, given the active tool and the device.
enum InputRoute {
  /// Let the viewer have it (scroll / pan / zoom / select).
  viewer,

  /// Draw a highlighter stroke.
  ink,

  /// Erase highlights under the stroke.
  erase,

  /// Drag a figure rectangle.
  figure,

  /// Drop it (palm rejection).
  reject,
}

bool isStylus(PointerDeviceKind kind) =>
    kind == PointerDeviceKind.stylus ||
    kind == PointerDeviceKind.invertedStylus;

/// Tracks stylus activity for palm rejection: `touch` pointers are ignored
/// while a stylus is down and for [window] after it lifts. Timestamps are
/// the pointer events' `timeStamp`s, so this is pure and testable.
class PalmRejection {
  PalmRejection({this.window = kPalmRejectionWindow});

  final Duration window;
  final Set<int> _activeStylus = <int>{};
  Duration? _lastStylusUp;

  bool get stylusActive => _activeStylus.isNotEmpty;

  void stylusDown(int pointer) => _activeStylus.add(pointer);

  void stylusUp(int pointer, Duration timeStamp) {
    _activeStylus.remove(pointer);
    _lastStylusUp = timeStamp;
  }

  /// Stylus in proximity (hover) counts as active until it leaves.
  void stylusHover(Duration timeStamp) => _lastStylusUp = timeStamp;

  bool shouldRejectTouch(Duration timeStamp) {
    if (_activeStylus.isNotEmpty) return true;
    final up = _lastStylusUp;
    return up != null && timeStamp - up <= window;
  }
}

/// Routes a pointer down for [tool].
///
/// - Pen: stylus inks (inverted stylus or [eraser] erases); finger and mouse
///   go to the viewer, except touches inside the palm-rejection window.
/// - Highlight: any single pointer drags a highlight (inverted stylus
///   erases).
/// - Figure: any pointer drags a rectangle.
/// - Select: the viewer (selection); palm rejection still applies.
InputRoute routePointer({
  required ReaderTool tool,
  required PointerDeviceKind kind,
  required bool eraser,
  required bool rejectTouch,
}) {
  if (kind == PointerDeviceKind.touch && rejectTouch) {
    return InputRoute.reject;
  }
  if (kind == PointerDeviceKind.invertedStylus && tool != ReaderTool.figure) {
    return InputRoute.erase;
  }
  switch (tool) {
    case ReaderTool.select:
      return InputRoute.viewer;
    case ReaderTool.pen:
      if (isStylus(kind)) return eraser ? InputRoute.erase : InputRoute.ink;
      return InputRoute.viewer;
    case ReaderTool.highlight:
      if (kind == PointerDeviceKind.trackpad) return InputRoute.viewer;
      return eraser ? InputRoute.erase : InputRoute.ink;
    case ReaderTool.figure:
      if (kind == PointerDeviceKind.trackpad) return InputRoute.viewer;
      return InputRoute.figure;
  }
}
