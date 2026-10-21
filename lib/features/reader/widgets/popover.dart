import 'package:flutter/material.dart';

import '../../../domain/domain.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/paper_tokens.dart';
import '../../../ui/ui.dart';
import 'highlight_layer.dart';

/// Gap between a selection popover's bottom edge and the selection
/// (reader.md §4: `top: anchor.top − 8`, `-translate-y-full`).
const double kPopoverGap = 8;

/// Inset of the clamp rect inside the pane (+ view padding).
const double kPopoverEdge = 8;

/// The zoom pill band at the top of the pane (24 + 36 + 8): a selection
/// popover that would cross it flips below the selection.
const double kZoomPillBand = 24 + 36 + 8;

/// Positions [child] around [anchor] (pane-local) inside the pane rect
/// deflated by the view padding + 8 (reader.md §4–§6):
/// - [preferBelow] false (selection / highlight popovers): bottom edge
///   [gap] above the anchor; flips [gap] below it when it would cross the
///   clamp top or the zoom-pill band ([topReserve]).
/// - [preferBelow] true (citation 6, floating explanation 8): top [gap]
///   below the anchor; flips above when it doesn't fit below but fits
///   above; otherwise the roomier side.
/// Horizontally centred on the anchor and clamped. Fills its parent (put it
/// in a `Stack`).
///
/// The web mounts popovers instantly: no fade, no translate (the
/// transitions stay in the tree at their end values). The popover is its
/// own [RepaintBoundary] (motion.md §1.4 B7).
class AnchoredPopover extends StatefulWidget {
  const AnchoredPopover({
    super.key,
    required this.anchor,
    required this.child,
    this.maxWidth = 560,
    this.gap = kPopoverGap,
    this.preferBelow = false,
    this.topReserve = kZoomPillBand,
  });

  final Rect anchor;
  final Widget child;
  final double maxWidth;
  final double gap;
  final bool preferBelow;
  final double topReserve;

  @override
  State<AnchoredPopover> createState() => _AnchoredPopoverState();
}

class _AnchoredPopoverState extends State<AnchoredPopover>
    with SingleTickerProviderStateMixin {
  // Always at its end value: popovers appear in one frame (reader.md §4).
  late final AnimationController _enter = AnimationController(
    vsync: this,
    value: 1,
  );

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.viewPaddingOf(context);
    final clampInsets = EdgeInsets.fromLTRB(
      kPopoverEdge + pad.left,
      kPopoverEdge,
      kPopoverEdge + pad.right,
      kPopoverEdge + pad.bottom,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return CustomSingleChildLayout(
          delegate: _PopoverLayout(
            anchor: widget.anchor,
            gap: widget.gap,
            preferBelow: widget.preferBelow,
            topReserve: widget.topReserve,
            insets: clampInsets,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: (size.width - clampInsets.horizontal).clamp(
                0,
                widget.maxWidth,
              ),
              maxHeight: (size.height - clampInsets.vertical).clamp(
                0,
                double.infinity,
              ),
            ),
            child: RepaintBoundary(
              child: FadeTransition(
                opacity: _enter,
                child: SlideTransition(
                  position: _enter.drive(
                    Tween<Offset>(begin: Offset.zero, end: Offset.zero),
                  ),
                  child: widget.child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PopoverLayout extends SingleChildLayoutDelegate {
  _PopoverLayout({
    required this.anchor,
    required this.gap,
    required this.preferBelow,
    required this.topReserve,
    required this.insets,
  });

  final Rect anchor;
  final double gap;
  final bool preferBelow;
  final double topReserve;
  final EdgeInsets insets;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size child) {
    final left = insets.left;
    final right = size.width - insets.right;
    final top = insets.top;
    final bottom = size.height - insets.bottom;
    final x = (anchor.center.dx - child.width / 2).clamp(
      left,
      (right - child.width).clamp(left, double.infinity),
    );
    final above = anchor.top - gap - child.height;
    final below = anchor.bottom + gap;
    double y;
    if (preferBelow) {
      final fitsBelow = below + child.height <= bottom;
      final fitsAbove = above >= top;
      if (fitsBelow) {
        y = below;
      } else if (fitsAbove) {
        y = above;
      } else {
        y = (anchor.top - top) > (bottom - anchor.bottom) ? above : below;
      }
    } else {
      final limit = top > topReserve ? top : topReserve;
      y = above < limit ? below : above;
    }
    y = y.clamp(top, (bottom - child.height).clamp(top, double.infinity));
    return Offset(x.toDouble(), y);
  }

  @override
  bool shouldRelayout(_PopoverLayout old) =>
      old.anchor != anchor ||
      old.gap != gap ||
      old.preferBelow != preferBelow ||
      old.topReserve != topReserve ||
      old.insets != insets;
}

/// True when the last input was touch-like, else pointer.
bool popoverIsTouch(BuildContext context) {
  final p = Theme.of(context).platform;
  return p == TargetPlatform.android || p == TargetPlatform.iOS;
}

/// Selection-popover box (components.md §10.1): gray-900, **no border**,
/// radius 6, shadow-lg.
class PopoverSurface extends StatelessWidget {
  const PopoverSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(PaperSpacing.tw1),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: const BoxDecoration(
      color: PaperWeb.gray900,
      borderRadius: PaperRadii.borderMd,
      boxShadow: PaperElevation.shadowLg,
    ),
    child: child,
  );
}

/// `SelectionPopover` row: `p-1 gap-1`, 40 tall (4 + 32 + 4); scrolls
/// horizontally when wider than the clamp rect.
class PopoverBar extends StatelessWidget {
  const PopoverBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => PopoverSurface(
    child: SizedBox(
      height: 32,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (var i = 0; i < children.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: PaperSpacing.tw1),
              children[i],
            ],
          ],
        ),
      ),
    ),
  );
}

/// 1×20 gray-700 divider, centred vertically.
class PopoverDivider extends StatelessWidget {
  const PopoverDivider({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 1,
    height: 20,
    child: ColoredBox(color: PaperWeb.gray700),
  );
}

/// A text action in a popover bar: `PaperButton.popover` primary (Explain),
/// neutral (Note, Copy) or destructive (Delete); 32 tall, radius 4. No
/// icons (the web never shows icons in text actions).
class PopoverAction extends StatelessWidget {
  const PopoverAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.emphasized = false,
    this.destructive = false,
    this.trailing,
    this.tooltip,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool emphasized;
  final bool destructive;
  final Widget? trailing;
  final String? tooltip;

  @override
  Widget build(BuildContext context) => PaperButton(
    label: label,
    onPressed: onPressed,
    tooltip: tooltip,
    trailing: trailing,
    variant: destructive
        ? PaperButtonVariant.popoverDestructive
        : (emphasized
              ? PaperButtonVariant.popoverPrimary
              : PaperButtonVariant.popoverNeutral),
  );
}

/// Localised colour name.
String highlightColorName(AppLocalizations l10n, HighlightColor c) =>
    switch (c) {
      HighlightColor.yellow => l10n.highlightColorYellow,
      HighlightColor.green => l10n.highlightColorGreen,
      HighlightColor.blue => l10n.highlightColorBlue,
      HighlightColor.pink => l10n.highlightColorPink,
      HighlightColor.purple => l10n.highlightColorPurple,
      HighlightColor.orange => l10n.highlightColorOrange,
    };

/// The 6 named swatches in token order (components.md §10.1): 32×32
/// `PaperButton.popover.highlight` boxes, each a 14px disc (`hue.wash` +
/// 1.5 `hue.ring`); [checked] shows a 10px `#171717` check.
class HighlightSwatches extends StatelessWidget {
  const HighlightSwatches({
    super.key,
    required this.onPick,
    this.checked,
    this.enabled = true,
  });

  final ValueChanged<HighlightColor> onPick;
  final HighlightColor? checked;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final color in HighlightColor.values) ...<Widget>[
          if (color.index > 0) const SizedBox(width: PaperSpacing.tw1),
          PaperPressable(
            key: ValueKey<String>('swatch-${color.name}'),
            onPressed: enabled ? () => onPick(color) : null,
            selected: color == checked,
            tooltip: highlightColorName(l10n, color),
            semanticLabel: color == checked
                ? '${l10n.a11yColorSwatch(highlightColorName(l10n, color))}, ${l10n.a11yColorSelected}'
                : l10n.a11yColorSwatch(highlightColorName(l10n, color)),
            excludeSemantics: true,
            builder: (context, states) {
              final colors = paperButtonColors(
                PaperButtonVariant.popoverHighlight,
                states,
              );
              return PaperFocusRing(
                show: states.contains(WidgetState.focused),
                radius: PaperRadii.borderSm,
                offset: 1,
                gap: PaperWeb.gray900,
                child: PaperColorBox(
                  color: colors.fill,
                  radius: PaperRadii.borderSm,
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                  alignment: Alignment.center,
                  child: _Swatch(
                    color: paperHue(color),
                    checked: color == checked,
                    dimmed: states.contains(WidgetState.disabled),
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.checked,
    required this.dimmed,
  });

  final PaperHighlightColor color;
  final bool checked;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    // Disabled @ 0.5 by colour, not an Opacity layer (reader P14).
    final a = dimmed ? 0.5 : 1.0;
    return Container(
      width: 14,
      height: 14,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.wash.withValues(alpha: a),
        shape: BoxShape.circle,
        border: Border.all(color: color.ring.withValues(alpha: a), width: 1.5),
      ),
      child: checked
          ? const PaperIcon(
              PaperIcons.check,
              size: 10,
              color: Color(0xFF171717),
            )
          : null,
    );
  }
}
