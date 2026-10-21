import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/immersive.dart';
import '../../domain/domain.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/paper_tokens.dart';
import '../../theme/theme_x.dart';
import '../../ui/ui.dart';
import '../reader/reader_controller.dart';
import '../reader/widgets/highlight_layer.dart';
import '../reader/widgets/popover.dart' show highlightColorName;
import 'ai_states.dart';
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

/// Highlights tab, in the web `FigureHighlightsPanel` structure
/// (side-panel.md §3.2): eyebrow "HIGHLIGHTS" + count chip, then `p-3`
/// cards (gap 8) in reading order. Tapping a card jumps to the highlight
/// (ring flash + "Back to page N"); Delete asks for a second tap.
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
      return PanelEmptyState(body: l10n.readerFirstHighlightHint);
    }
    final label = l10n.panelTabHighlights;
    return ListView.separated(
      key: const PageStorageKey<String>('panel-highlights'),
      padding: SafeViewPadding.resolve(
        context,
        base: const EdgeInsets.all(PaperSpacing.tw4),
        left: false,
        top: false,
      ),
      itemCount: highlights.length + 1,
      separatorBuilder: (_, i) =>
          SizedBox(height: i == 0 ? PaperSpacing.tw3 : PaperSpacing.tw2),
      itemBuilder: (context, i) {
        if (i == 0) {
          return Semantics(
            header: true,
            label: '$label, ${highlights.length}',
            excludeSemantics: true,
            child: Row(
              children: <Widget>[
                Text(label.toUpperCase(), style: PaperTypography.eyebrow(c)),
                const SizedBox(width: PaperSpacing.tw2),
                PaperBadge.count(label: '${highlights.length}'),
              ],
            ),
          );
        }
        final h = highlights[i - 1];
        return _HighlightItem(
          key: ValueKey<String>('highlight-item-${h.id}'),
          highlight: h,
          onTap: () => panel.onJumpToHighlight(h),
          onDelete: () => unawaited(
            ref
                .read(readerControllerProvider(panel.paperId).notifier)
                .deleteHighlight(h),
          ),
          colorName: highlightColorName(l10n, h.color),
        );
      },
    );
  }
}

class _HighlightItem extends StatefulWidget {
  const _HighlightItem({
    super.key,
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
  State<_HighlightItem> createState() => _HighlightItemState();
}

class _HighlightItemState extends State<_HighlightItem> {
  final FocusNode _deleteFocus = FocusNode(debugLabel: 'highlight-delete');
  bool _confirm = false;

  @override
  void initState() {
    super.initState();
    // Blur resets the confirm step (web parity).
    _deleteFocus.addListener(() {
      if (!_deleteFocus.hasFocus && _confirm && mounted) {
        setState(() => _confirm = false);
      }
    });
  }

  @override
  void dispose() {
    _deleteFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final h = widget.highlight;
    final hue = paperHue(h.color);
    final page = h.position?.pageNumber ?? h.pageNumber;
    return PaperCard(
      padding: const EdgeInsets.all(PaperSpacing.tw3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PaperPressable(
            onPressed: widget.onTap,
            semanticLabel: l10n.a11yHighlight(widget.colorName, h.selectedText),
            excludeSemantics: true,
            builder: (context, states) {
              final hover =
                  states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.focused);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: PaperSpacing.tw1),
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
                  const SizedBox(width: PaperSpacing.tw3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (page != null)
                          Text(
                            l10n.highlightPageLabel(page),
                            style: TextStyle(
                              fontFamily: PaperTypography.sans,
                              fontFamilyFallback: PaperTypography.sansFallback,
                              fontSize: 14,
                              height: 20 / 14,
                              fontWeight: FontWeight.w600,
                              color: PaperWeb.gray100,
                              decoration: hover
                                  ? TextDecoration.underline
                                  : TextDecoration.none,
                              decorationColor: PaperWeb.gray100,
                            ),
                          ),
                        const SizedBox(height: PaperSpacing.tw1),
                        Text(
                          h.selectedText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: PaperTypography.sans,
                            fontFamilyFallback: PaperTypography.sansFallback,
                            fontSize: 12,
                            height: 1.625,
                            color: PaperWeb.gray300,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: PaperSpacing.tw2),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: _confirm
                ? PaperButton(
                    key: const ValueKey<String>('highlight-delete-confirm'),
                    label: l10n.highlightDeleteConfirm,
                    variant: PaperButtonVariant.popoverDestructive,
                    focusNode: _deleteFocus,
                    autofocus: true,
                    onPressed: widget.onDelete,
                  )
                : PaperButton.quiet(
                    key: const ValueKey<String>('highlight-delete'),
                    label: l10n.highlightDelete,
                    focusNode: _deleteFocus,
                    onPressed: () => setState(() => _confirm = true),
                  ),
          ),
        ],
      ),
    );
  }
}
