// Pure geometry for the reader: page-normalised rects (the RPR
// `highlights.position` convention), line merging, per-hue wash rects and
// selection capture. No Flutter widgets, no pdfrx: unit-testable.
//
// Coordinate convention (matches RPR `src/lib/reader/selection.ts`): every
// rect is page-relative and normalised to 0..1, origin at the page's top-left
// corner; `x`/`width` are fractions of the page width, `y`/`height` of the
// page height. `textLayerScale` is always 1.

import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import '../../domain/domain.dart';
import 'reader_state.dart';

/// Context length on each side of a highlight (RPR DEFAULT_CONTEXT_LENGTH).
const int kHighlightContextLength = 200;

/// The extracted text of one page with page-normalised char rects.
/// `charRects[i]` is the box of `text[i]` (`Rect.zero` when the char has no
/// box, e.g. a synthesised line break).
class ReaderPageText {
  ReaderPageText({
    required this.pageNumber,
    required this.text,
    required this.charRects,
  }) : assert(text.length == charRects.length);

  final int pageNumber;
  final String text;
  final List<Rect> charRects;

  bool get isEmpty => text.trim().isEmpty;

  /// Index of the char whose box contains [point] (normalised), or the
  /// nearest char within [tolerance]; -1 when none.
  int charIndexAt(Offset point, {double tolerance = 0.004}) {
    var best = -1;
    var bestDist = double.infinity;
    for (var i = 0; i < charRects.length; i++) {
      final r = charRects[i];
      if (r.isEmpty) continue;
      if (r.contains(point)) return i;
      final d = _distanceToRect(point, r);
      if (d <= tolerance && d < bestDist) {
        best = i;
        bestDist = d;
      }
    }
    return best;
  }
}

double _distanceToRect(Offset p, Rect r) {
  final dx = math.max(math.max(r.left - p.dx, 0.0), p.dx - r.right);
  final dy = math.max(math.max(r.top - p.dy, 0.0), p.dy - r.bottom);
  return math.sqrt(dx * dx + dy * dy);
}

double _round4(double v) => (v * 10000).roundToDouble() / 10000;
double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

/// Stored rect -> [Rect] (page-normalised).
Rect highlightRectToRect(HighlightRect r) =>
    Rect.fromLTWH(r.x, r.y, r.width, r.height);

/// [Rect] (page-normalised) -> stored rect, clamped to the page and rounded
/// to 4 decimals like RPR.
HighlightRect rectToHighlightRect(Rect r) {
  final left = _clamp01(r.left);
  final top = _clamp01(r.top);
  final right = _clamp01(r.right);
  final bottom = _clamp01(r.bottom);
  return HighlightRect(
    x: _round4(left),
    y: _round4(top),
    width: _round4(right - left),
    height: _round4(bottom - top),
  );
}

/// FigureBBox <-> Rect (both page-normalised).
Rect figureBBoxToRect(FigureBBox b) =>
    Rect.fromLTWH(b.x, b.y, b.width, b.height);

FigureBBox rectToFigureBBox(Rect r) {
  final h = rectToHighlightRect(r);
  return FigureBBox(x: h.x, y: h.y, width: h.width, height: h.height);
}

/// True when [a] and [b] sit on the same text line: they overlap vertically
/// by at least half of the shorter one.
bool sameLine(Rect a, Rect b) {
  final overlap = math.min(a.bottom, b.bottom) - math.max(a.top, b.top);
  final minH = math.min(a.height, b.height);
  if (minH <= 0) return false;
  return overlap >= minH * 0.5;
}

/// Merges char boxes (in text order) into one rect per line run. A new run
/// starts when the next char is on another line or jumps backwards / far
/// right (column change). Empty boxes are skipped.
List<Rect> mergeCharRectsIntoLines(Iterable<Rect> charRects) {
  final runs = <Rect>[];
  Rect? cur;
  for (final r in charRects) {
    if (r.isEmpty || r.width <= 0 || r.height <= 0) continue;
    if (cur == null) {
      cur = r;
      continue;
    }
    final lineH = math.max(cur.height, r.height);
    final gap = r.left - cur.right;
    final continues =
        sameLine(cur, r) && r.left >= cur.left - lineH * 0.5 && gap <= lineH;
    if (continues) {
      cur = cur.expandToInclude(r);
    } else {
      runs.add(cur);
      cur = r;
    }
  }
  if (cur != null) runs.add(cur);
  return runs;
}

/// Unions rects that overlap or touch on the same line, so a hue's wash is a
/// few clean rects (no seams, fewer draw calls). Rects on different lines
/// stay separate.
List<Rect> mergeOverlappingRects(Iterable<Rect> input) {
  final rects = input.where((r) => !r.isEmpty).toList();
  var merged = true;
  while (merged) {
    merged = false;
    outer:
    for (var i = 0; i < rects.length; i++) {
      for (var j = i + 1; j < rects.length; j++) {
        final a = rects[i];
        final b = rects[j];
        final touches = a.left <= b.right + 1e-6 && b.left <= a.right + 1e-6;
        if (touches && sameLine(a, b)) {
          rects[i] = a.expandToInclude(b);
          rects.removeAt(j);
          merged = true;
          break outer;
        }
      }
    }
  }
  rects.sort((a, b) {
    final c = a.top.compareTo(b.top);
    return c != 0 ? c : a.left.compareTo(b.left);
  });
  return rects;
}

/// The page-normalised rects of [h] on [pageNumber] (empty when the
/// highlight is on another page or has no position).
List<Rect> highlightRectsOnPage(Highlight h, int pageNumber) {
  final pos = h.position;
  final page = pos?.pageNumber ?? h.pageNumber;
  if (pos == null || page != pageNumber) return const <Rect>[];
  return pos.rects.map(highlightRectToRect).toList(growable: false);
}

/// Wash geometry for one page: merged rects per hue, in hue order. Each hue
/// is painted as ONE multiply layer at the hue alpha, so overlapping
/// highlights of the same hue never darken.
Map<HighlightColor, List<Rect>> washRectsByHue(
  Iterable<Highlight> highlights,
  int pageNumber,
) {
  final byHue = <HighlightColor, List<Rect>>{};
  for (final h in highlights) {
    final rects = highlightRectsOnPage(h, pageNumber);
    if (rects.isEmpty) continue;
    (byHue[h.color] ??= <Rect>[]).addAll(rects);
  }
  return <HighlightColor, List<Rect>>{
    for (final c in HighlightColor.values)
      if (byHue[c] != null) c: mergeOverlappingRects(byHue[c]!),
  };
}

/// The topmost highlight on [pageNumber] under [point] (normalised), or
/// null. Later highlights win (drawn last).
Highlight? highlightAt(
  Iterable<Highlight> highlights,
  int pageNumber,
  Offset point, {
  double tolerance = 0.002,
}) {
  Highlight? hit;
  for (final h in highlights) {
    for (final r in highlightRectsOnPage(h, pageNumber)) {
      if (r.inflate(tolerance).contains(point)) hit = h;
    }
  }
  return hit;
}

/// Bounding box of [rects], or null for none.
Rect? boundsOf(Iterable<Rect> rects) {
  Rect? b;
  for (final r in rects) {
    b = b == null ? r : b.expandToInclude(r);
  }
  return b;
}

final RegExp _ws = RegExp(r'\s+');
final RegExp _lineBreakHyphen = RegExp(r'(\p{Ll})-\s+(\p{Ll})', unicode: true);

/// RPR `normalizeSelectedText`: collapse whitespace, join words hyphenated
/// across a line break ("se-\nmantic" -> "semantic"), trim.
String normalizeSelectedText(String raw) => raw
    .replaceAll(_ws, ' ')
    .replaceAllMapped(_lineBreakHyphen, (m) => '${m[1]}${m[2]}')
    .trim();

/// Up to [maxLen] chars of normalised context before [start] and after
/// [end] (exclusive) in [fullText].
({String before, String after}) extractContext(
  String fullText,
  int start,
  int end, {
  int maxLen = kHighlightContextLength,
}) {
  final s = start.clamp(0, fullText.length);
  final e = end.clamp(s, fullText.length);
  final rawBefore = fullText.substring(math.max(0, s - maxLen * 2), s);
  final rawAfter = fullText.substring(
    e,
    math.min(fullText.length, e + maxLen * 2),
  );
  final before = rawBefore.replaceAll(_ws, ' ').trimLeft();
  final after = rawAfter.replaceAll(_ws, ' ').trimRight();
  return (
    before: before.length > maxLen
        ? before.substring(before.length - maxLen).trimLeft()
        : before,
    after: after.length > maxLen
        ? after.substring(0, maxLen).trimRight()
        : after,
  );
}

/// Builds the stored selection for chars `[start, end)` of [page], or null
/// when the range holds no visible text.
ReaderTextSelection? selectionFromRange(
  ReaderPageText page,
  int start,
  int end,
) {
  final s = start.clamp(0, page.text.length);
  final e = end.clamp(s, page.text.length);
  if (e <= s) return null;
  final text = normalizeSelectedText(page.text.substring(s, e));
  if (text.isEmpty) return null;
  final lines = mergeCharRectsIntoLines(page.charRects.sublist(s, e));
  if (lines.isEmpty) return null;
  final ctx = extractContext(page.text, s, e);
  final rects = lines.map(rectToHighlightRect).toList(growable: false);
  return ReaderTextSelection(
    pageNumber: page.pageNumber,
    text: text,
    rects: rects,
    contextBefore: ctx.before,
    contextAfter: ctx.after,
    anchor: ReaderAnchor(pageNumber: page.pageNumber, rect: boundsOf(lines)!),
  );
}
