import 'package:flutter/material.dart';

import '../theme/paper_tokens.dart';
import 'paper_focus_ring.dart';

/// Web button families (components.md §2).
enum PaperButtonVariant {
  /// `.btn-primary`: accent fill, indigo-950 label.
  primary,

  /// `.btn-secondary`: gray-900 fill, 1px gray-700 border, gray-200 label.
  secondary,

  /// `.btn-ghost`: transparent, gray-400 label; hover gray-800/gray-100.
  ghost,

  /// Red outline (`DeletePaperButton`): gray-900, red-900 border, red-400.
  destructive,

  /// Card/popover footer action (`rounded px-2 py-1 text-xs`), radius 4.
  quiet,

  /// Selection-popover items, radius 4, 32 tall (§2.6).
  popoverPrimary,
  popoverHighlight,
  popoverNeutral,
  popoverDestructive,
}

/// Web button sizes. Heights without/with a 1px border (§2 table):
/// md 36/38, sm 32/34, xs 24/26, xxs 24.
enum PaperButtonSize {
  /// `px-4 py-2 text-sm`.
  md(16, 20, 14, 36),

  /// `px-3 py-1.5 text-sm`.
  sm(12, 20, 14, 32),

  /// `px-2.5 py-1 text-xs`.
  xs(10, 16, 12, 24),

  /// `px-2 py-1 text-xs` (panel tabs, "Mark read", quiet actions).
  xxs(8, 16, 12, 24);

  const PaperButtonSize(
    this.paddingX,
    this.lineHeight,
    this.fontSize,
    this.height,
  );

  final double paddingX;
  final double lineHeight;
  final double fontSize;

  /// Height without border.
  final double height;
}

/// Resolved colours for one button state.
@immutable
class PaperButtonColors {
  const PaperButtonColors(this.fill, this.label, [this.border]);
  final Color fill;
  final Color label;
  final Color? border;
}

const Color _transparent = Color(0x00000000);

/// The web colour table for [variant] in [states] (components.md §2).
/// Ghost only: [toggled] = `aria-pressed` (label accent), [open] = open
/// disclosure (label gray-100).
PaperButtonColors paperButtonColors(
  PaperButtonVariant variant,
  Set<WidgetState> states, {
  bool toggled = false,
  bool open = false,
}) {
  final hover = states.contains(WidgetState.hovered);
  final pressed = states.contains(WidgetState.pressed);
  final active = hover || pressed;
  switch (variant) {
    case PaperButtonVariant.primary:
    case PaperButtonVariant.popoverPrimary:
      return PaperButtonColors(
        active ? PaperWeb.accentHover : PaperWeb.accent,
        PaperWeb.indigo950,
      );
    case PaperButtonVariant.secondary:
      return PaperButtonColors(
        active ? PaperWeb.gray800 : PaperWeb.gray900,
        PaperWeb.gray200,
        PaperWeb.gray700,
      );
    case PaperButtonVariant.ghost:
      if (toggled && !active) {
        return const PaperButtonColors(_transparent, PaperWeb.accent);
      }
      if (open && !active) {
        return const PaperButtonColors(_transparent, PaperWeb.gray100);
      }
      return PaperButtonColors(
        pressed
            ? PaperWeb.gray700
            : hover
            ? PaperWeb.gray800
            : _transparent,
        active ? PaperWeb.gray100 : PaperWeb.gray400,
      );
    case PaperButtonVariant.destructive:
      return PaperButtonColors(
        active ? PaperWeb.red950 : PaperWeb.gray900,
        PaperWeb.red400,
        PaperWeb.red900,
      );
    case PaperButtonVariant.quiet:
      return PaperButtonColors(
        active ? PaperWeb.gray800 : _transparent,
        PaperWeb.gray300,
      );
    case PaperButtonVariant.popoverHighlight:
      return PaperButtonColors(
        active ? PaperWeb.yellow900Hover : _transparent,
        PaperWeb.gray200,
      );
    case PaperButtonVariant.popoverNeutral:
      return PaperButtonColors(
        active ? PaperWeb.gray800 : _transparent,
        PaperWeb.gray200,
      );
    case PaperButtonVariant.popoverDestructive:
      return PaperButtonColors(
        active ? PaperWeb.red950 : _transparent,
        PaperWeb.red400,
      );
  }
}

/// A web-parity text button (components.md §2). Sizes are the web's: no
/// 48px touch padding, no ripple, colour-only 150ms state changes, keyboard
/// focus ring only, whole button at 50% when disabled.
///
/// Loading: swap [label] ("Saving…") and pass `onPressed: null`, as the web
/// does. Use [PaperButton.primary] etc. for the common variants.
class PaperButton extends StatelessWidget {
  const PaperButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = PaperButtonVariant.secondary,
    this.size = PaperButtonSize.md,
    this.leading,
    this.trailing,
    this.toggled,
    this.open = false,
    this.expand = false,
    this.focusGap,
    this.focusNode,
    this.autofocus = false,
    this.tooltip,
    this.semanticLabel,
  });

  const PaperButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = PaperButtonSize.md,
    this.leading,
    this.trailing,
    this.expand = false,
    this.focusGap,
    this.focusNode,
    this.autofocus = false,
    this.tooltip,
    this.semanticLabel,
  }) : variant = PaperButtonVariant.primary,
       toggled = null,
       open = false;

  const PaperButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = PaperButtonSize.md,
    this.leading,
    this.trailing,
    this.expand = false,
    this.focusGap,
    this.focusNode,
    this.autofocus = false,
    this.tooltip,
    this.semanticLabel,
  }) : variant = PaperButtonVariant.secondary,
       toggled = null,
       open = false;

  const PaperButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = PaperButtonSize.md,
    this.leading,
    this.trailing,
    this.toggled,
    this.open = false,
    this.expand = false,
    this.focusGap,
    this.focusNode,
    this.autofocus = false,
    this.tooltip,
    this.semanticLabel,
  }) : variant = PaperButtonVariant.ghost;

  const PaperButton.destructive({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = PaperButtonSize.xs,
    this.leading,
    this.trailing,
    this.expand = false,
    this.focusGap,
    this.focusNode,
    this.autofocus = false,
    this.tooltip,
    this.semanticLabel,
  }) : variant = PaperButtonVariant.destructive,
       toggled = null,
       open = false;

  const PaperButton.quiet({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
    this.trailing,
    this.focusNode,
    this.autofocus = false,
    this.tooltip,
    this.semanticLabel,
  }) : variant = PaperButtonVariant.quiet,
       size = PaperButtonSize.xxs,
       toggled = null,
       open = false,
       expand = false,
       focusGap = null;

  final String label;
  final VoidCallback? onPressed;
  final PaperButtonVariant variant;
  final PaperButtonSize size;

  /// Optional glyph before / after the label (gap 8), e.g. a 16px
  /// `PaperIcon`. It is tinted with the label colour via `IconTheme`.
  final Widget? leading;
  final Widget? trailing;

  /// Ghost only: `aria-pressed` toggle; when true the label is accent
  /// ("Mark read" when read). Exposed as semantics `toggled`.
  final bool? toggled;

  /// Ghost only: open disclosure / menu trigger; label stays gray-100.
  final bool open;

  /// `w-full`.
  final bool expand;

  /// The surface under the button for the focus ring's offset band
  /// (default `#0A0A0A`; pass `#171717` inside cards, popovers, dialogs).
  final Color? focusGap;
  final FocusNode? focusNode;
  final bool autofocus;
  final String? tooltip;
  final String? semanticLabel;

  bool get _bordered =>
      variant == PaperButtonVariant.secondary ||
      variant == PaperButtonVariant.destructive;

  bool get _popover =>
      variant == PaperButtonVariant.popoverPrimary ||
      variant == PaperButtonVariant.popoverHighlight ||
      variant == PaperButtonVariant.popoverNeutral ||
      variant == PaperButtonVariant.popoverDestructive;

  /// Rendered height including the border.
  double get height {
    if (_popover) return PaperButtonSize.sm.height;
    return size.height + (_bordered ? 2 : 0);
  }

  @override
  Widget build(BuildContext context) {
    final s = _popover ? PaperButtonSize.sm : size;
    final radius = (_popover || variant == PaperButtonVariant.quiet)
        ? PaperRadii.borderSm
        : PaperRadii.borderMd;
    final ringOffset = switch (variant) {
      PaperButtonVariant.quiet => 0.0,
      _ when _popover => 1.0,
      _ => 2.0,
    };
    final ringGap = _popover
        ? PaperWeb.gray900
        : (focusGap ?? PaperWeb.gray950);
    final ringColor = variant == PaperButtonVariant.destructive
        ? PaperWeb.red500
        : PaperWeb.accent;
    final disabledOpacity = variant == PaperButtonVariant.quiet ? 0.6 : 0.5;

    return PaperPressable(
      onPressed: onPressed,
      focusNode: focusNode,
      autofocus: autofocus,
      tooltip: tooltip,
      semanticLabel: semanticLabel,
      toggled: toggled,
      builder: (context, states) {
        final colors = paperButtonColors(
          variant,
          states,
          toggled: toggled ?? false,
          open: open,
        );
        final textStyle = TextStyle(
          fontFamily: PaperTypography.sans,
          fontFamilyFallback: PaperTypography.sansFallback,
          fontSize: s.fontSize,
          height: s.lineHeight / s.fontSize,
          leadingDistribution: TextLeadingDistribution.even,
          fontWeight: FontWeight.w500,
          color: colors.label,
        );
        final text = Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          textAlign: TextAlign.center,
          style: textStyle,
        );
        final content = IconTheme.merge(
          data: IconThemeData(color: colors.label, size: 16),
          child: DefaultTextStyle.merge(
            style: textStyle,
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (leading != null) ...<Widget>[
                  leading!,
                  const SizedBox(width: PaperSpacing.tw2),
                ],
                Flexible(child: text),
                if (trailing != null) ...<Widget>[
                  const SizedBox(width: PaperSpacing.tw2),
                  trailing!,
                ],
              ],
            ),
          ),
        );
        Widget box = PaperColorBox(
          color: colors.fill,
          borderColor: _bordered ? colors.border : null,
          radius: radius,
          constraints: BoxConstraints.tightFor(height: height),
          padding: EdgeInsets.symmetric(horizontal: s.paddingX),
          // An alignment would make the box fill loose constraints (e.g.
          // inside an Align); without one it hugs its label like the web's
          // inline-flex buttons. The Row still centres the label.
          alignment: expand ? Alignment.center : null,
          child: content,
        );
        if (expand) box = SizedBox(width: double.infinity, child: box);
        return Opacity(
          opacity: states.contains(WidgetState.disabled) ? disabledOpacity : 1,
          child: PaperFocusRing(
            show: states.contains(WidgetState.focused),
            radius: radius,
            color: ringColor,
            offset: ringOffset,
            gap: ringOffset > 0 ? ringGap : null,
            child: box,
          ),
        );
      },
    );
  }
}
