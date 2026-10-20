import 'dart:async';

import 'package:flutter/material.dart';

import '../../../theme/paper_tokens.dart';

/// Per-page interactive overlay (motion.md §1.4 B3): ring around the
/// highlight whose picker is open, the jump flash ring (motion #31) and the
/// figure rectangle being dragged (motion #40). Rects are page-normalised.
///
/// Lives in its own [RepaintBoundary] so a flash or a ring never repaints
/// the page raster or the multiply washes.
class PageInteractionOverlay extends StatefulWidget {
  const PageInteractionOverlay({
    super.key,
    this.ringRects = const <Rect>[],
    this.ringColor,
    this.flashRects = const <Rect>[],
    this.flashSerial = 0,
    this.figureDraft,
  });

  final List<Rect> ringRects;
  final Color? ringColor;
  final List<Rect> flashRects;

  /// Bump to replay the flash.
  final int flashSerial;
  final Rect? figureDraft;

  bool get isEmpty =>
      ringRects.isEmpty && flashRects.isEmpty && figureDraft == null;

  @override
  State<PageInteractionOverlay> createState() => _PageInteractionOverlayState();
}

class _PageInteractionOverlayState extends State<PageInteractionOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flash = AnimationController(vsync: this);
  late final Animation<double> _flashAlpha = TweenSequence<double>(
    <TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 0,
          end: 1,
        ).chain(CurveTween(curve: PaperMotion.decelerate)),
        weight: PaperMotion.fast.inMilliseconds.toDouble(),
      ),
      TweenSequenceItem<double>(
        tween: ConstantTween<double>(1),
        weight: PaperMotion.emphasis.inMilliseconds.toDouble(),
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1,
          end: 0,
        ).chain(CurveTween(curve: PaperMotion.standard)),
        weight: PaperMotion.slow.inMilliseconds.toDouble(),
      ),
    ],
  ).animate(_flash);
  Timer? _staticFlash;
  final ValueNotifier<double> _staticAlpha = ValueNotifier<double>(0);
  int _playedSerial = 0;

  static const Duration _flashTotal = Duration(milliseconds: 150 + 420 + 300);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybePlay();
  }

  @override
  void didUpdateWidget(PageInteractionOverlay old) {
    super.didUpdateWidget(old);
    _maybePlay();
  }

  void _maybePlay() {
    if (widget.flashRects.isEmpty || widget.flashSerial == _playedSerial) {
      return;
    }
    _playedSerial = widget.flashSerial;
    if (MediaQuery.disableAnimationsOf(context)) {
      // Reduced motion: static ring for 1 s, then removed instantly.
      _staticFlash?.cancel();
      _staticAlpha.value = 1;
      _staticFlash = Timer(const Duration(seconds: 1), () {
        _staticAlpha.value = 0;
      });
    } else {
      _flash
        ..duration = _flashTotal
        ..forward(from: 0);
    }
  }

  @override
  void dispose() {
    _staticFlash?.cancel();
    _staticAlpha.dispose();
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<PaperColors>()!;
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _OverlayPainter(
            ringRects: widget.ringRects,
            ringColor: widget.ringColor ?? c.focusRingOnPaper,
            flashRects: widget.flashRects,
            flashColor: c.focusRingOnPaper,
            flash: Listenable.merge(<Listenable>[_flashAlpha, _staticAlpha]),
            flashAlpha: () => _flash.isAnimating || _flash.value > 0
                ? _flashAlpha.value
                : _staticAlpha.value,
            figureDraft: widget.figureDraft,
            draftColor: c.focusRingOnPaper,
            scrim: c.scrim,
          ),
        ),
      ),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  _OverlayPainter({
    required this.ringRects,
    required this.ringColor,
    required this.flashRects,
    required this.flashColor,
    required Listenable flash,
    required this.flashAlpha,
    required this.figureDraft,
    required this.draftColor,
    required this.scrim,
  }) : super(repaint: flash);

  final List<Rect> ringRects;
  final Color ringColor;
  final List<Rect> flashRects;
  final Color flashColor;
  final double Function() flashAlpha;
  final Rect? figureDraft;
  final Color draftColor;
  final Color scrim;

  Rect _scale(Rect r, Size s) => Rect.fromLTRB(
    r.left * s.width,
    r.top * s.height,
    r.right * s.width,
    r.bottom * s.height,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = PaperHighlightColors.hoverRingWidth
      ..color = ringColor;
    for (final r in ringRects) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          _scale(r, size).inflate(1),
          const Radius.circular(PaperHighlightColors.cornerRadius),
        ),
        ring,
      );
    }
    final a = flashAlpha();
    if (a > 0 && flashRects.isNotEmpty) {
      final flash = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = PaperHighlightColors.focusRingWidth
        ..color = flashColor.withValues(alpha: a);
      for (final r in flashRects) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            _scale(r, size).inflate(2),
            const Radius.circular(PaperHighlightColors.cornerRadius + 2),
          ),
          flash,
        );
      }
    }
    final draft = figureDraft;
    if (draft != null) {
      final rect = _scale(draft, size);
      final outside = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addRect(rect);
      canvas.drawPath(outside, Paint()..color = scrim);
      _dashedRect(canvas, rect, draftColor);
      final handle = Paint()..color = const Color(0xFFFFFFFF);
      final handleStroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = draftColor;
      for (final p in <Offset>[
        rect.topLeft,
        rect.topRight,
        rect.bottomLeft,
        rect.bottomRight,
      ]) {
        final h = Rect.fromCenter(center: p, width: 8, height: 8);
        canvas
          ..drawRect(h, handle)
          ..drawRect(h, handleStroke);
      }
    }
  }

  void _dashedRect(Canvas canvas, Rect r, Color color) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color;
    void dashLine(Offset a, Offset b) {
      final len = (b - a).distance;
      if (len == 0) return;
      final dir = (b - a) / len;
      var t = 0.0;
      while (t < len) {
        final end = (t + 4).clamp(0.0, len);
        canvas.drawLine(a + dir * t, a + dir * end, p);
        t += 7; // 4 on, 3 off
      }
    }

    dashLine(r.topLeft, r.topRight);
    dashLine(r.topRight, r.bottomRight);
    dashLine(r.bottomRight, r.bottomLeft);
    dashLine(r.bottomLeft, r.topLeft);
  }

  @override
  bool shouldRepaint(_OverlayPainter old) =>
      old.ringRects != ringRects ||
      old.ringColor != ringColor ||
      old.flashRects != flashRects ||
      old.figureDraft != figureDraft ||
      old.draftColor != draftColor;
}
