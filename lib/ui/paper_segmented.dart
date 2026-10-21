import 'package:flutter/material.dart';

import '../theme/paper_tokens.dart';
import 'paper_focus_ring.dart';

/// `PaperSegmented` sizes (components.md §8.1).
enum PaperSegmentedSize {
  /// 28 total: container `p-px`, segments `px-2 py-1` 12/16 (icon-only
  /// 24×24). Fits the 52-tall reader header.
  sm,

  /// 38 total: container `p-0.5`, segments `px-3 py-1.5` 14/20.
  md,
}

/// One segment: a text [label] and/or a 16px [icon]. Icon-only segments
/// need a [tooltip] (also the semantics label).
@immutable
class PaperSegment<T> {
  const PaperSegment({
    required this.value,
    this.label,
    this.icon,
    this.tooltip,
    this.key,
    this.enabled = true,
  }) : assert(label != null || icon != null);

  final T value;
  final String? label;
  final Widget? icon;
  final String? tooltip;
  final Key? key;
  final bool enabled;
}

/// The app's segmented control in web parts (components.md §8.1): a
/// gray-900 / gray-800-bordered radius-6 tray; ghost segments; the
/// selected one accent-soft / accent-ink. Content-sized segments, no check
/// icon.
class PaperSegmented<T> extends StatelessWidget {
  const PaperSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.size = PaperSegmentedSize.md,
  });

  final List<PaperSegment<T>> segments;
  final T selected;
  final ValueChanged<T>? onChanged;
  final PaperSegmentedSize size;

  @override
  Widget build(BuildContext context) {
    final md = size == PaperSegmentedSize.md;
    final pad = md ? 2.0 : 1.0;
    return Container(
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: PaperWeb.gray900,
        border: Border.all(color: PaperWeb.gray800),
        borderRadius: PaperRadii.borderMd,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (var i = 0; i < segments.length; i++) ...<Widget>[
            if (i > 0) SizedBox(width: pad),
            _Segment<T>(
              key: segments[i].key,
              segment: segments[i],
              md: md,
              selected: segments[i].value == selected,
              onPressed: onChanged == null || !segments[i].enabled
                  ? null
                  : () => onChanged!(segments[i].value),
            ),
          ],
        ],
      ),
    );
  }
}

class _Segment<T> extends StatelessWidget {
  const _Segment({
    super.key,
    required this.segment,
    required this.md,
    required this.selected,
    required this.onPressed,
  });

  final PaperSegment<T> segment;
  final bool md;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final iconOnly = segment.label == null;
    final height = md ? 32.0 : 24.0;
    return PaperPressable(
      onPressed: onPressed,
      selected: selected,
      tooltip: segment.tooltip,
      semanticLabel: segment.tooltip ?? segment.label,
      excludeSemantics: true,
      builder: (context, states) {
        final c = _tabColors(states, selected);
        return Opacity(
          opacity: states.contains(WidgetState.disabled) ? 0.5 : 1,
          child: PaperFocusRing(
            show: states.contains(WidgetState.focused),
            radius: PaperRadii.borderSm,
            offset: 1,
            gap: PaperWeb.gray900,
            child: PaperColorBox(
              color: c.$1,
              radius: PaperRadii.borderSm,
              constraints: iconOnly
                  ? BoxConstraints.tightFor(width: height, height: height)
                  : BoxConstraints.tightFor(height: height),
              padding: iconOnly
                  ? null
                  : EdgeInsets.symmetric(
                      horizontal: md ? PaperSpacing.tw3 : PaperSpacing.tw2,
                    ),
              alignment: Alignment.center,
              child: IconTheme.merge(
                data: IconThemeData(color: c.$2, size: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (segment.icon != null) segment.icon!,
                    if (segment.icon != null && !iconOnly)
                      const SizedBox(width: PaperSpacing.tw1_5),
                    if (!iconOnly)
                      Text(
                        segment.label!,
                        maxLines: 1,
                        style: _labelStyle(md ? 14 : 12, c.$2),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

TextStyle _labelStyle(double size, Color color) => TextStyle(
  fontFamily: PaperTypography.sans,
  fontFamilyFallback: PaperTypography.sansFallback,
  fontSize: size,
  height: (size == 14 ? 20 : 16) / size,
  leadingDistribution: TextLeadingDistribution.even,
  fontWeight: FontWeight.w500,
  color: color,
);

/// (fill, label) for a ghost tab/segment.
(Color, Color) _tabColors(Set<WidgetState> states, bool selected) {
  if (selected) return (PaperWeb.accentSoft, PaperWeb.accentInk);
  if (states.contains(WidgetState.pressed)) {
    return (PaperWeb.gray700, PaperWeb.gray100);
  }
  if (states.contains(WidgetState.hovered)) {
    return (PaperWeb.gray800, PaperWeb.gray100);
  }
  return (const Color(0x00000000), PaperWeb.gray400);
}

/// One side-panel tab.
@immutable
class PaperTab {
  const PaperTab({required this.label, this.key, this.showDot = false});

  final String label;
  final Key? key;

  /// "New result" 6×6 accent dot, 6 after the label.
  final bool showDot;
}

/// Side-panel tabs (components.md §8.2): ghost `xxs` buttons (24 tall,
/// `px-2`, 12/16 500), gap 4; selected = accent-soft / accent-ink. No
/// underline indicator.
class PaperTabs extends StatelessWidget {
  const PaperTabs({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
    this.dotSemanticLabel,
  });

  final List<PaperTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Appended to a tab's semantics when its dot shows
  /// (`panelTabNewResult`).
  final String? dotSemanticLabel;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var i = 0; i < tabs.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: PaperSpacing.tw1),
          PaperPressable(
            key: tabs[i].key,
            onPressed: () => onSelected(i),
            selected: i == selectedIndex,
            semanticLabel: tabs[i].showDot && dotSemanticLabel != null
                ? '${tabs[i].label}, $dotSemanticLabel'
                : tabs[i].label,
            excludeSemantics: true,
            builder: (context, states) {
              final c = _tabColors(states, i == selectedIndex);
              return PaperFocusRing(
                show: states.contains(WidgetState.focused),
                radius: PaperRadii.borderMd,
                gap: PaperWeb.gray950,
                child: PaperColorBox(
                  color: c.$1,
                  radius: PaperRadii.borderMd,
                  constraints: const BoxConstraints.tightFor(height: 24),
                  padding: const EdgeInsets.symmetric(
                    horizontal: PaperSpacing.tw2,
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        tabs[i].label,
                        maxLines: 1,
                        style: _labelStyle(12, c.$2),
                      ),
                      if (tabs[i].showDot) ...<Widget>[
                        const SizedBox(width: PaperSpacing.tw1_5),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: PaperWeb.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ],
    ),
  );
}
