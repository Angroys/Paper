import 'package:flutter/material.dart';

import '../theme/paper_tokens.dart';
import 'paper_focus_ring.dart';

/// Web link styles (components.md §18.1).
enum PaperLinkVariant {
  /// `accent` 500, hover `accentHover` + underline (offset 2).
  accent,

  /// `gray100` 500, no underline at rest, hover underline (sign-in toggle).
  strong,

  /// `gray400` 400, hover `gray100` + underline (sign-in secondary links,
  /// legal footer).
  muted,
}

/// A text link (components.md §18.1): no ripple, colour + underline on
/// hover, keyboard focus ring 2 accent (radius 6, no offset).
///
/// [fontSize] 14 (`sm`, default) or 12 (`xs`). [trailing] is appended as
/// plain text (e.g. the `↗` external glyph).
class PaperLink extends StatelessWidget {
  const PaperLink({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = PaperLinkVariant.accent,
    this.fontSize = 14,
    this.trailing,
    this.semanticLabel,
  });

  const PaperLink.strong({
    super.key,
    required this.label,
    required this.onPressed,
    this.fontSize = 14,
    this.trailing,
    this.semanticLabel,
  }) : variant = PaperLinkVariant.strong;

  const PaperLink.muted({
    super.key,
    required this.label,
    required this.onPressed,
    this.fontSize = 14,
    this.trailing,
    this.semanticLabel,
  }) : variant = PaperLinkVariant.muted;

  final String label;
  final VoidCallback? onPressed;
  final PaperLinkVariant variant;
  final double fontSize;
  final String? trailing;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => PaperPressable(
    onPressed: onPressed,
    semanticLabel: semanticLabel,
    builder: (context, states) {
      final hot =
          states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.pressed);
      final color = switch (variant) {
        PaperLinkVariant.accent => hot ? PaperWeb.accentHover : PaperWeb.accent,
        PaperLinkVariant.strong => PaperWeb.gray100,
        PaperLinkVariant.muted => hot ? PaperWeb.gray100 : PaperWeb.gray400,
      };
      final style = TextStyle(
        fontFamily: PaperTypography.sans,
        fontFamilyFallback: PaperTypography.sansFallback,
        fontSize: fontSize,
        height: (fontSize <= 12 ? 16 : 20) / fontSize,
        leadingDistribution: TextLeadingDistribution.even,
        fontWeight: variant == PaperLinkVariant.muted
            ? FontWeight.w400
            : FontWeight.w500,
        color: color,
        decoration: hot ? TextDecoration.underline : TextDecoration.none,
        decorationColor: color,
      );
      return Opacity(
        opacity: states.contains(WidgetState.disabled) ? 0.5 : 1,
        child: PaperFocusRing(
          show: states.contains(WidgetState.focused),
          radius: PaperRadii.borderMd,
          color: PaperWeb.accent,
          offset: 0,
          child: Text.rich(
            TextSpan(
              text: label,
              children: <InlineSpan>[
                if (trailing != null)
                  TextSpan(
                    text: ' $trailing',
                    style: const TextStyle(decoration: TextDecoration.none),
                  ),
              ],
            ),
            style: style,
          ),
        ),
      );
    },
  );
}
