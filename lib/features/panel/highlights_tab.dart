import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../domain/domain.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/paper_tokens.dart';
import '../../theme/theme_x.dart';
import '../reader/reader_controller.dart';
import '../reader/widgets/highlight_layer.dart';
import '../reader/widgets/popover.dart' show highlightColorName;
import 'reader_side_panel.dart';

/// Sorts highlights in reading order: page, then top, then left.
List<Highlight> sortHighlightsForList(Iterable<Highlight> highlights) {
  double top(Highlight h) => h.position?.rects.firstOrNull?.y ?? 0;
  double left(Highlight h) => h.position?.rects.firstOrNull?.x ?? 0;
  int page(Highlight h) => h.position?.pageNumber ?? h.pageNumber ?? 0;
  return highlights.toList()..sort((a, b) {
    final p = page(a).compareTo(page(b));
    if (p != 0) return p;
    final t = top(a).compareTo(top(b));
    return t != 0 ? t : left(a).compareTo(left(b));
  });
}

/// Minimal Highlights tab: every text highlight of the paper in reading
/// order; tap jumps to it (ring flash + "Back to page N"); delete with undo.
class HighlightsTab extends ConsumerWidget {
  const HighlightsTab({super.key, required this.panel});

  final ReaderPanelContext panel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = context.paper;
    final async = ref.watch(readerHighlightsProvider(panel.paperId));
    final highlights = sortHighlightsForList(
      async.value ?? const <Highlight>[],
    );
    if (highlights.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(PaperSpacing.xl),
          child: Text(
            l10n.readerFirstHighlightHint,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: c.textMuted),
          ),
        ),
      );
    }
    return ListView.separated(
      key: const PageStorageKey<String>('panel-highlights'),
      padding: const EdgeInsets.all(PaperSpacing.panePadding),
      itemCount: highlights.length,
      separatorBuilder: (_, _) => const SizedBox(height: PaperSpacing.sm),
      itemBuilder: (context, i) => _HighlightRow(
        highlight: highlights[i],
        onTap: () => panel.onJumpToHighlight(highlights[i]),
        onDelete: () => unawaited(
          ref
              .read(readerControllerProvider(panel.paperId).notifier)
              .deleteHighlight(highlights[i]),
        ),
        colorName: highlightColorName(l10n, highlights[i].color),
      ),
    );
  }
}

class _HighlightRow extends StatelessWidget {
  const _HighlightRow({
    required this.highlight,
    required this.onTap,
    required this.onDelete,
    required this.colorName,
  });

  final Highlight highlight;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final String colorName;

  @override
  Widget build(BuildContext context) {
    final c = context.paper;
    final l10n = AppLocalizations.of(context);
    final hue = paperHue(highlight.color);
    final page = highlight.position?.pageNumber ?? highlight.pageNumber;
    return Semantics(
      button: true,
      label: l10n.a11yHighlight(colorName, highlight.selectedText),
      excludeSemantics: true,
      child: Material(
        color: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: PaperRadii.borderLg,
          side: BorderSide(color: c.border),
        ),
        child: InkWell(
          borderRadius: PaperRadii.borderLg,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              PaperSpacing.md,
              PaperSpacing.sm,
              PaperSpacing.xs,
              PaperSpacing.sm,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: hue.wash,
                      shape: BoxShape.circle,
                      border: Border.all(color: hue.ring, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(width: PaperSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (page != null)
                        Text(
                          'p.$page',
                          style: PaperTypography.pageIndicator(
                            c,
                          ).copyWith(color: c.textMuted),
                        ),
                      Text(
                        highlight.selectedText,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: PaperTypography.noteBody(c),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l10n.highlightDelete,
                  onPressed: onDelete,
                  icon: Icon(
                    Symbols.delete_rounded,
                    size: PaperIconSize.sm,
                    color: c.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
