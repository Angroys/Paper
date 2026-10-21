import 'package:flutter/material.dart';

import '../theme/paper_tokens.dart';
import 'paper_focus_ring.dart';

/// `PaperRating` (components.md §18.2, web `TermRating`): "Rate this
/// explanation" · five 24×24 radius-6 digit squares (gap 4) · "4/5" or
/// "Not rated". Only the chosen value is accent-filled (not 1..n).
///
/// [onRate] null = disabled (@ 0.5, e.g. offline or saving). [onClear]
/// (re-tap on the selected value) is optional; without it a re-tap is a
/// no-op.
class PaperRating extends StatelessWidget {
  const PaperRating({
    super.key,
    required this.value,
    required this.label,
    required this.valueText,
    required this.onRate,
    this.onClear,
    this.tooltip,
    this.semanticValue,
    this.focusGap = PaperWeb.gray900,
  });

  /// 1–5, or null when not rated.
  final int? value;

  /// "Rate this explanation".
  final String label;

  /// "4/5" / "Not rated".
  final String valueText;
  final ValueChanged<int>? onRate;
  final VoidCallback? onClear;

  /// Shown on the row (e.g. why it is disabled).
  final String? tooltip;
  final String? semanticValue;

  /// Surface under the squares (the focus ring's offset band).
  final Color focusGap;

  static Key keyFor(int n) => ValueKey<String>('rating-$n');

  static const TextStyle _caption = TextStyle(
    fontFamily: PaperTypography.sans,
    fontFamilyFallback: PaperTypography.sansFallback,
    fontSize: 12,
    height: 16 / 12,
    leadingDistribution: TextLeadingDistribution.even,
    color: PaperWeb.gray400,
  );

  @override
  Widget build(BuildContext context) {
    Widget row = Wrap(
      spacing: PaperSpacing.tw2,
      runSpacing: PaperSpacing.tw1,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        ExcludeSemantics(child: Text(label, style: _caption)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (var n = 1; n <= 5; n++) ...<Widget>[
              if (n > 1) const SizedBox(width: PaperSpacing.tw1),
              _Square(
                key: keyFor(n),
                n: n,
                selected: value == n,
                focusGap: focusGap,
                onPressed: onRate == null
                    ? null
                    : () {
                        if (value == n) {
                          onClear?.call();
                        } else {
                          onRate!(n);
                        }
                      },
              ),
            ],
          ],
        ),
        ExcludeSemantics(child: Text(valueText, style: _caption)),
      ],
    );
    row = Semantics(
      container: true,
      label: label,
      value: semanticValue ?? valueText,
      child: row,
    );
    if (tooltip != null && tooltip!.isNotEmpty) {
      row = Tooltip(message: tooltip, child: row);
    }
    return row;
  }
}

class _Square extends StatelessWidget {
  const _Square({
    super.key,
    required this.n,
    required this.selected,
    required this.focusGap,
    required this.onPressed,
  });

  final int n;
  final bool selected;
  final Color focusGap;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => PaperPressable(
    onPressed: onPressed,
    selected: selected,
    semanticLabel: '$n',
    excludeSemantics: true,
    builder: (context, states) {
      final active =
          states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.pressed);
      final (fill, digit) = selected
          ? (PaperWeb.accent, PaperWeb.indigo950)
          : active
          ? (PaperWeb.gray700, PaperWeb.gray100)
          : (PaperWeb.gray800, PaperWeb.gray400);
      return Opacity(
        opacity: states.contains(WidgetState.disabled) ? 0.5 : 1,
        child: PaperFocusRing(
          show: states.contains(WidgetState.focused),
          radius: PaperRadii.borderMd,
          gap: focusGap,
          child: PaperColorBox(
            color: fill,
            radius: PaperRadii.borderMd,
            constraints: const BoxConstraints.tightFor(width: 24, height: 24),
            alignment: Alignment.center,
            child: Text(
              '$n',
              style: TextStyle(
                fontFamily: PaperTypography.sans,
                fontFamilyFallback: PaperTypography.sansFallback,
                fontSize: 12,
                height: 16 / 12,
                leadingDistribution: TextLeadingDistribution.even,
                fontWeight: FontWeight.w500,
                color: digit,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      );
    },
  );
}
