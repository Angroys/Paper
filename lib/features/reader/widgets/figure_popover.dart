import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/paper_tokens.dart';
import '../../../ui/ui.dart';

/// Figure action pills (components.md §10.5, reader.md §7) over a dragged
/// `FigureSelectionBox`: a `flex-col items-end gap-1` column of white pills
/// at the figure's top-right inside (`right-1 top-1`): Save highlight · Add
/// note · Cancel, text only. [anchor] is the box in viewer-local
/// coordinates; this widget fills its parent `Stack`.
class FigurePopover extends StatelessWidget {
  const FigurePopover({
    super.key,
    required this.anchor,
    required this.l10n,
    required this.onSave,
    required this.onAddNote,
    required this.onCancel,
  });

  final Rect anchor;
  final AppLocalizations l10n;
  final VoidCallback onSave;
  final VoidCallback onAddNote;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => Stack(
      children: <Widget>[
        Positioned(
          top: (anchor.top + PaperSpacing.tw1).clamp(
            0,
            (box.maxHeight - 80).clamp(0, double.infinity),
          ),
          right: (box.maxWidth - anchor.right + PaperSpacing.tw1).clamp(
            0,
            box.maxWidth,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              FigurePill(label: l10n.figureSaveHighlight, onPressed: onSave),
              const SizedBox(height: PaperSpacing.tw1),
              FigurePill(label: l10n.figureAddNote, onPressed: onAddNote),
              const SizedBox(height: PaperSpacing.tw1),
              FigurePill(label: l10n.figureCancel, onPressed: onCancel),
            ],
          ),
        ),
      ],
    ),
  );
}

/// One figure pill: radius full, white, `px-2.5 py-1 xs 500 gray-900`,
/// shadow-sm, `ring-1` #0A0A0A @ .15, 24 tall; hover gray-100; focus ring 2
/// `#4F46E5`; disabled @ .6.
class FigurePill extends StatelessWidget {
  const FigurePill({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => PaperPressable(
    onPressed: onPressed,
    semanticLabel: label,
    excludeSemantics: true,
    builder: (context, states) {
      final active =
          states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.pressed);
      final disabled = states.contains(WidgetState.disabled);
      return PaperFocusRing(
        show: states.contains(WidgetState.focused),
        radius: PaperRadii.borderFull,
        color: PaperWeb.markFocusRing,
        offset: 0,
        child: PaperColorBox(
          color: active ? PaperWeb.gray100 : PaperWeb.white,
          borderColor: const Color(0x260A0A0A),
          radius: PaperRadii.borderFull,
          boxShadow: PaperElevation.shadowSm,
          constraints: const BoxConstraints.tightFor(height: 24),
          padding: const EdgeInsets.symmetric(horizontal: PaperSpacing.tw2_5),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: PaperTypography.sans,
              fontFamilyFallback: PaperTypography.sansFallback,
              fontSize: 12,
              height: 16 / 12,
              fontWeight: FontWeight.w500,
              color: PaperWeb.gray900.withValues(alpha: disabled ? 0.6 : 1),
            ),
          ),
        ),
      );
    },
  );
}

/// Note for a figure highlight (a `PaperDialog`); null when cancelled.
Future<String?> showFigureNoteDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  final controller = TextEditingController();
  return showPaperDialog<String>(
    context: context,
    builder: (context) => PaperDialog(
      title: l10n.figureAddNote,
      content: PaperTextField(
        controller: controller,
        autofocus: true,
        minLines: 3,
        maxLines: 8,
        hintText: l10n.noteInlinePlaceholder,
      ),
      actions: <Widget>[
        PaperButton.secondary(
          label: l10n.commonCancel,
          focusGap: PaperWeb.gray900,
          onPressed: () => Navigator.of(context).pop(),
        ),
        PaperButton.primary(
          label: l10n.commonSave,
          focusGap: PaperWeb.gray900,
          onPressed: () => Navigator.of(context).pop(controller.text),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}
