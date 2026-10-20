import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/build_flags.dart';
import '../../../core/core_providers.dart';
import '../../../domain/domain.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/theme_x.dart';
import '../reader_controller.dart';
import 'popover.dart';

/// `SelectionPopover`: colours · Explain · Note · Copy (reader spec).
class SelectionPopover extends ConsumerWidget {
  const SelectionPopover({
    super.key,
    required this.paperId,
    required this.selection,
  });

  final String paperId;
  final ReaderTextSelection selection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final ctrl = ref.read(readerControllerProvider(paperId).notifier);
    final color = ref.watch(
      readerControllerProvider(paperId).select((s) => s.highlightColor),
    );
    final hasText = ref.watch(
      readerControllerProvider(paperId).select((s) => s.hasTextLayer),
    );
    final online = ref.watch(isOnlineProvider).value ?? true;
    // Offline-only builds have no AI: no Explain action at all.
    final ai = !ref.watch(offlineOnlyProvider);
    return PopoverBar(
      children: <Widget>[
        HighlightSwatches(
          checked: color,
          enabled: hasText,
          onPick: (c) => unawaited(ctrl.highlightSelection(c)),
        ),
        const PopoverDivider(),
        if (ai)
          PopoverAction(
            icon: Symbols.auto_awesome_rounded,
            label: l10n.selectionExplain,
            emphasized: true,
            tooltip: online ? null : l10n.selectionExplainOffline,
            trailing: online
                ? null
                : Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(
                      Symbols.cloud_off_rounded,
                      size: 14,
                      color: context.paper.textMuted,
                    ),
                  ),
            onPressed: hasText
                ? () => unawaited(ctrl.explainSelection())
                : null,
          ),
        PopoverAction(
          icon: Symbols.sticky_note_2_rounded,
          label: l10n.selectionNote,
          onPressed: () => unawaited(ctrl.noteForSelection()),
        ),
        PopoverAction(
          icon: Symbols.content_copy_rounded,
          label: l10n.selectionCopy,
          onPressed: hasText
              ? () => unawaited(copySelection(context, ref, paperId))
              : null,
        ),
      ],
    );
  }
}

/// Copies the current selection and confirms with `selectionCopied`.
Future<void> copySelection(
  BuildContext context,
  WidgetRef ref,
  String paperId,
) async {
  final sel = ref.read(readerControllerProvider(paperId)).selection;
  if (sel == null) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final copied = AppLocalizations.of(context).selectionCopied;
  await Clipboard.setData(ClipboardData(text: sel.text));
  messenger?.showSnackBar(SnackBar(content: Text(copied)));
}

/// `HighlightPicker` on an existing highlight: colours (current checked) ·
/// Note · Explain · Delete.
class HighlightPicker extends ConsumerWidget {
  const HighlightPicker({
    super.key,
    required this.paperId,
    required this.highlight,
  });

  final String paperId;
  final Highlight highlight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final ctrl = ref.read(readerControllerProvider(paperId).notifier);
    final ai = !ref.watch(offlineOnlyProvider);
    return PopoverBar(
      children: <Widget>[
        HighlightSwatches(
          checked: highlight.color,
          onPick: (c) => unawaited(ctrl.changeHighlightColor(highlight.id, c)),
        ),
        const PopoverDivider(),
        PopoverAction(
          icon: Symbols.sticky_note_2_rounded,
          label: l10n.selectionNote,
          onPressed: () => ctrl.noteForHighlight(highlight),
        ),
        if (ai)
          PopoverAction(
            icon: Symbols.auto_awesome_rounded,
            label: l10n.selectionExplain,
            emphasized: true,
            onPressed: () => ctrl.explainHighlight(highlight),
          ),
        PopoverAction(
          icon: Symbols.delete_rounded,
          label: l10n.highlightDelete,
          destructive: true,
          onPressed: () => unawaited(ctrl.deleteHighlight(highlight)),
        ),
      ],
    );
  }
}
