import 'package:flutter/material.dart';

import '../theme/paper_tokens.dart';

/// Tailwind `focus-visible:ring-2 ring-accent ring-offset-2`
/// + `ring-offset-{surface}` (components.md §20): an offset band in [gap]
/// then a [width] ring in [color], painted outside the child's box as a
/// foreground layer (no layout change, never animated).
///
/// [show] should be "focused by keyboard" only; [PaperPressable] computes
/// it via `FocusableActionDetector.onShowFocusHighlight`, which is false in
/// touch highlight mode.
class PaperFocusRing extends StatelessWidget {
  const PaperFocusRing({
    super.key,
    required this.child,
    required this.radius,
    required this.show,
    this.color = PaperWeb.accent,
    this.width = 2,
    this.offset = 2,
    this.gap,
    this.inset = false,
  });

  final Widget child;

  /// The child's own corner radius.
  final BorderRadius radius;
  final bool show;

  /// accent; `red500` for destructive; `markFocusRing` on the PDF.
  final Color color;
  final double width;

  /// ring-offset: 2 (default), 1 (popover buttons, segmented), 0 (icon
  /// buttons, links).
  final double offset;

  /// ring-offset colour = the surface under the child (`#0A0A0A` on the
  /// page, `#171717` in cards/popovers/dialogs). Null paints no band.
  final Color? gap;

  /// ring-inset (list rows): stroke inside the box, no gap.
  final bool inset;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: show
        ? _FocusRingPainter(
            radius: radius,
            color: color,
            width: width,
            offset: offset,
            gap: gap,
            inset: inset,
            textDirection: Directionality.maybeOf(context),
          )
        : null,
    child: child,
  );
}

class _FocusRingPainter extends CustomPainter {
  _FocusRingPainter({
    required this.radius,
    required this.color,
    required this.width,
    required this.offset,
    required this.gap,
    required this.inset,
    required this.textDirection,
  });

  final BorderRadius radius;
  final Color color;
  final double width;
  final double offset;
  final Color? gap;
  final bool inset;
  final TextDirection? textDirection;

  RRect _rrect(Rect rect, double grow) {
    final r = radius.resolve(textDirection);
    Radius g(Radius x) => Radius.elliptical(
      (x.x + grow).clamp(0, double.infinity),
      (x.y + grow).clamp(0, double.infinity),
    );
    return RRect.fromRectAndCorners(
      rect.inflate(grow),
      topLeft: g(r.topLeft),
      topRight: g(r.topRight),
      bottomLeft: g(r.bottomLeft),
      bottomRight: g(r.bottomRight),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = Paint()..style = PaintingStyle.stroke;
    if (inset) {
      canvas.drawRRect(
        _rrect(rect, -width / 2),
        stroke
          ..color = color
          ..strokeWidth = width,
      );
      return;
    }
    if (offset > 0 && gap != null) {
      canvas.drawRRect(
        _rrect(rect, offset / 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = gap!
          ..strokeWidth = offset,
      );
    }
    canvas.drawRRect(
      _rrect(rect, offset + width / 2),
      stroke
        ..color = color
        ..strokeWidth = width,
    );
  }

  @override
  bool shouldRepaint(_FocusRingPainter old) =>
      old.radius != radius ||
      old.color != color ||
      old.width != width ||
      old.offset != offset ||
      old.gap != gap ||
      old.inset != inset;
}

/// Interaction states for web-parity controls: hover (pointer only),
/// pressed, keyboard focus. Calls [builder] with the current
/// [WidgetState]s (`disabled` when [onPressed] is null). No ink, no ripple.
///
/// Enter/Space activate (ActivateIntent), like a `<button>`.
class PaperPressable extends StatefulWidget {
  const PaperPressable({
    super.key,
    required this.onPressed,
    required this.builder,
    this.focusNode,
    this.autofocus = false,
    this.semanticLabel,
    this.tooltip,
    this.selected,
    this.toggled,
    this.button = true,
    this.excludeSemantics = false,
    this.onLongPress,
  });

  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final Widget Function(BuildContext context, Set<WidgetState> states) builder;
  final FocusNode? focusNode;
  final bool autofocus;

  /// Accessible name; with [excludeSemantics] it replaces the child's.
  final String? semanticLabel;

  /// Wraps in a [Tooltip] (icon-only buttons: same text as the label).
  final String? tooltip;
  final bool? selected;
  final bool? toggled;
  final bool button;
  final bool excludeSemantics;

  @override
  State<PaperPressable> createState() => _PaperPressableState();
}

class _PaperPressableState extends State<PaperPressable> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null;

  void _activate() => widget.onPressed?.call();

  @override
  void didUpdateWidget(PaperPressable old) {
    super.didUpdateWidget(old);
    if (!_enabled) {
      _hovered = false;
      _pressed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final states = <WidgetState>{
      if (!_enabled) WidgetState.disabled,
      if (_enabled && _hovered) WidgetState.hovered,
      if (_enabled && _pressed) WidgetState.pressed,
      if (_enabled && _focused) WidgetState.focused,
      if (widget.selected ?? widget.toggled ?? false) WidgetState.selected,
    };
    Widget result = FocusableActionDetector(
      enabled: _enabled,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      mouseCursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onShowHoverHighlight: (v) => setState(() => _hovered = v),
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _activate();
            return null;
          },
        ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
        onTap: _enabled ? _activate : null,
        onLongPress: _enabled ? widget.onLongPress : null,
        child: widget.builder(context, states),
      ),
    );
    result = Semantics(
      button: widget.button,
      enabled: _enabled,
      selected: widget.selected,
      toggled: widget.toggled,
      label: widget.semanticLabel,
      excludeSemantics: widget.excludeSemantics,
      onTap: _enabled ? _activate : null,
      child: result,
    );
    if (widget.tooltip != null) {
      result = Tooltip(
        message: widget.tooltip,
        excludeFromSemantics: true,
        child: result,
      );
    }
    return result;
  }
}

/// Colour-only transition box (Tailwind `transition-colors`, 150 ms,
/// 0 ms under reduced motion).
class PaperColorBox extends StatelessWidget {
  const PaperColorBox({
    super.key,
    required this.child,
    required this.color,
    this.borderColor,
    this.borderWidth = 1,
    this.radius = PaperRadii.borderMd,
    this.padding,
    this.constraints,
    this.boxShadow,
    this.alignment,
  });

  final Widget child;
  final Color color;
  final Color? borderColor;
  final double borderWidth;
  final BorderRadius radius;
  final EdgeInsetsGeometry? padding;
  final BoxConstraints? constraints;
  final List<BoxShadow>? boxShadow;
  final AlignmentGeometry? alignment;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: PaperMotion.of(context, PaperMotion.colors),
    curve: PaperMotion.standard,
    padding: padding,
    constraints: constraints,
    alignment: alignment,
    decoration: BoxDecoration(
      color: color,
      borderRadius: radius,
      border: borderColor == null
          ? null
          : Border.all(color: borderColor!, width: borderWidth),
      boxShadow: boxShadow,
    ),
    child: child,
  );
}
