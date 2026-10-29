import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/build_flags.dart';
import '../../../core/core_providers.dart';
import '../../../domain/domain.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/paper_tokens.dart';
import '../../../ui/ui.dart';
import '../reader_controller.dart';
import 'popover.dart';

/// How long "Copied." replaces the Copy label (reader.md §4).
const Duration kCopiedLabelDuration = Duration(milliseconds: 1500);

/// `SelectionPopover` (components.md §10.1): **Explain** (primary) · 6
/// swatches · divider · **Note** · **Copy**. Explain stays enabled offline
/// with a trailing `cloud-off` 14 and a tooltip.
class SelectionPopover extends ConsumerStatefulWidget {
  const SelectionPopover({
    super.key,
    required this.paperId,
    required this.selection,
  });

  final String paperId;
  final ReaderTextSelection selection;

  @override
  ConsumerState<SelectionPopover> createState() => _SelectionPopoverState();
}

class _SelectionPopoverState extends ConsumerState<SelectionPopover> {
  Timer? _copied;

  @override
  void dispose() {
    _copied?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.selection.text));
    if (!mounted) return;
    _copied?.cancel();
    setState(() {
      _copied = Timer(kCopiedLabelDuration, () {
        if (mounted) setState(() => _copied = null);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final paperId = widget.paperId;
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
    final copied = _copied?.isActive ?? false;
    return PopoverBar(
      children: <Widget>[
        if (ai)
          PopoverAction(
            label: l10n.selectionExplain,
            emphasized: true,
            tooltip: online ? null : l10n.selectionExplainOffline,
            trailing: online
                ? null
                : const PaperIcon(
                    PaperIcons.cloudOff,
                    size: 14,
                    color: PaperWeb.indigo950,
                  ),
            onPressed: hasText
                ? () => unawaited(ctrl.explainSelection())
                : null,
          ),
        HighlightSwatches(
          checked: color,
          enabled: hasText,
          onPick: (c) => unawaited(ctrl.highlightSelection(c)),
        ),
        const PopoverDivider(),
        PopoverAction(
          label: l10n.selectionNote,
          onPressed: () => unawaited(ctrl.noteForSelection()),
        ),
        PopoverAction(
          key: const ValueKey<String>('selection-copy'),
          label: copied ? l10n.selectionCopied : l10n.selectionCopy,
          onPressed: hasText ? () => unawaited(_copy()) : null,
        ),
      ],
    );
  }
}

/// Copies the current selection (the `Mod+C` shortcut) and confirms with a
/// plain `selectionCopied` toast (the popover's Copy button swaps its label
/// instead).
Future<void> copySelection(
  BuildContext context,
  WidgetRef ref,
  String paperId,
) async {
  final sel = ref.read(readerControllerProvider(paperId)).selection;
  if (sel == null) return;
  final l10n = AppLocalizations.of(context);
  await Clipboard.setData(ClipboardData(text: sel.text));
  if (!context.mounted) return;
  showPaperToast(
    context,
    message: l10n.selectionCopied,
    dismissTooltip: l10n.commonDismiss,
  );
}

/// `HighlightPicker` on an existing highlight: 6 swatches (current checked)
/// · divider · Note · Explain (primary) · Delete (destructive text).
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
          label: l10n.selectionNote,
          onPressed: () => ctrl.noteForHighlight(highlight),
        ),
        if (ai)
          PopoverAction(
            label: l10n.selectionExplain,
            emphasized: true,
            onPressed: () => ctrl.explainHighlight(highlight),
          ),
        PopoverAction(
          label: l10n.commonDelete,
          tooltip: l10n.highlightDelete,
          destructive: true,
          onPressed: () => unawaited(ctrl.deleteHighlight(highlight)),
        ),
      ],
    );
  }
}
