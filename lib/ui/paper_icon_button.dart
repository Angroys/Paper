import 'package:flutter/material.dart';

import '../theme/paper_tokens.dart';
import 'paper_focus_ring.dart';

/// Web icon-button boxes (components.md §3).
enum PaperIconButtonSize {
  /// `h-6 w-6`: popover / card close (`×` 16).
  s24(24),

  /// `p-1` around a 20 glyph: reader back.
  s28(28),

  /// `h-8 w-8`: panel hide, toast dismiss, nav sync badge.
  s32(32),

  /// `h-9 w-9` bordered + shadow-sm: show-panel button.
  s36Bordered(36),

  /// Zoom `−`/`+` (`btn-secondary px-2 py-1`), bordered, 26 tall.
  zoom26(26);

  const PaperIconButtonSize(this.extent);
  final double extent;

  bool get bordered => this == s36Bordered || this == zoom26;
}

/// Glyph tone: neutral (gray-400 → gray-100), or `error` inside red cards.
enum PaperIconButtonTone { neutral, error }

/// A square icon-only button: radius 6, centred glyph, no ripple, web
/// sizes (no 48px padding). Always has a [tooltip], which is also its
/// semantics label.
///
/// [icon] is any widget (a `PaperIcon`, or a `Text('×')` glyph); it is
/// tinted through `IconTheme` / `DefaultTextStyle`.
class PaperIconButton extends StatelessWidget {
  const PaperIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = PaperIconButtonSize.s32,
    this.tone = PaperIconButtonTone.neutral,
    this.selected = false,
    this.focusGap,
    this.focusNode,
    this.semanticLabel,
  });

  final Widget icon;
  final String tooltip;

  /// Overrides the semantics label (defaults to [tooltip]).
  final String? semanticLabel;
  final VoidCallback? onPressed;
  final PaperIconButtonSize size;
  final PaperIconButtonTone tone;

  /// Tool-dock style selection: accent-soft fill + accent-ink glyph.
  final bool selected;

  /// Offset-band colour for bordered sizes (offset 2); unused otherwise.
  final Color? focusGap;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final bordered = size.bordered;
    return PaperPressable(
      onPressed: onPressed,
      focusNode: focusNode,
      tooltip: tooltip,
      semanticLabel: semanticLabel ?? tooltip,
      excludeSemantics: true,
      selected: selected ? true : null,
      builder: (context, states) {
        final active =
            states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.pressed);
        Color fill;
        Color glyph;
        Color? border;
        if (selected) {
          fill = PaperWeb.accentSoft;
          glyph = PaperWeb.accentInk;
        } else if (tone == PaperIconButtonTone.error) {
          fill = active ? PaperWeb.red900 : const Color(0x00000000);
          glyph = active ? const Color(0xFFFEE2E2) : PaperWeb.red300;
        } else if (size == PaperIconButtonSize.s36Bordered) {
          fill = active ? PaperWeb.gray800 : PaperWeb.gray900;
          glyph = active ? PaperWeb.gray100 : PaperWeb.gray300;
          border = PaperWeb.gray700;
        } else if (size == PaperIconButtonSize.zoom26) {
          fill = active ? PaperWeb.gray800 : PaperWeb.gray900;
          glyph = PaperWeb.gray200;
          border = PaperWeb.gray700;
        } else {
          fill = active ? PaperWeb.gray800 : const Color(0x00000000);
          glyph = active ? PaperWeb.gray100 : PaperWeb.gray400;
        }
        final box = PaperColorBox(
          color: fill,
          borderColor: border,
          radius: PaperRadii.borderMd,
          boxShadow: size == PaperIconButtonSize.s36Bordered
              ? PaperElevation.shadowSm
              : null,
          constraints: BoxConstraints.tightFor(
            width: size.extent,
            height: size.extent,
          ),
          alignment: Alignment.center,
          child: IconTheme.merge(
            data: IconThemeData(color: glyph, size: 16),
            child: DefaultTextStyle.merge(
              style: TextStyle(
                fontFamily: PaperTypography.sans,
                fontSize: 16,
                height: 1,
                color: glyph,
              ),
              child: icon,
            ),
          ),
        );
        return Opacity(
          opacity: states.contains(WidgetState.disabled) ? 0.5 : 1,
          child: PaperFocusRing(
            show: states.contains(WidgetState.focused),
            radius: PaperRadii.borderMd,
            color: tone == PaperIconButtonTone.error
                ? PaperWeb.red500
                : PaperWeb.accent,
            offset: bordered ? 2 : 0,
            gap: bordered ? (focusGap ?? PaperWeb.gray950) : null,
            child: box,
          ),
        );
      },
    );
  }
}

/// The `×` close glyph used by 24/32 close buttons (text, Geist 16/16).
class PaperCloseGlyph extends StatelessWidget {
  const PaperCloseGlyph({super.key});

  @override
  Widget build(BuildContext context) =>
      const Text('×', textAlign: TextAlign.center);
}
