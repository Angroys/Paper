import 'package:flutter/widgets.dart';

import '../../../domain/domain.dart';
import '../../../theme/paper_tokens.dart';
import '../pdf_geometry.dart';

/// Maps the domain hue to the token hue (same names, same order).
PaperHighlightColor paperHue(HighlightColor c) =>
    PaperHighlightColor.values.byName(c.name);

/// Pre-computed wash geometry for one page (hue -> merged rects), so the
/// painter does no work beyond drawing.
@immutable
class PageWash {
  const PageWash({required this.byHue, this.figures = const <Rect>[]});

  factory PageWash.of(
    Iterable<Highlight> highlights,
    Iterable<FigureHighlight> figures,
    int pageNumber,
  ) => PageWash(
    byHue: washRectsByHue(highlights, pageNumber),
    figures: <Rect>[
      for (final f in figures)
        if (f.pageNumber == pageNumber) figureBBoxToRect(f.bbox),
    ],
  );

  static const PageWash empty = PageWash(byHue: <HighlightColor, List<Rect>>{});

  final Map<HighlightColor, List<Rect>> byHue;
  final List<Rect> figures;

  bool get isEmpty => byHue.isEmpty && figures.isEmpty;

  @override
  bool operator ==(Object other) {
    if (other is! PageWash) return false;
    if (other.byHue.length != byHue.length ||
        other.figures.length != figures.length) {
      return false;
    }
    for (final e in byHue.entries) {
      final o = other.byHue[e.key];
      if (o == null || o.length != e.value.length) return false;
      for (var i = 0; i < o.length; i++) {
        if (o[i] != e.value[i]) return false;
      }
    }
    for (var i = 0; i < figures.length; i++) {
      if (figures[i] != other.figures[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(byHue.keys),
    Object.hashAll(byHue.values.expand((r) => r)),
    Object.hashAll(figures),
  );
}

/// Static highlight washes for one page (motion.md §1.4 B2 content).
///
/// Painted in page-point space ([pageSize]) and scaled to the on-screen page
/// rect by a [FittedBox] transform, so scrolling and zooming move / scale a
/// cached layer: the picture is re-recorded only when [wash] changes
/// (highlight created, recoloured, deleted: motion #29/#30).
class HighlightWashLayer extends StatelessWidget {
  const HighlightWashLayer({
    super.key,
    required this.wash,
    required this.pageSize,
    required this.colors,
  });

  final PageWash wash;

  /// Page size in PDF points (aspect ratio of the page).
  final Size pageSize;
  final PaperHighlightColors colors;

  @override
  Widget build(BuildContext context) {
    if (wash.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: FittedBox(
        fit: BoxFit.fill,
        alignment: Alignment.topLeft,
        child: SizedBox.fromSize(
          size: pageSize,
          child: RepaintBoundary(
            child: CustomPaint(
              size: pageSize,
              painter: HighlightWashPainter(wash: wash, colors: colors),
              isComplex: true,
              willChange: false,
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints one layer per hue: opaque wash rects inside a `saveLayer` whose
/// paint carries the hue alpha and the blend mode (multiply on white paper).
/// Same-hue overlaps are merged and composited once, so they never darken
/// (tokens README §5; components.md HighlightMark).
class HighlightWashPainter extends CustomPainter {
  HighlightWashPainter({required this.wash, required this.colors});

  final PageWash wash;
  final PaperHighlightColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final radius = Radius.circular(
      PaperHighlightColors.cornerRadius *
          (size.width / 600).clamp(0.5, 2.0).toDouble(),
    );
    final fill = Paint()..isAntiAlias = true;
    for (final entry in wash.byHue.entries) {
      final hue = paperHue(entry.key);
      canvas.saveLayer(
        bounds,
        Paint()
          ..color = Color.fromRGBO(0, 0, 0, colors.restAlpha)
          ..blendMode = colors.blendMode,
      );
      fill.color = hue.wash;
      for (final r in entry.value) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(_scale(r, size), radius),
          fill,
        );
      }
      canvas.restore();
    }
    if (wash.figures.isNotEmpty) {
      // Saved figure highlight: hue wash at the AI-mark rest alpha + 2dp ring
      // (components.md FigureSelectionBox). Figures carry no colour in the
      // domain model: default hue.
      final hue = paperHue(HighlightColor.defaultColor);
      final figFill = Paint()
        ..color = hue.wash.withValues(alpha: PaperReaderMark.restAlpha)
        ..blendMode = colors.blendMode;
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * size.width / 600
        ..color = hue.ring;
      for (final r in wash.figures) {
        final rect = _scale(r, size);
        canvas
          ..drawRect(rect, figFill)
          ..drawRect(rect, ring);
      }
    }
  }

  static Rect _scale(Rect r, Size s) => Rect.fromLTRB(
    r.left * s.width,
    r.top * s.height,
    r.right * s.width,
    r.bottom * s.height,
  );

  @override
  bool shouldRepaint(HighlightWashPainter old) =>
      old.wash != wash ||
      old.colors.restAlpha != colors.restAlpha ||
      old.colors.blendMode != colors.blendMode;
}
