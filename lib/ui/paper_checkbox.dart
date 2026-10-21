import 'package:flutter/material.dart';

import '../theme/paper_tokens.dart';
import 'paper_focus_ring.dart';

/// Chromium's dark native checkbox, as painted on paper.college
/// (components.md §5.1). [size] 16 (`h-4`, tables/dialogs) or 20 (`h-5`,
/// the web "switch": every restyled `Switch` becomes this).
///
/// `value == null` is indeterminate (requires [tristate]).
class PaperCheckbox extends StatelessWidget {
  const PaperCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 16,
    this.tristate = false,
    this.semanticLabel,
    this.focusGap = PaperWeb.gray950,
    this.focusNode,
  });

  final bool? value;
  final ValueChanged<bool?>? onChanged;
  final double size;
  final bool tristate;
  final String? semanticLabel;
  final Color focusGap;
  final FocusNode? focusNode;

  static const Color _uncheckedFill = Color(0xFF3B3B3B);
  static const Color _uncheckedBorder = Color(0xFF858585);
  static const Color _mark = Color(0xFF0A0A0A);

  void _toggle() {
    final next = switch (value) {
      false => true,
      true => tristate ? null : false,
      null => false,
    };
    onChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) => PaperPressable(
    onPressed: onChanged == null ? null : _toggle,
    focusNode: focusNode,
    button: false,
    semanticLabel: semanticLabel,
    toggled: null,
    builder: (context, states) {
      final on = value != false;
      final hover = states.contains(WidgetState.hovered);
      final box = AnimatedContainer(
        duration: PaperMotion.of(context, PaperMotion.colors),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: on ? PaperWeb.accent : _uncheckedFill,
          borderRadius: PaperRadii.borderXs,
          border: on
              ? null
              : Border.all(color: hover ? PaperWeb.gray400 : _uncheckedBorder),
        ),
        child: on
            ? CustomPaint(painter: _MarkPainter(indeterminate: value == null))
            : null,
      );
      return Semantics(
        checked: value ?? false,
        mixed: tristate && value == null,
        child: Opacity(
          opacity: states.contains(WidgetState.disabled) ? 0.5 : 1,
          child: PaperFocusRing(
            show: states.contains(WidgetState.focused),
            radius: PaperRadii.borderXs,
            gap: focusGap,
            child: box,
          ),
        ),
      );
    },
  );
}

class _MarkPainter extends CustomPainter {
  _MarkPainter({required this.indeterminate});
  final bool indeterminate;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 16;
    if (indeterminate) {
      canvas.drawRect(
        Rect.fromCenter(
          center: size.center(Offset.zero),
          width: 8 * s,
          height: 2 * s,
        ),
        Paint()..color = PaperCheckbox._mark,
      );
      return;
    }
    final p = Path()
      ..moveTo(3.5 * s, 8.2 * s)
      ..lineTo(6.6 * s, 11.2 * s)
      ..lineTo(12.5 * s, 4.8 * s);
    canvas.drawPath(
      p,
      Paint()
        ..color = PaperCheckbox._mark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * s
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.indeterminate != indeterminate;
}

/// A checkbox with its label as one hit target (`<label>`): checkbox, gap
/// 8, `sm` 14/20 gray-300 text. For settings rows use [PaperCheckbox] with
/// size 20 right-aligned instead.
class PaperCheckboxRow extends StatelessWidget {
  const PaperCheckboxRow({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.size = 16,
    this.focusGap = PaperWeb.gray900,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String label;
  final double size;
  final Color focusGap;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(top: (20 - size) / 2),
            child: PaperCheckbox(
              value: value,
              size: size,
              focusGap: focusGap,
              onChanged: onChanged == null
                  ? null
                  : (v) => onChanged!(v ?? false),
            ),
          ),
          const SizedBox(width: PaperSpacing.tw2),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: PaperWeb.gray300),
            ),
          ),
        ],
      ),
    ),
  );
}
