import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/paper_tokens.dart';
import '../../../theme/theme_x.dart';
import '../reader_controller.dart';

String readerToolLabel(AppLocalizations l10n, ReaderTool tool) => switch (tool) {
  ReaderTool.select => l10n.readerToolSelect,
  ReaderTool.highlight => l10n.readerToolHighlight,
  ReaderTool.pen => l10n.readerToolPen,
  ReaderTool.figure => l10n.readerToolFigure,
};

IconData readerToolIcon(ReaderTool tool) => switch (tool) {
  ReaderTool.select => Symbols.arrow_selector_tool_rounded,
  ReaderTool.highlight => Symbols.ink_highlighter_rounded,
  ReaderTool.pen => Symbols.stylus_rounded,
  ReaderTool.figure => Symbols.crop_free_rounded,
};

String _toolShortcut(ReaderTool tool) => switch (tool) {
  ReaderTool.select => 'V',
  ReaderTool.highlight => 'H',
  ReaderTool.pen => 'P',
  ReaderTool.figure => 'F',
};

/// `ToolModeSegmented`: Select / Highlight / Pen / Figure as a radio group.
class ToolModeSegmented extends ConsumerWidget {
  const ToolModeSegmented({
    super.key,
    required this.paperId,
    this.showLabels = false,
    this.dense = false,
  });

  final String paperId;
  final bool showLabels;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = context.paper;
    final provider = readerControllerProvider(paperId);
    final tool = ref.watch(provider.select((s) => s.tool));
    final hasText = ref.watch(provider.select((s) => s.hasTextLayer));
    final height = dense ? 32.0 : 40.0;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Container(
        height: height,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: c.surfaceVariant,
          borderRadius: PaperRadii.borderLg,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final t in ReaderTool.values)
              _Segment(
                key: ValueKey<String>('tool-${t.name}'),
                icon: readerToolIcon(t),
                label: readerToolLabel(l10n, t),
                tooltip: hasText || t != ReaderTool.highlight
                    ? '${readerToolLabel(l10n, t)} (${_toolShortcut(t)})'
                    : l10n.readerNoTextLayer,
                selected: t == tool,
                showLabel: showLabels,
                enabled: hasText || t != ReaderTool.highlight,
                width: dense ? 36 : 44,
                onTap: () =>
                    ref.read(provider.notifier).setTool(t),
              ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    super.key,
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.selected,
    required this.showLabel,
    required this.enabled,
    required this.width,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final bool selected;
  final bool showLabel;
  final bool enabled;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.paper;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          icon,
          size: PaperIconSize.md,
          color: !enabled
              ? c.textDisabled
              : (selected ? c.primary : c.textSecondary),
        ),
        if (showLabel) ...<Widget>[
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: enabled ? c.textPrimary : c.textDisabled,
            ),
          ),
        ],
      ],
    );
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: PaperRadii.borderMd,
            child: Container(
              constraints: BoxConstraints(minWidth: width),
              padding: EdgeInsets.symmetric(horizontal: showLabel ? 10 : 0),
              alignment: Alignment.center,
              decoration: selected
                  ? BoxDecoration(
                      color: c.surface,
                      borderRadius: PaperRadii.borderMd,
                      border: Border.all(color: c.border),
                    )
                  : null,
              child: content,
            ),
          ),
      ),
    );
  }
}

/// `PageNavigator`: ‹ · "12 / 34" (opens PageJumpDialog) · ›.
class PageNavigator extends ConsumerWidget {
  const PageNavigator({
    super.key,
    required this.paperId,
    required this.onGoToPage,
    this.pill = false,
  });

  final String paperId;
  final VoidCallback onGoToPage;

  /// Floating pill form (compact / medium): no chevrons, inverse surface.
  final bool pill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = context.paper;
    final provider = readerControllerProvider(paperId);
    final page = ref.watch(provider.select((s) => s.currentPage));
    final total = ref.watch(provider.select((s) => s.pageCount));
    final ctrl = ref.read(provider.notifier);
    final label = '$page / ${total < 1 ? '–' : total}';
    final semantics = l10n.readerPageIndicator(page, total);
    if (pill) {
      return Semantics(
        button: true,
        label: semantics,
        excludeSemantics: true,
        child: Material(
          color: c.inverseSurface,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onGoToPage,
            child: SizedBox(
              height: 40,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: PaperSpacing.lg),
                child: Center(
                  child: Text(
                    label,
                    style: PaperTypography.pageIndicator(
                      c,
                    ).copyWith(color: c.onInverseSurface),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton(
          tooltip: l10n.readerPrevPage,
          onPressed: page > 1 ? ctrl.previousPage : null,
          icon: const Icon(Symbols.chevron_left_rounded, size: PaperIconSize.md),
        ),
        Semantics(
          button: true,
          label: semantics,
          excludeSemantics: true,
          child: Tooltip(
            message: l10n.readerGoToPage,
            child: InkWell(
              onTap: onGoToPage,
              borderRadius: PaperRadii.borderMd,
              child: Container(
                constraints: const BoxConstraints(minWidth: 72),
                height: 28,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: PaperSpacing.sm),
                decoration: BoxDecoration(
                  color: c.surfaceVariant,
                  borderRadius: PaperRadii.borderMd,
                ),
                child: Text(label, style: PaperTypography.pageIndicator(c)),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: l10n.readerNextPage,
          onPressed: total > 0 && page < total ? ctrl.nextPage : null,
          icon: const Icon(Symbols.chevron_right_rounded, size: PaperIconSize.md),
        ),
      ],
    );
  }
}

enum _ZoomMenu { fitWidth, fitPage, step }

/// `ZoomControl`: − · "125%" (fit menu + steps) · +.
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton(
          tooltip: l10n.readerZoomOut,
          onPressed: zoom > kMinZoom + 1e-3 ? ctrl.zoomOut : null,
          icon: const Icon(Symbols.remove_rounded, size: PaperIconSize.md),
        ),
        Semantics(
          liveRegion: true,
          label: l10n.readerZoomLevel(percent),
          excludeSemantics: true,
          child: PopupMenuButton<(_ZoomMenu, double)>(
            tooltip: l10n.readerFitWidth,
            onSelected: (v) => switch (v.$1) {
              _ZoomMenu.fitWidth => ctrl.fitWidth(),
              _ZoomMenu.fitPage => ctrl.fitPage(),
              _ZoomMenu.step => ctrl.setZoom(v.$2),
            },
            itemBuilder: (context) => <PopupMenuEntry<(_ZoomMenu, double)>>[
              PopupMenuItem(
                value: (_ZoomMenu.fitWidth, 0),
                child: Text(l10n.readerFitWidth),
              ),
              PopupMenuItem(
                value: (_ZoomMenu.fitPage, 0),
                child: Text(l10n.readerFitPage),
              ),
              const PopupMenuDivider(),
              for (final s in kZoomSteps)
                PopupMenuItem(
                  value: (_ZoomMenu.step, s),
                  child: Text(l10n.readerZoomLevel((s * 100).round())),
                ),
            ],
            child: SizedBox(
              width: 60,
              height: 32,
              child: Center(
                child: Text(
                  l10n.readerZoomLevel(percent),
                  style: PaperTypography.pageIndicator(c).copyWith(fontSize: 13),
                ),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: l10n.readerZoomIn,
          onPressed: zoom < kMaxZoom - 1e-3 ? ctrl.zoomIn : null,
          icon: const Icon(Symbols.add_rounded, size: PaperIconSize.md),
        ),
      ],
    );
  }
}

/// `ReaderToolbar` per window class (components.md). Built once per state
/// change of the values it shows; it lives in its own RepaintBoundary (B5)
/// set up by the screen.
class ReaderToolbar extends ConsumerWidget {
  const ReaderToolbar({
    super.key,
    required this.paperId,
    required this.windowClass,
    required this.height,
    required this.onBack,
    required this.onGoToPage,
    this.pointer = false,
  });

  final String paperId;
  final PaperWindowClass windowClass;
  final double height;
  final VoidCallback onBack;
  final VoidCallback onGoToPage;
  final bool pointer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = context.paper;
    final provider = readerControllerProvider(paperId);
    final title = ref.watch(provider.select((s) => s.paper?.title)) ?? '';
    final panelOpen = ref.watch(provider.select((s) => s.panelOpen));
    final ctrl = ref.read(provider.notifier);
    final compact = windowClass == PaperWindowClass.compact;
    final inline = windowClass.index >= PaperWindowClass.expanded.index;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: dark ? c.background : c.surface,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.border)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: PaperSpacing.xs),
        child: Row(
          children: <Widget>[
            IconButton(
              tooltip: l10n.readerBack,
              onPressed: onBack,
              icon: const Icon(Symbols.arrow_back_rounded, size: PaperIconSize.md),
            ),
            const SizedBox(width: PaperSpacing.xs),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (!compact) ...<Widget>[
              const SizedBox(width: PaperSpacing.lg),
              ToolModeSegmented(
                paperId: paperId,
                dense: pointer && inline,
                showLabels: windowClass == PaperWindowClass.extraLarge,
              ),
              const SizedBox(width: PaperSpacing.lg),
            ],
            if (inline) ...<Widget>[
              PageNavigator(paperId: paperId, onGoToPage: onGoToPage),
              const SizedBox(width: PaperSpacing.sm),
              ZoomControl(paperId: paperId),
              IconButton(
                tooltip: l10n.readerFind,
                onPressed: ctrl.openSearch,
                icon: const Icon(Symbols.search_rounded, size: PaperIconSize.md),
              ),
            ],
            if (!compact)
              IconButton(
                tooltip: l10n.readerTogglePanel,
                isSelected: panelOpen,
                onPressed: ctrl.togglePanel,
                icon: Icon(
                  panelOpen
                      ? Symbols.right_panel_close_rounded
                      : Symbols.right_panel_open_rounded,
                  size: PaperIconSize.md,
                ),
              ),
            PopupMenuButton<int>(
              tooltip: l10n.readerMore,
              icon: const Icon(Symbols.more_vert_rounded, size: PaperIconSize.md),
              onSelected: (v) => switch (v) {
                0 => ctrl.openSearch(),
                1 => ctrl.fitWidth(),
                2 => ctrl.zoomIn(),
                3 => ctrl.zoomOut(),
                _ => null,
              },
              itemBuilder: (context) => <PopupMenuEntry<int>>[
                if (!inline) ...<PopupMenuEntry<int>>[
                  PopupMenuItem(value: 0, child: Text(l10n.readerFind)),
                  PopupMenuItem(value: 1, child: Text(l10n.readerFitWidth)),
                  PopupMenuItem(value: 2, child: Text(l10n.readerZoomIn)),
                  PopupMenuItem(value: 3, child: Text(l10n.readerZoomOut)),
                ],
                PopupMenuItem(value: 9, child: Text(l10n.readerPaperInfo)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// `ToolDock` (compact): floating pill with the 4 tools, eraser and panel.
class ToolDock extends ConsumerWidget {
  const ToolDock({super.key, required this.paperId});

  final String paperId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = context.paper;
    final provider = readerControllerProvider(paperId);
    final tool = ref.watch(provider.select((s) => s.tool));
    final eraser = ref.watch(provider.select((s) => s.eraser));
    final ctrl = ref.read(provider.notifier);
    Widget button(IconData icon, String label, bool selected, VoidCallback onTap) =>
        Semantics(
          button: true,
          selected: selected,
          label: label,
          excludeSemantics: true,
          child: Tooltip(
            message: label,
            child: InkResponse(
              onTap: onTap,
              radius: 24,
              child: SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: selected
                        ? BoxDecoration(color: c.primarySoft, shape: BoxShape.circle)
                        : null,
                    child: Icon(
                      icon,
                      size: PaperIconSize.lg,
                      color: selected ? c.onPrimarySoft : c.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: PaperRadii.borderFull,
        border: Border.all(color: c.border),
        boxShadow: PaperElevation.shadow2(Theme.of(context).brightness),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: PaperSpacing.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final t in ReaderTool.values)
              button(
                readerToolIcon(t),
                readerToolLabel(l10n, t),
                t == tool && !eraser,
                () => ctrl.setTool(t),
              ),
            button(
              Symbols.ink_eraser_rounded,
              l10n.readerToolEraser,
              eraser,
              ctrl.toggleEraser,
            ),
            button(
              Symbols.right_panel_open_rounded,
              l10n.readerTogglePanel,
              false,
              ctrl.togglePanel,
            ),
          ],
        ),
      ),
    );
  }
}

/// `FindBar`: field · count · ↑ ↓ · match case · close.
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
    _text.text = ref.read(readerControllerProvider(widget.paperId)).search.query;
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
    return Material(
      color: c.surface,
      child: Container(
        height: 48,
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.border))),
        padding: const EdgeInsets.symmetric(horizontal: PaperSpacing.sm),
        child: Row(
          children: <Widget>[
            Expanded(
              child: CallbackShortcuts(
                bindings: <ShortcutActivator, VoidCallback>{
                  const SingleActivator(LogicalKeyboardKey.enter): ctrl.searchNext,
                  const SingleActivator(LogicalKeyboardKey.enter, shift: true):
                      ctrl.searchPrevious,
                },
                child: TextField(
                  key: const ValueKey<String>('find-field'),
                  controller: _text,
                  focusNode: _focus,
                  onChanged: ctrl.setSearchQuery,
                  decoration: InputDecoration(
                    hintText: l10n.readerFind,
                    isDense: true,
                    prefixIcon: const Icon(Symbols.search_rounded, size: PaperIconSize.md),
                  ),
                ),
              ),
            ),
            const SizedBox(width: PaperSpacing.sm),
            Semantics(
              liveRegion: true,
              child: Text(
                noResults
                    ? l10n.readerFindNoResults
                    : (search.query.isEmpty
                          ? ''
                          : l10n.readerFindResultCount(search.current, search.total)),
                style: PaperTypography.pageIndicator(
                  c,
                ).copyWith(color: noResults ? c.error : c.textMuted),
              ),
            ),
            IconButton(
              tooltip: l10n.shortcutsPrevMatch,
              onPressed: search.total > 0 ? ctrl.searchPrevious : null,
              icon: const Icon(Symbols.keyboard_arrow_up_rounded, size: PaperIconSize.md),
            ),
            IconButton(
              tooltip: l10n.shortcutsNextMatch,
              onPressed: search.total > 0 ? ctrl.searchNext : null,
              icon: const Icon(Symbols.keyboard_arrow_down_rounded, size: PaperIconSize.md),
            ),
            IconButton(
              tooltip: l10n.readerFindMatchCase,
              isSelected: search.matchCase,
              onPressed: () => ctrl.setSearchMatchCase(!search.matchCase),
              icon: const Icon(Symbols.match_case_rounded, size: PaperIconSize.md),
            ),
            IconButton(
              tooltip: l10n.commonClose,
              onPressed: ctrl.closeSearch,
              icon: const Icon(Symbols.close_rounded, size: PaperIconSize.md),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Back to page N" return pill (motion #28).
class ReturnPill extends ConsumerWidget {
  const ReturnPill({super.key, required this.paperId});

  final String paperId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = context.paper;
    final provider = readerControllerProvider(paperId);
    final page = ref.watch(provider.select((s) => s.returnPage));
    if (page == null) return const SizedBox.shrink();
    return Material(
      color: c.inverseSurface,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: ref.read(provider.notifier).returnToPreviousPage,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PaperSpacing.lg,
            vertical: PaperSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Symbols.undo_rounded, size: PaperIconSize.sm, color: c.onInverseSurface),
              const SizedBox(width: PaperSpacing.xs),
              Text(
                l10n.readerBackToPage(page),
                style: TextStyle(color: c.onInverseSurface, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `PageJumpDialog`. Returns the chosen page or null.
Future<int?> showPageJumpDialog(
  BuildContext context, {
  required int current,
  required int total,
}) {
  final l10n = AppLocalizations.of(context);
  final controller = TextEditingController(text: '$current');
  String? error;
  return showDialog<int>(
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

        return AlertDialog(
          title: Text(l10n.readerPageJumpTitle),
          content: SizedBox(
            width: 280,
            child: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(
                labelText: l10n.readerPageJumpField,
                errorText: error,
              ),
              onSubmitted: (_) => submit(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(onPressed: submit, child: Text(l10n.readerGoToPage)),
          ],
        );
      },
    ),
  ).whenComplete(controller.dispose);
}
