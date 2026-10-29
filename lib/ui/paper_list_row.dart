import 'package:flutter/material.dart';

import '../theme/paper_tokens.dart';
import 'paper_focus_ring.dart';
import 'web_breakpoint.dart';

/// `PaperListRow` (components.md §7.4, settings.md §2): a `py-3` row inside
/// a `p-5` card with a 1px gray-800 bottom border (none when [last]),
/// hover `#1F1F1F`, label `sm 500` + optional `xs gray-400` description 4
/// below, and a [trailing] control 16 to the right.
///
/// [onTap] makes the whole row one button (e.g. "Copy all notes").
/// [stackBelowSm]: below 640 a wide control (segmented, buttons) moves under
/// the label, 12 below. [alignTop] top-aligns the control with a 2px nudge
/// (checkbox rows).
class PaperListRow extends StatelessWidget {
  const PaperListRow({
    super.key,
    required this.title,
    this.description,
    this.descriptionWidget,
    this.trailing,
    this.onTap,
    this.last = false,
    this.stackBelowSm = false,
    this.alignTop = false,
    this.titleColor = PaperWeb.gray300,
    this.titleMaxLines,
    this.semanticLabel,
  });

  final String title;
  final String? description;

  /// Replaces [description] (e.g. a coloured status line or a skeleton).
  final Widget? descriptionWidget;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool last;
  final bool stackBelowSm;
  final bool alignTop;
  final Color titleColor;
  final int? titleMaxLines;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final stack = stackBelowSm && !WebBreakpoint.of(context).isSmUp;
    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          title,
          maxLines: titleMaxLines,
          overflow: titleMaxLines == null ? null : TextOverflow.ellipsis,
          style: t.labelLarge?.copyWith(color: titleColor),
        ),
        if (descriptionWidget != null) ...<Widget>[
          const SizedBox(height: PaperSpacing.tw1),
          descriptionWidget!,
        ] else if (description != null) ...<Widget>[
          const SizedBox(height: PaperSpacing.tw1),
          Text(
            description!,
            style: t.bodySmall?.copyWith(color: PaperWeb.gray400),
          ),
        ],
      ],
    );
    final Widget content;
    if (trailing == null) {
      content = label;
    } else if (stack) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          label,
          const SizedBox(height: PaperSpacing.tw3),
          trailing!,
        ],
      );
    } else {
      content = Row(
        crossAxisAlignment: alignTop
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(child: label),
          const SizedBox(width: PaperSpacing.tw4),
          Padding(
            padding: EdgeInsets.only(top: alignTop ? 2 : 0),
            child: trailing,
          ),
        ],
      );
    }
    BoxDecoration deco(Color fill) => BoxDecoration(
      color: fill,
      border: last
          ? null
          : const Border(bottom: BorderSide(color: PaperWeb.gray800)),
    );
    const padding = EdgeInsets.symmetric(vertical: PaperSpacing.tw3);
    if (onTap == null) {
      return _HoverRow(
        builder: (hover) => AnimatedContainer(
          duration: PaperMotion.of(context, PaperMotion.fast),
          decoration: deco(hover ? PaperWeb.gray800Half : Colors.transparent),
          padding: padding,
          child: content,
        ),
      );
    }
    return PaperPressable(
      onPressed: onTap,
      semanticLabel: semanticLabel,
      builder: (context, states) {
        final hot =
            states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.pressed);
        return PaperFocusRing(
          show: states.contains(WidgetState.focused),
          radius: BorderRadius.zero,
          color: PaperWeb.accent,
          inset: true,
          child: AnimatedContainer(
            duration: PaperMotion.of(context, PaperMotion.fast),
            decoration: deco(hot ? PaperWeb.gray800Half : Colors.transparent),
            padding: padding,
            child: content,
          ),
        );
      },
    );
  }
}

class _HoverRow extends StatefulWidget {
  const _HoverRow({required this.builder});

  final Widget Function(bool hover) builder;

  @override
  State<_HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<_HoverRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hover = true),
    onExit: (_) => setState(() => _hover = false),
    child: widget.builder(_hover),
  );
}
