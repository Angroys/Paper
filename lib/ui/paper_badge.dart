import 'package:flutter/material.dart';

import '../theme/paper_tokens.dart';
import 'paper_focus_ring.dart';

/// Chip/badge tones (components.md §9).
enum PaperBadgeTone {
  /// `ReadBadge`, `TagChip.type`: accent-soft / accent-ink.
  accent(PaperWeb.accentSoft, PaperWeb.accentInk),

  /// `TagChip.topic`, `NeutralChip`, `CountChip`: gray-800 / gray-300.
  neutral(PaperWeb.gray800, PaperWeb.gray300),

  /// `NeutralChip` "+N more": gray-800 / gray-400.
  muted(PaperWeb.gray800, PaperWeb.gray400),

  /// `StatusChip.error`: red-950 / red-300.
  error(PaperWeb.red950, PaperWeb.red300);

  const PaperBadgeTone(this.fill, this.label);
  final Color fill;
  final Color label;
}

/// A non-interactive rounded-full chip, 20 tall: `px-2 py-0.5`, 11/16 500
/// ([count] = `px-1.5`, 10.4px tabular).
class PaperBadge extends StatelessWidget {
  const PaperBadge({
    super.key,
    required this.label,
    this.tone = PaperBadgeTone.accent,
    this.leading,
    this.semanticLabel,
  }) : count = false;

  /// `CountChip` (panel section counts).
  const PaperBadge.count({super.key, required this.label, this.semanticLabel})
    : tone = PaperBadgeTone.neutral,
      leading = null,
      count = true;

  final String label;
  final PaperBadgeTone tone;

  /// Optional 12px glyph before the label (gap 4).
  final Widget? leading;
  final bool count;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: PaperTypography.sans,
      fontFamilyFallback: PaperTypography.sansFallback,
      fontSize: count ? PaperTypography.text0_65rem : PaperTypography.text11,
      height: 16 / (count ? PaperTypography.text0_65rem : 11),
      leadingDistribution: TextLeadingDistribution.even,
      fontWeight: FontWeight.w500,
      color: tone.label,
      fontFeatures: count
          ? const <FontFeature>[FontFeature.tabularFigures()]
          : null,
    );
    return Semantics(
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: Container(
        height: 20,
        padding: EdgeInsets.symmetric(
          horizontal: count ? PaperSpacing.tw1_5 : PaperSpacing.tw2,
        ),
        decoration: BoxDecoration(
          color: tone.fill,
          borderRadius: PaperRadii.borderFull,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (leading != null) ...<Widget>[
              IconTheme.merge(
                data: IconThemeData(color: tone.label, size: 12),
                child: leading!,
              ),
              const SizedBox(width: PaperSpacing.tw1),
            ],
            Text(label, style: style, maxLines: 1),
          ],
        ),
      ),
    );
  }
}

/// `FilterPill` (glossary tag filter, a toggle): 24 tall, `px-2.5 py-1`,
/// 12/16 500; rest gray-800/gray-400, hover gray-700; active accent fill +
/// indigo-950 label.
class PaperFilterPill extends StatelessWidget {
  const PaperFilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => PaperPressable(
    onPressed: onChanged == null ? null : () => onChanged!(!selected),
    toggled: selected,
    builder: (context, states) {
      final hover =
          states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.pressed);
      final fill = selected
          ? PaperWeb.accent
          : hover
          ? PaperWeb.gray700
          : PaperWeb.gray800;
      return Opacity(
        opacity: states.contains(WidgetState.disabled) ? 0.5 : 1,
        child: PaperFocusRing(
          show: states.contains(WidgetState.focused),
          radius: PaperRadii.borderFull,
          gap: PaperWeb.gray950,
          child: PaperColorBox(
            color: fill,
            radius: PaperRadii.borderFull,
            constraints: const BoxConstraints.tightFor(height: 24),
            padding: const EdgeInsets.symmetric(horizontal: PaperSpacing.tw2_5),
            alignment: Alignment.center,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontFamily: PaperTypography.sans,
                fontSize: 12,
                height: 16 / 12,
                fontWeight: FontWeight.w500,
                color: selected ? PaperWeb.indigo950 : PaperWeb.gray400,
              ),
            ),
          ),
        ),
      );
    },
  );
}
