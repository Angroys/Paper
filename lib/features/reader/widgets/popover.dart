import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../domain/domain.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/paper_tokens.dart';
import '../../../theme/theme_x.dart';
import 'highlight_layer.dart';

/// Gap between a popover and its anchor (clears the touch handle knob).
const double kPopoverGap = 16;

/// Below this much room above the anchor the popover flips below.
const double kPopoverFlipThreshold = 56;

/// Positions [child] above [anchor] (viewer-local), flipping below when there
/// is less than [kPopoverFlipThreshold] above, clamped [kPopoverGap] inside
/// the parent. Fills its parent (put it in a `Stack`).
///
/// Enters with opacity + 4dp translate toward the anchor (motion #9/#10/#11,
/// `fast` · `decelerate`); under reduced motion it fades only. The
/// popover is its own [RepaintBoundary] (motion.md §1.4 B7), so its fade
/// never dirties the page below. Layout never animates.
class AnchoredPopover extends StatefulWidget {
  const AnchoredPopover({
    super.key,
    required this.anchor,
    required this.child,
    this.maxWidth = 560,
  });

  final Rect anchor;
  final Widget child;
  final double maxWidth;

  @override
  State<AnchoredPopover> createState() => _AnchoredPopoverState();
}

class _AnchoredPopoverState extends State<AnchoredPopover>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(vsync: this);
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _enter,
    curve: PaperMotion.decelerate,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _enter.duration = PaperMotion.fade(context, PaperMotion.fast);
    _enter.forward();
  }

  @override
  void dispose() {
    _curve.dispose();
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final above = widget.anchor.top - kPopoverGap >= kPopoverFlipThreshold;
        final offset = Tween<Offset>(
          begin: Offset(0, reduce ? 0 : (above ? 4 : -4) / 48),
          end: Offset.zero,
        ).animate(_curve);
        return CustomSingleChildLayout(
          delegate: _PopoverLayout(anchor: widget.anchor, above: above),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: (size.width - 2 * kPopoverGap).clamp(
                0,
                widget.maxWidth,
              ),
            ),
            child: RepaintBoundary(
              child: FadeTransition(
                opacity: _curve,
                child: SlideTransition(position: offset, child: widget.child),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PopoverLayout extends SingleChildLayoutDelegate {
  _PopoverLayout({required this.anchor, required this.above});

  final Rect anchor;
  final bool above;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size child) {
    final x = (anchor.center.dx - child.width / 2).clamp(
      kPopoverGap,
      (size.width - child.width - kPopoverGap).clamp(kPopoverGap, double.infinity),
    );
    var y = above
        ? anchor.top - kPopoverGap - child.height
        : anchor.bottom + kPopoverGap;
    y = y.clamp(
      kPopoverGap,
      (size.height - child.height - kPopoverGap).clamp(kPopoverGap, double.infinity),
    );
    return Offset(x.toDouble(), y.toDouble());
  }

  @override
  bool shouldRelayout(_PopoverLayout old) =>
      old.anchor != anchor || old.above != above;
}

/// True when the last input was touch-like (48dp targets), else pointer.
bool popoverIsTouch(BuildContext context) {
  final p = Theme.of(context).platform;
  return p == TargetPlatform.android || p == TargetPlatform.iOS;
}

/// Popover container: `surfaceRaised`, `r.xl`, 1dp border, `shadow2` in
/// light only (components.md SelectionPopover).
class PopoverSurface extends StatelessWidget {
  const PopoverSurface({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.accentBar = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// 3dp `primary` bar on the left (CitationPopover).
  final bool accentBar;

  @override
  Widget build(BuildContext context) {
    final c = context.paper;
    final brightness = Theme.of(context).brightness;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: PaperRadii.borderXl,
        border: Border.all(color: c.border),
        boxShadow: PaperElevation.shadow2(brightness),
      ),
      child: ClipRRect(
        borderRadius: PaperRadii.borderXl,
        child: Material(
          type: MaterialType.transparency,
          child: accentBar
              ? IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(width: 3, color: c.primary),
                      Flexible(
                        child: Padding(padding: padding, child: child),
                      ),
                    ],
                  ),
                )
              : Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// A horizontal bar of popover actions (48 high touch / 40 pointer).
class PopoverBar extends StatelessWidget {
  const PopoverBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final touch = popoverIsTouch(context);
    return PopoverSurface(
      padding: const EdgeInsets.symmetric(horizontal: PaperSpacing.xs),
      child: SizedBox(
        height: touch ? 48 : 40,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }
}

class PopoverDivider extends StatelessWidget {
  const PopoverDivider({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: PaperSpacing.xs,
      vertical: PaperSpacing.sm,
    ),
    child: SizedBox(
      width: 1,
      child: ColoredBox(color: context.paper.divider),
    ),
  );
}

/// Icon + label action in a popover bar.
class PopoverAction extends StatelessWidget {
  const PopoverAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.emphasized = false,
    this.destructive = false,
    this.trailing,
    this.tooltip,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool emphasized;
  final bool destructive;
  final Widget? trailing;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.paper;
    final color = destructive
        ? c.error
        : (emphasized ? c.primary : c.textPrimary);
    final touch = popoverIsTouch(context);
    Widget button = InkWell(
      onTap: onPressed,
      borderRadius: PaperRadii.borderMd,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: touch ? 48 : 32),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: PaperSpacing.md),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: PaperIconSize.md, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
    if (tooltip != null) button = Tooltip(message: tooltip, child: button);
    return Semantics(button: true, label: label, child: button);
  }
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

/// The 6 named swatches in token order. [checked] shows a check glyph (the
/// `H` default on SelectionPopover, the current colour on HighlightPicker).
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
    final touch = popoverIsTouch(context);
    final disc = touch ? 22.0 : 18.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final color in HighlightColor.values)
          Semantics(
            button: true,
            selected: color == checked,
            label: color == checked
                ? '${l10n.a11yColorSwatch(highlightColorName(l10n, color))}, ${l10n.a11yColorSelected}'
                : l10n.a11yColorSwatch(highlightColorName(l10n, color)),
            child: Tooltip(
              message: highlightColorName(l10n, color),
              child: InkWell(
                key: ValueKey<String>('swatch-${color.name}'),
                onTap: enabled ? () => onPick(color) : null,
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: touch ? 36 : 30,
                  height: touch ? 48 : 40,
                  child: Center(
                    child: _Swatch(
                      color: paperHue(color),
                      size: disc,
                      checked: color == checked,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.size,
    required this.checked,
  });

  final PaperHighlightColor color;
  final double size;
  final bool checked;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.wash,
      shape: BoxShape.circle,
      border: Border.all(color: color.ring, width: 1.5),
    ),
    child: checked
        ? const Icon(Symbols.check_rounded, size: 14, color: Color(0xFF171717))
        : null,
  );
}
