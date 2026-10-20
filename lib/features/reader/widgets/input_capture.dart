import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../stylus.dart';

/// Live stroke / figure-drag state in viewer-local coordinates. Mutated at
/// pointer rate; the [InkLayer] painter listens and repaints only its own
/// layer (motion.md §1.4 B4). Repaints coalesce to one per frame because
/// `markNeedsPaint` only schedules a single frame.
class LiveStroke extends ChangeNotifier {
  final List<Offset> _points = <Offset>[];
  InputRoute? _route;

  List<Offset> get points => List<Offset>.unmodifiable(_points);
  InputRoute? get route => _route;
  bool get isActive => _route != null;

  /// Figure rectangle (first point to latest point).
  Rect? get figureRect => _route == InputRoute.figure && _points.isNotEmpty
      ? Rect.fromPoints(_points.first, _points.last)
      : null;

  void begin(InputRoute route, Offset p) {
    _route = route;
    _points
      ..clear()
      ..add(p);
    notifyListeners();
  }

  void add(Offset p) {
    if (_route == null) return;
    if (_route == InputRoute.figure && _points.length > 1) {
      _points[1] = p;
    } else {
      _points.add(p);
    }
    notifyListeners();
  }

  void clear() {
    if (_route == null && _points.isEmpty) return;
    _route = null;
    _points.clear();
    notifyListeners();
  }
}

/// Decides what a pointer down does (see [routePointer]).
typedef InputRouter = InputRoute Function(PointerDownEvent event);

/// Called when a captured stroke ends, with its points in viewer-local
/// coordinates.
typedef StrokeEnd = void Function(
  InputRoute route,
  List<Offset> points,
  PointerDeviceKind kind,
);

/// Wraps the PDF viewer and claims pointers the active tool owns (pen /
/// highlighter stroke, eraser, figure rectangle, palm-rejected touches)
/// **on pointer down**, so the viewer never pans for them, while every other
/// pointer (finger scroll / pinch in Pen mode, mouse wheel) reaches the
/// viewer untouched. Uses raw pointer events (motion #39), not drag
/// recognizers with slop, so ink follows within a frame.
class ReaderInputCapture extends StatefulWidget {
  const ReaderInputCapture({
    super.key,
    required this.child,
    required this.router,
    required this.stroke,
    required this.onStrokeEnd,
    this.onStylusSeen,
    this.onActiveChanged,
  });

  final Widget child;
  final InputRouter router;
  final LiveStroke stroke;
  final StrokeEnd onStrokeEnd;

  /// Any stylus pointer down / hover (auto-switch to Pen, palm rejection).
  final ValueChanged<PointerEvent>? onStylusSeen;

  /// A captured gesture started (true) or ended (false).
  final ValueChanged<bool>? onActiveChanged;

  @override
  State<ReaderInputCapture> createState() => _ReaderInputCaptureState();
}

class _ReaderInputCaptureState extends State<ReaderInputCapture> {
  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) {
        if (isStylus(e.kind)) widget.onStylusSeen?.call(e);
      },
      onPointerHover: (e) {
        if (isStylus(e.kind)) widget.onStylusSeen?.call(e);
      },
      child: RawGestureDetector(
        behavior: HitTestBehavior.translucent,
        gestures: <Type, GestureRecognizerFactory>{
          _ClaimRecognizer:
              GestureRecognizerFactoryWithHandlers<_ClaimRecognizer>(
                () => _ClaimRecognizer(debugOwner: this),
                (r) => r
                  ..router = widget.router
                  ..onStart = _onStart
                  ..onUpdate = _onUpdate
                  ..onEnd = _onEnd
                  ..onCancel = _onCancel,
              ),
        },
        child: widget.child,
      ),
    );
  }

  PointerDeviceKind _kind = PointerDeviceKind.touch;

  void _onStart(InputRoute route, PointerDownEvent e) {
    if (route == InputRoute.reject) return;
    _kind = e.kind;
    widget.stroke.begin(route, e.localPosition);
    widget.onActiveChanged?.call(true);
  }

  void _onUpdate(PointerEvent e) => widget.stroke.add(e.localPosition);

  void _onEnd(PointerEvent e) {
    final route = widget.stroke.route;
    if (route == null) return;
    final points = widget.stroke.points;
    widget.onStrokeEnd(route, points, _kind);
    widget.stroke.clear();
    widget.onActiveChanged?.call(false);
  }

  void _onCancel() {
    if (!widget.stroke.isActive) return;
    widget.stroke.clear();
    widget.onActiveChanged?.call(false);
  }
}

/// Wins the arena on pointer down for routed pointers (eager winner), so
/// the viewer's pan/scale/selection recognizers are rejected for them.
class _ClaimRecognizer extends OneSequenceGestureRecognizer {
  _ClaimRecognizer({super.debugOwner});

  late InputRouter router;
  late void Function(InputRoute route, PointerDownEvent e) onStart;
  late void Function(PointerEvent e) onUpdate;
  late void Function(PointerEvent e) onEnd;
  late VoidCallback onCancel;

  int? _active;
  final Set<int> _rejected = <int>{};

  @override
  void addAllowedPointer(PointerDownEvent event) {
    final route = router(event);
    if (route == InputRoute.viewer) return;
    startTrackingPointer(event.pointer, event.transform);
    resolvePointer(event.pointer, GestureDisposition.accepted);
    if (route == InputRoute.reject || _active != null) {
      _rejected.add(event.pointer);
      return;
    }
    _active = event.pointer;
    onStart(route, event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (_rejected.contains(event.pointer)) {
      if (event is PointerUpEvent || event is PointerCancelEvent) {
        _rejected.remove(event.pointer);
        stopTrackingPointer(event.pointer);
      }
      return;
    }
    if (event.pointer != _active) return;
    if (event is PointerMoveEvent) {
      onUpdate(event);
    } else if (event is PointerUpEvent) {
      onEnd(event);
      _active = null;
      stopTrackingPointer(event.pointer);
    } else if (event is PointerCancelEvent) {
      onCancel();
      _active = null;
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void rejectGesture(int pointer) {
    if (pointer == _active) {
      onCancel();
      _active = null;
    }
    _rejected.remove(pointer);
    stopTrackingPointer(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'readerInputCapture';
}

/// Live highlighter stroke + figure drag box (motion.md §1.4 B4). Painted in
/// its own [RepaintBoundary] at input rate; never touches the page raster.
class InkLayer extends StatelessWidget {
  const InkLayer({
    super.key,
    required this.stroke,
    required this.inkColor,
    required this.strokeWidth,
    required this.figureColor,
    required this.eraserColor,
  });

  final LiveStroke stroke;
  final Color inkColor;
  final double strokeWidth;
  final Color figureColor;
  final Color eraserColor;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _InkPainter(
            stroke: stroke,
            inkColor: inkColor,
            strokeWidth: strokeWidth,
            figureColor: figureColor,
            eraserColor: eraserColor,
          ),
        ),
      ),
    );
  }
}

class _InkPainter extends CustomPainter {
  _InkPainter({
    required this.stroke,
    required this.inkColor,
    required this.strokeWidth,
    required this.figureColor,
    required this.eraserColor,
  }) : super(repaint: stroke);

  final LiveStroke stroke;
  final Color inkColor;
  final double strokeWidth;
  final Color figureColor;
  final Color eraserColor;

  @override
  void paint(Canvas canvas, Size size) {
    final route = stroke.route;
    final points = stroke.points;
    if (route == null || points.isEmpty) return;
    if (route == InputRoute.figure) {
      final r = stroke.figureRect!;
      canvas.drawRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = figureColor,
      );
      return;
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    if (points.length == 1) {
      path.lineTo(points.first.dx + 0.01, points.first.dy);
    }
    final erase = route == InputRoute.erase;
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = erase ? StrokeCap.round : StrokeCap.square
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = erase ? 16 : strokeWidth
        ..color = erase ? eraserColor.withValues(alpha: 0.25) : inkColor,
    );
  }

  @override
  bool shouldRepaint(_InkPainter old) =>
      old.stroke != stroke ||
      old.inkColor != inkColor ||
      old.strokeWidth != strokeWidth;
}
