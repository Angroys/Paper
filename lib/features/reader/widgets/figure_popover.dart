import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../l10n/app_localizations.dart';
import 'popover.dart';

/// Mini popover under a dragged `FigureSelectionBox`: Save highlight · Add
/// note · Cancel (components.md FigureSelectionBox). [anchor] is the box in
/// viewer-local coordinates.
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
  Widget build(BuildContext context) {
    return AnchoredPopover(
      anchor: anchor,
      child: PopoverBar(
        children: <Widget>[
          PopoverAction(
            icon: Symbols.check_rounded,
            label: l10n.figureSaveHighlight,
            onPressed: onSave,
            emphasized: true,
          ),
          PopoverAction(
            icon: Symbols.sticky_note_2_rounded,
            label: l10n.figureAddNote,
            onPressed: onAddNote,
          ),
          PopoverAction(
            icon: Symbols.close_rounded,
            label: l10n.figureCancel,
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

/// Note for a figure highlight; null when cancelled.
Future<String?> showFigureNoteDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.figureAddNote),
      content: SizedBox(
        width: 320,
        child: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 8,
          decoration: InputDecoration(hintText: l10n.noteInlinePlaceholder),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: Text(l10n.commonSave),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}
