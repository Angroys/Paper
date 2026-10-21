import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/build_flags.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/paper_tokens.dart';
import '../../../theme/theme_x.dart';
import '../../../ui/ui.dart';
import '../../sync/sync_badge.dart';
import '../reader_controller.dart';

String readerToolLabel(AppLocalizations l10n, ReaderTool tool) =>
    switch (tool) {
      ReaderTool.select => l10n.readerToolSelect,
      ReaderTool.highlight => l10n.readerToolHighlight,
      ReaderTool.pen => l10n.readerToolPen,
      ReaderTool.figure => l10n.readerToolFigure,
    };

/// Tool glyphs (components.md §19): Lucide mouse-pointer-2 / the web
/// highlighter / Lucide pen-line / Lucide scan.
PaperIcons readerToolIcon(ReaderTool tool) => switch (tool) {
  ReaderTool.select => PaperIcons.mousePointer,
  ReaderTool.highlight => PaperIcons.highlighter,
  ReaderTool.pen => PaperIcons.penLine,
  ReaderTool.figure => PaperIcons.scan,
};

String _toolShortcut(ReaderTool tool) => switch (tool) {
  ReaderTool.select => 'V',
  ReaderTool.highlight => 'H',
  ReaderTool.pen => 'P',
  ReaderTool.figure => 'F',
};

/// Header strip content height (`py-3` around 28): 52, + 1px border.
const double kReaderHeaderHeight = 52;

/// `ToolModeSegmented`: Select / Highlight / Pen / Figure as a
/// `PaperSegmented.sm` with four 24×24 icon segments (28 tall, tooltips
/// only, selected accent-soft / accent-ink).
class ToolModeSegmented extends ConsumerWidget {
  const ToolModeSegmented({super.key, required this.paperId});

  final String paperId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final provider = readerControllerProvider(paperId);
    final tool = ref.watch(provider.select((s) => s.tool));
    final hasText = ref.watch(provider.select((s) => s.hasTextLayer));
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: PaperSegmented<ReaderTool>(
        size: PaperSegmentedSize.sm,
        selected: tool,
        onChanged: (t) => ref.read(provider.notifier).setTool(t),
        segments: <PaperSegment<ReaderTool>>[
          for (final t in ReaderTool.values)
            PaperSegment<ReaderTool>(
              key: ValueKey<String>('tool-${t.name}'),
              value: t,
              icon: PaperIcon(readerToolIcon(t)),
              enabled: hasText || t != ReaderTool.highlight,
              tooltip: hasText || t != ReaderTool.highlight
                  ? '${readerToolLabel(l10n, t)} (${_toolShortcut(t)})'
                  : l10n.readerNoTextLayer,
            ),
        ],
      ),
    );
  }
}

/// `PageNavigator`: prev 24 · "3 / 12" (`PaperButton.ghost xxs`, opens the
/// go-to-page dialog) · next 24 (mirrored), gap 2.
class PageNavigator extends ConsumerWidget {
  const PageNavigator({
    super.key,
    required this.paperId,
    required this.onGoToPage,
  });

  final String paperId;
  final VoidCallback onGoToPage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final provider = readerControllerProvider(paperId);
    final page = ref.watch(provider.select((s) => s.currentPage));
    final total = ref.watch(provider.select((s) => s.pageCount));
    final ctrl = ref.read(provider.notifier);
    final label = '$page / ${total < 1 ? '–' : total}';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        PaperIconButton(
          size: PaperIconButtonSize.s24,
          tooltip: l10n.readerPrevPage,
          icon: const PaperIcon(PaperIcons.navBack),
          onPressed: page > 1 ? ctrl.previousPage : null,
        ),
        const SizedBox(width: PaperSpacing.tw0_5),
        PaperButton.ghost(
          label: label,
          size: PaperButtonSize.xxs,
          tooltip: l10n.readerGoToPage,
          semanticLabel: l10n.readerPageIndicator(page, total),
          onPressed: onGoToPage,
        ),
        const SizedBox(width: PaperSpacing.tw0_5),
        PaperIconButton(
          size: PaperIconButtonSize.s24,
          tooltip: l10n.readerNextPage,
          icon: const PaperIcon(PaperIcons.navBack, mirror: true),
          onPressed: total > 0 && page < total ? ctrl.nextPage : null,
        ),
      ],
    );
  }
}

/// The web zoom pill (components.md §11.2): 36 tall, gray-900, 1px
/// gray-800, radius 6, `px-2 py-1`, gap 6, shadow-sm; `−` / `+` 26
/// bordered buttons around the `pageIndicator` percentage (min 48; tap =
/// fit width).
class ZoomControl extends ConsumerWidget {
  const ZoomControl({super.key, required this.paperId});

  final String paperId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = context.paper;
    final provider = readerControllerProvider(paperId);
    final zoom = ref.watch(provider.select((s) => s.zoom));
    final ctrl = ref.read(provider.notifier);
    final percent = (zoom * 100).round();
    return ReaderPill(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PaperIconButton(
            size: PaperIconButtonSize.zoom26,
            tooltip: l10n.readerZoomOut,
            focusGap: PaperWeb.gray900,
            icon: const Text('−'),
            onPressed: zoom > kMinZoom + 1e-3 ? ctrl.zoomOut : null,
          ),
          const SizedBox(width: PaperSpacing.tw1_5),
          Semantics(
            liveRegion: true,
            button: true,
            label: l10n.readerZoomLevel(percent),
            excludeSemantics: true,
            child: Tooltip(
              message: l10n.readerFitWidth,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: ctrl.fitWidth,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 48),
                  child: Text(
                    l10n.readerZoomLevel(percent),
                    textAlign: TextAlign.center,
                    style: PaperTypography.pageIndicator(c),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: PaperSpacing.tw1_5),
          PaperIconButton(
            size: PaperIconButtonSize.zoom26,
            tooltip: l10n.readerZoomIn,
            focusGap: PaperWeb.gray900,
            icon: const Text('+'),
            onPressed: zoom < kMaxZoom - 1e-3 ? ctrl.zoomIn : null,
          ),
        ],
      ),
    );
  }
}

/// The toolbar-pill box shared by the zoom pill and the tool dock: 36 tall,
/// gray-900, 1px gray-800, radius 6, `px-2 py-1`, shadow-sm.
class ReaderPill extends StatelessWidget {
  const ReaderPill({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    height: 36,
    padding: const EdgeInsets.symmetric(
      horizontal: PaperSpacing.tw2,
      vertical: PaperSpacing.tw1,
    ),
    decoration: BoxDecoration(
      color: PaperWeb.gray900,
      border: Border.all(color: PaperWeb.gray800),
      borderRadius: PaperRadii.borderMd,
      boxShadow: PaperElevation.shadowSm,
    ),
    child: child,
  );
}

/// `ReaderHeader` (components.md §11.1, reader.md §2): the 52 + 1 strip.
/// Fill gray-950 bleeds under the top / side cutouts; content is inset.
/// ≥ 640: back · title · tools · page navigator · find · sync · ···.
/// < 640: back · title · find · sync · ··· (tools in the `ToolDock`, the
/// page navigator in the menu). While find is open the [FindBar] replaces
/// the tool / page / find controls.
class ReaderToolbar extends ConsumerWidget {
  const ReaderToolbar({
    super.key,
    required this.paperId,
    required this.onBack,
    required this.onGoToPage,
  });

  final String paperId;
  final VoidCallback onBack;
  final VoidCallback onGoToPage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = context.paper;
    final provider = readerControllerProvider(paperId);
    final title = ref.watch(provider.select((s) => s.paper?.title)) ?? '';
    final searchOpen = ref.watch(provider.select((s) => s.search.open));
    final ctrl = ref.read(provider.notifier);
    final wide = WebBreakpoint.of(context).isSmUp;
    final pad = MediaQuery.viewPaddingOf(context);

    final controls = <Widget>[
      if (searchOpen)
        Flexible(flex: 3, child: FindBar(paperId: paperId))
      else ...<Widget>[
        if (wide) ...<Widget>[
          ToolModeSegmented(paperId: paperId),
          PageNavigator(paperId: paperId, onGoToPage: onGoToPage),
        ],
        PaperIconButton(
          key: const ValueKey<String>('reader-find'),
          size: PaperIconButtonSize.s28,
          tooltip: l10n.readerFind,
          icon: const PaperIcon(PaperIcons.search),
          onPressed: ctrl.openSearch,
        ),
      ],
      // Sync status (sync-status.md); none in offline-only builds.
      if (!ref.watch(offlineOnlyProvider))
        const SyncBadge(iconSize: PaperIconButtonSize.s28),
      MenuAnchor(
        alignmentOffset: const Offset(0, 4),
        menuChildren: <Widget>[
          if (!wide) ...<Widget>[
            PaperMenuItem(label: l10n.readerGoToPage, onPressed: onGoToPage),
            PaperMenuItem(label: l10n.readerFind, onPressed: ctrl.openSearch),
          ],
          PaperMenuItem(label: l10n.readerFitWidth, onPressed: ctrl.fitWidth),
          PaperMenuItem(label: l10n.readerPaperInfo, onPressed: () {}),
        ],
        builder: (context, menu, _) => PaperButton.ghost(
          key: const ValueKey<String>('reader-more'),
          label: '···',
          size: PaperButtonSize.xs,
          tooltip: l10n.readerMore,
          open: menu.isOpen,
          onPressed: () => menu.isOpen ? menu.close() : menu.open(),
        ),
      ),
    ];

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: PaperWeb.gray950,
        border: Border(bottom: BorderSide(color: PaperWeb.gray800)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          PaperSpacing.tw4 + pad.left,
          pad.top,
          PaperSpacing.tw4 + pad.right,
          1, // the 1px bottom border sits below the 52 content
        ),
        child: SizedBox(
          height: kReaderHeaderHeight,
          child: Row(
            children: <Widget>[
              // `-m-1`: the glyph box starts at x = 12.
              Transform.translate(
                offset: const Offset(-4, 0),
                child: PaperIconButton(
                  size: PaperIconButtonSize.s28,
                  tooltip: l10n.readerBack,
                  icon: const PaperIcon(PaperIcons.readerBack, size: 20),
                  onPressed: onBack,
                ),
              ),
              const SizedBox(width: PaperSpacing.tw2 - 4),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 120),
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PaperTypography.sectionTitle(c),
                  ),
                ),
              ),
              for (final w in controls) ...<Widget>[
                const SizedBox(width: PaperSpacing.tw2),
                w,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// `ToolDock` (< 640, components.md §11.6): a zoom-pill box with 28 icon
/// buttons for the four tools and the eraser (selected accent-soft /
/// accent-ink), bottom-centred in the pane.
class ToolDock extends ConsumerWidget {
  const ToolDock({super.key, required this.paperId});

  final String paperId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final provider = readerControllerProvider(paperId);
    final tool = ref.watch(provider.select((s) => s.tool));
    final eraser = ref.watch(provider.select((s) => s.eraser));
    final ctrl = ref.read(provider.notifier);
    Widget button(
      PaperIcons icon,
      String label,
      bool selected,
      VoidCallback onTap,
    ) => PaperIconButton(
      size: PaperIconButtonSize.s28,
      tooltip: label,
      selected: selected,
      icon: PaperIcon(icon),
      onPressed: onTap,
    );
    return ReaderPill(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final t in ReaderTool.values) ...<Widget>[
            button(
              readerToolIcon(t),
              readerToolLabel(l10n, t),
              t == tool && !eraser,
              () => ctrl.setTool(t),
            ),
            const SizedBox(width: PaperSpacing.tw1_5),
          ],
          button(
            PaperIcons.eraser,
            l10n.readerToolEraser,
            eraser,
            ctrl.toggleEraser,
          ),
        ],
      ),
    );
  }
}

/// `FindBar` (components.md §11.5), in the header strip: `PaperTextField.xs`
/// 256×26 · match count · prev / next 24 · `Aa` toggle · `×` 24. The strip
/// height does not change.
class FindBar extends ConsumerStatefulWidget {
  const FindBar({super.key, required this.paperId});

  final String paperId;

  @override
  ConsumerState<FindBar> createState() => _FindBarState();
}

class _FindBarState extends ConsumerState<FindBar> {
  final TextEditingController _text = TextEditingController();
  final FocusNode _focus = FocusNode(debugLabel: 'find-field');

  @override
  void initState() {
    super.initState();
    _text.text = ref
        .read(readerControllerProvider(widget.paperId))
        .search
        .query;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.paper;
    final provider = readerControllerProvider(widget.paperId);
    final search = ref.watch(provider.select((s) => s.search));
    final ctrl = ref.read(provider.notifier);
    final noResults = search.query.isNotEmpty && search.total == 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 256),
            child: CallbackShortcuts(
              bindings: <ShortcutActivator, VoidCallback>{
                const SingleActivator(LogicalKeyboardKey.enter):
                    ctrl.searchNext,
                const SingleActivator(LogicalKeyboardKey.enter, shift: true):
                    ctrl.searchPrevious,
              },
              child: PaperTextField(
                fieldKey: const ValueKey<String>('find-field'),
                controller: _text,
                focusNode: _focus,
                size: PaperTextFieldSize.xs,
                hintText: l10n.readerFind,
                onChanged: ctrl.setSearchQuery,
              ),
            ),
          ),
        ),
        const SizedBox(width: PaperSpacing.tw2),
        Semantics(
          liveRegion: true,
          child: Text(
            noResults
                ? l10n.readerFindNoResults
                : (search.query.isEmpty
                      ? ''
                      : l10n.readerFindResultCount(
                          search.current,
                          search.total,
                        )),
            style: PaperTypography.pageIndicator(
              c,
            ).copyWith(color: noResults ? PaperWeb.red400 : PaperWeb.gray400),
          ),
        ),
        const SizedBox(width: PaperSpacing.tw1),
        PaperIconButton(
          size: PaperIconButtonSize.s24,
          tooltip: l10n.shortcutsPrevMatch,
          icon: const PaperIcon(PaperIcons.chevronDown, quarterTurns: 2),
          onPressed: search.total > 0 ? ctrl.searchPrevious : null,
        ),
        PaperIconButton(
          size: PaperIconButtonSize.s24,
          tooltip: l10n.shortcutsNextMatch,
          icon: const PaperIcon(PaperIcons.chevronDown),
          onPressed: search.total > 0 ? ctrl.searchNext : null,
        ),
        const SizedBox(width: PaperSpacing.tw1),
        Tooltip(
          message: l10n.readerFindMatchCase,
          child: PaperSegmented<bool>(
            size: PaperSegmentedSize.sm,
            selected: search.matchCase,
            onChanged: (_) => ctrl.setSearchMatchCase(!search.matchCase),
            segments: <PaperSegment<bool>>[
              PaperSegment<bool>(
                key: const ValueKey<String>('find-match-case'),
                value: true,
                label: 'Aa',
                tooltip: l10n.readerFindMatchCase,
              ),
            ],
          ),
        ),
        const SizedBox(width: PaperSpacing.tw1),
        PaperIconButton(
          size: PaperIconButtonSize.s24,
          tooltip: l10n.commonClose,
          icon: const PaperCloseGlyph(),
          onPressed: ctrl.closeSearch,
        ),
      ],
    );
  }
}

/// "↩ Back to page N" (components.md §11.4): 38 tall, radius full, gray-900
/// + 1px gray-700, `px-4 py-2 sm 500 gray-100`, shadow-lg, hover gray-800.
class ReturnPill extends ConsumerWidget {
  const ReturnPill({super.key, required this.paperId});

  final String paperId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final provider = readerControllerProvider(paperId);
    final page = ref.watch(provider.select((s) => s.returnPage));
    if (page == null) return const SizedBox.shrink();
    const style = TextStyle(
      fontFamily: PaperTypography.sans,
      fontFamilyFallback: PaperTypography.sansFallback,
      fontSize: 14,
      height: 20 / 14,
      fontWeight: FontWeight.w500,
      color: PaperWeb.gray100,
    );
    return PaperPressable(
      onPressed: ref.read(provider.notifier).returnToPreviousPage,
      semanticLabel: l10n.readerBackToPage(page),
      excludeSemantics: true,
      builder: (context, states) {
        final active =
            states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.pressed);
        return PaperFocusRing(
          show: states.contains(WidgetState.focused),
          radius: PaperRadii.borderFull,
          offset: 0,
          child: PaperColorBox(
            color: active ? PaperWeb.gray800 : PaperWeb.gray900,
            borderColor: PaperWeb.gray700,
            radius: PaperRadii.borderFull,
            boxShadow: PaperElevation.shadowLg,
            constraints: const BoxConstraints.tightFor(height: 38),
            padding: const EdgeInsets.symmetric(horizontal: PaperSpacing.tw4),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text('↩ ', style: style),
                Text(l10n.readerBackToPage(page), style: style),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// `ShowPanelButton` (reader.md §3.3): 36 bordered, `panel-show.svg` 20.
class ShowPanelButton extends StatelessWidget {
  const ShowPanelButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => PaperIconButton(
    key: const ValueKey<String>('reader-show-panel'),
    size: PaperIconButtonSize.s36Bordered,
    tooltip: AppLocalizations.of(context).readerTogglePanel,
    icon: const PaperIcon(PaperIcons.panelShow, size: 20),
    onPressed: onPressed,
  );
}

/// `PageJumpDialog` (a `PaperDialog`). Returns the chosen page or null.
Future<int?> showPageJumpDialog(
  BuildContext context, {
  required int current,
  required int total,
}) {
  final l10n = AppLocalizations.of(context);
  final controller = TextEditingController(text: '$current');
  String? error;
  return showPaperDialog<int>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        void submit() {
          final n = int.tryParse(controller.text.trim());
          if (n == null || n < 1 || n > total) {
            setState(() => error = l10n.readerPageOutOfRange(total));
            return;
          }
          Navigator.of(context).pop(n);
        }

        return PaperDialog(
          title: l10n.readerPageJumpTitle,
          content: PaperTextField(
            controller: controller,
            autofocus: true,
            label: l10n.readerPageJumpField,
            errorText: error,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            onSubmitted: (_) => submit(),
          ),
          actions: <Widget>[
            PaperButton.secondary(
              label: l10n.commonCancel,
              focusGap: PaperWeb.gray900,
              onPressed: () => Navigator.of(context).pop(),
            ),
            PaperButton.primary(
              label: l10n.readerGoToPage,
              focusGap: PaperWeb.gray900,
              onPressed: submit,
            ),
          ],
        );
      },
    ),
  ).whenComplete(controller.dispose);
}
