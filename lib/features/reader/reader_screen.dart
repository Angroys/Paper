import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app/routes.dart';
import '../../core/window_class.dart';
import '../../domain/domain.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/motion_extras.dart';
import '../../theme/paper_tokens.dart';
import '../../theme/theme_x.dart';
import '../panel/panel_layout.dart';
import '../panel/reader_side_panel.dart';
import '../panel/split_view.dart';
import 'reader_controller.dart';
import 'reader_shortcuts.dart';
import 'reader_viewport.dart';
import 'widgets/citation_popover.dart';
import 'widgets/popover.dart';
import 'widgets/reader_chrome.dart';
import 'widgets/reader_states.dart';
import 'widgets/selection_popovers.dart';

/// Full-screen reader route (`/reader/:paperId`, reader.md).
///
/// Public surface for other features:
/// - State + commands: `readerControllerProvider(paperId)`
///   ([ReaderController] / [ReaderState]); events on
///   `ReaderController.events` (explain / note requests, undo).
/// - Side panel tab bodies: `readerPanelSlotsProvider` ([ReaderPanelSlots]).
/// - PDF viewport injection (tests): `readerViewportBuilderProvider`.
/// - Route transition: `buildReaderPage` (reader_route.dart).
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({
    super.key,
    required this.paperId,
    this.singleKeyShortcuts = true,
    this.preferOverlayPanel = false,
  });

  final String paperId;

  /// Settings › Reader › "Single-key shortcuts".
  final bool singleKeyShortcuts;

  /// Settings › Reader › "Panel style" = Overlay.
  final bool preferOverlayPanel;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen>
    with SingleTickerProviderStateMixin {
  /// Toolbar auto-hide (motion #26): 0 = shown, 1 = hidden.
  late final AnimationController _toolbar = AnimationController(vsync: this);
  double _scrollAccumulator = 0;
  PaperWindowClass? _windowClass;
  PanelLayout? _panelLayout;
  bool _overlayHintShown = false;
  StreamSubscription<ReaderEvent>? _events;

  String get _paperId => widget.paperId;
  ReaderController get _ctrl =>
      ref.read(readerControllerProvider(_paperId).notifier);

  @override
  void initState() {
    super.initState();
    _events = _ctrl.events.listen(_onEvent);
  }

  @override
  void dispose() {
    unawaited(_events?.cancel());
    _toolbar.dispose();
    super.dispose();
  }

  void _onEvent(ReaderEvent event) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    switch (event) {
      case HighlightCreatedEvent(:final highlight):
        unawaited(
          SemanticsService.sendAnnouncement(
            View.of(context),
            l10n.highlightAnnouncement(
              highlightColorName(l10n, highlight.color),
            ),
            Directionality.of(context),
          ),
        );
        messenger
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(l10n.highlightCreatedUndo),
              duration: kUndoSnackbarDurationHighlight,
              action: SnackBarAction(
                label: l10n.commonUndo,
                onPressed: () => unawaited(_ctrl.undoCreate(highlight)),
              ),
            ),
          );
      case HighlightDeletedEvent(:final highlight):
        messenger
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(l10n.highlightDeletedUndo),
              duration: kUndoSnackbarDurationHighlight,
              action: SnackBarAction(
                label: l10n.commonUndo,
                onPressed: () => unawaited(_ctrl.undoDelete(highlight)),
              ),
            ),
          );
      case HighlightSaveFailedEvent(:final retry):
        messenger
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(l10n.highlightSaveFailed),
              action: SnackBarAction(
                label: l10n.commonRetry,
                onPressed: () => unawaited(retry()),
              ),
            ),
          );
      case FigureHighlightSavedEvent():
      case ExplainRequestedEvent():
      case NoteRequestedEvent():
        // Consumed by the side panel tabs (screens agent).
        break;
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.library);
    }
  }

  Future<void> _goToPage() async {
    final s = ref.read(readerControllerProvider(_paperId));
    if (s.pageCount < 1) return;
    final page = await showPageJumpDialog(
      context,
      current: s.currentPage,
      total: s.pageCount,
    );
    if (page != null) _ctrl.goToPage(page);
  }

  bool get _panelIsOverlay => !(_panelLayout?.isSplit ?? false);

  void _onScrollDelta(double dy) {
    if (_scrollAccumulator.sign != dy.sign) _scrollAccumulator = 0;
    _scrollAccumulator += dy;
    final s = ref.read(readerControllerProvider(_paperId));
    if (s.search.open || s.hasPopover) return;
    if (_scrollAccumulator >= kToolbarHideThreshold && _toolbar.value < 1) {
      _toolbar.duration = PaperMotion.of(context, PaperMotion.base);
      unawaited(_toolbar.animateTo(1, curve: PaperMotion.accelerate));
      _scrollAccumulator = 0;
    } else if (_scrollAccumulator <= -kToolbarHideThreshold &&
        _toolbar.value > 0) {
      _showToolbar();
      _scrollAccumulator = 0;
    }
  }

  void _showToolbar() {
    _toolbar.duration = PaperMotion.of(context, PaperMotion.base);
    unawaited(_toolbar.animateBack(0, curve: PaperMotion.decelerate));
  }

  void _onPanelLayout(PanelLayout layout) {
    _panelLayout = layout;
    final open = ref.read(readerControllerProvider(_paperId)).panelOpen;
    if (layout.fellBackToOverlay && open && !_overlayHintShown && mounted) {
      _overlayHintShown = true;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).readerPanelOverlayHint),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = readerControllerProvider(_paperId);
    final phase = ref.watch(provider.select((s) => s.phase));
    final title = ref.watch(provider.select((s) => s.paper?.title)) ?? '';
    final c = context.paper;

    final Widget body = switch (phase) {
      ReaderResolving() => const SizedBox.expand(),
      ReaderDownloading(:final progress) => ReaderLoadingState(
        title: title,
        progress: progress,
        onCancel: _back,
      ),
      ReaderLoadError(:final kind) => ReaderErrorState(
        kind: kind,
        onRetry: () => unawaited(_ctrl.retry()),
        onBack: _back,
      ),
      ReaderOpening(:final filePath) ||
      ReaderReady(:final filePath) => _buildReader(context, filePath),
    };

    return Scaffold(
      backgroundColor: c.readerBackdrop,
      body: SafeArea(
        bottom: false,
        child: phase is ReaderOpening || phase is ReaderReady
            ? body
            : Column(
                children: <Widget>[
                  _SimpleBar(onBack: _back, title: title),
                  Expanded(child: body),
                ],
              ),
      ),
    );
  }

  Widget _buildReader(BuildContext context, String filePath) {
    final provider = readerControllerProvider(_paperId);
    final panelOpen = ref.watch(provider.select((s) => s.panelOpen));
    final panelTab = ref.watch(provider.select((s) => s.panelTab));
    final searchOpen = ref.watch(provider.select((s) => s.search.open));
    final canPop = ref.watch(
      provider.select(
        (s) =>
            !s.hasPopover &&
            !s.search.open &&
            !(s.panelOpen && _panelIsOverlay),
      ),
    );
    final currentPage = ref.watch(provider.select((s) => s.currentPage));

    return LayoutBuilder(
      builder: (context, constraints) {
        final wc = resolveWindowClass(
          constraints.maxWidth,
          previous: _windowClass,
        );
        _windowClass = wc;
        final platform = Theme.of(context).platform;
        final pointer =
            platform == TargetPlatform.macOS ||
            platform == TargetPlatform.windows ||
            platform == TargetPlatform.linux;
        final toolbarHeight = PaperChrome.readerToolbarHeight(
          wc,
          pointer: pointer,
        );
        final autoHide =
            wc.index <= PaperWindowClass.medium.index ||
            constraints.maxHeight < kSplitMinWindowHeight;
        if (!autoHide && _toolbar.value != 0) _toolbar.value = 0;

        final toolbar = RepaintBoundary(
          // B5: hide/show is a transform on this cached layer.
          child: ReaderToolbar(
            paperId: _paperId,
            windowClass: wc,
            height: toolbarHeight,
            pointer: pointer,
            onBack: _back,
            onGoToPage: () => unawaited(_goToPage()),
          ),
        );

        final split = ReaderSplitView(
          open: panelOpen,
          onClose: _ctrl.closePanel,
          preferOverlay: widget.preferOverlayPanel,
          onLayoutChanged: _onPanelLayout,
          reader: _ReaderArea(
            paperId: _paperId,
            filePath: filePath,
            onScrollDelta: autoHide ? _onScrollDelta : null,
          ),
          panel: ReaderSidePanel(
            tab: panelTab,
            onTabChanged: _ctrl.setPanelTab,
            panel: ReaderPanelContext(
              paperId: _paperId,
              currentPage: currentPage,
              onJumpToHighlight: (h) {
                if (_panelIsOverlay) _ctrl.closePanel();
                _ctrl.jumpToHighlight(h);
              },
              onJumpToPage: (p) {
                if (_panelIsOverlay) _ctrl.closePanel();
                _ctrl.goToPage(p, rememberReturn: true);
              },
              onClose: _ctrl.closePanel,
            ),
          ),
        );

        final Widget content;
        if (!autoHide) {
          content = Column(
            children: <Widget>[
              toolbar,
              if (searchOpen) RepaintBoundary(child: FindBar(paperId: _paperId)),
              Expanded(child: split),
            ],
          );
        } else {
          final hide = Tween<Offset>(
            begin: Offset.zero,
            end: const Offset(0, -1),
          ).animate(_toolbar);
          final drop = Tween<Offset>(
            begin: Offset.zero,
            end: const Offset(0, 2),
          ).animate(_toolbar);
          final compact = wc == PaperWindowClass.compact;
          final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
          content = Stack(
            children: <Widget>[
              Positioned.fill(child: split),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SlideTransition(
                  position: hide,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      toolbar,
                      if (searchOpen)
                        RepaintBoundary(child: FindBar(paperId: _paperId)),
                    ],
                  ),
                ),
              ),
              if (!panelOpen)
                Positioned(
                  bottom: bottomInset + PaperSpacing.lg,
                  left: compact ? 0 : null,
                  right: compact ? 0 : PaperSpacing.xl,
                  child: SlideTransition(
                    position: drop,
                    child: RepaintBoundary(
                      child: compact
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                PageNavigator(
                                  paperId: _paperId,
                                  pill: true,
                                  onGoToPage: () => unawaited(_goToPage()),
                                ),
                                const SizedBox(height: PaperSpacing.sm),
                                Center(child: ToolDock(paperId: _paperId)),
                              ],
                            )
                          : PageNavigator(
                              paperId: _paperId,
                              pill: true,
                              onGoToPage: () => unawaited(_goToPage()),
                            ),
                    ),
                  ),
                ),
            ],
          );
        }

        return PopScope(
          canPop: canPop,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _ctrl.escape(panelIsOverlay: _panelIsOverlay);
          },
          child: ReaderShortcuts(
            paperId: _paperId,
            singleKeyShortcuts: widget.singleKeyShortcuts,
            panelIsOverlay: _panelIsOverlay,
            onClose: _back,
            onGoToPage: () => unawaited(_goToPage()),
            onCopySelection: () =>
                unawaited(copySelection(context, ref, _paperId)),
            child: content,
          ),
        );
      },
    );
  }
}

/// The PDF viewport plus everything anchored to it: popovers (B7), the
/// "Back to page N" pill and the no-text-layer strip.
class _ReaderArea extends ConsumerWidget {
  const _ReaderArea({
    required this.paperId,
    required this.filePath,
    this.onScrollDelta,
  });

  final String paperId;
  final String filePath;
  final ValueChanged<double>? onScrollDelta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final builder = ref.watch(readerViewportBuilderProvider);
    final hasText = ref.watch(
      readerControllerProvider(paperId).select((s) => s.hasTextLayer),
    );
    final c = context.paper;
    final l10n = AppLocalizations.of(context);
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        builder(
          context,
          ReaderViewportArgs(
            paperId: paperId,
            filePath: filePath,
            onScrollDelta: onScrollDelta,
          ),
        ),
        _PopoverLayer(paperId: paperId),
        if (!hasText)
          Positioned(
            top: PaperSpacing.sm,
            left: PaperSpacing.lg,
            right: PaperSpacing.lg,
            child: Center(
              child: Material(
                color: c.infoSurface,
                borderRadius: PaperRadii.borderLg,
                child: Padding(
                  padding: const EdgeInsets.all(PaperSpacing.md),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Symbols.info_rounded, size: PaperIconSize.sm, color: c.info),
                      const SizedBox(width: PaperSpacing.sm),
                      Flexible(child: Text(l10n.readerNoTextLayer)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: PaperSpacing.xxl + MediaQuery.viewPaddingOf(context).bottom,
          child: Center(child: ReturnPill(paperId: paperId)),
        ),
      ],
    );
  }
}

/// Popover layer (motion.md §1.4 B7): SelectionPopover, HighlightPicker and
/// CitationPopover, anchored in viewport-local coordinates. Hidden while the
/// page moves under them (motion #12).
class _PopoverLayer extends ConsumerWidget {
  const _PopoverLayer({required this.paperId});

  final String paperId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = readerControllerProvider(paperId);
    final hidden = ref.watch(
      provider.select((s) => s.overlaysHidden || s.gestureInProgress),
    );
    final selection = ref.watch(provider.select((s) => s.selection));
    final pickedId = ref.watch(provider.select((s) => s.selectedHighlightId));
    final pickedAnchor = ref.watch(
      provider.select((s) => s.selectedHighlightAnchor),
    );
    final citation = ref.watch(provider.select((s) => s.citation));
    if (hidden) return const SizedBox.shrink();

    Widget? popover;
    final selAnchor = selection?.anchor?.local;
    if (selection != null && selAnchor != null) {
      popover = AnchoredPopover(
        key: ValueKey<Object>(('selection', selection.text, selAnchor)),
        anchor: selAnchor,
        child: SelectionPopover(paperId: paperId, selection: selection),
      );
    } else if (pickedId != null && pickedAnchor?.local != null) {
      final highlights =
          ref.watch(readerHighlightsProvider(paperId)).value ??
          const <Highlight>[];
      final h = highlights.where((h) => h.id == pickedId).firstOrNull;
      if (h != null) {
        popover = AnchoredPopover(
          key: ValueKey<Object>(('picker', pickedId)),
          anchor: pickedAnchor!.local!,
          child: HighlightPicker(paperId: paperId, highlight: h),
        );
      }
    } else if (citation != null && citation.anchor.local != null) {
      popover = AnchoredPopover(
        key: ValueKey<Object>(('citation', citation.label)),
        anchor: citation.anchor.local!,
        maxWidth: 360,
        child: CitationPopover(paperId: paperId, target: citation),
      );
    }
    if (popover == null) return const SizedBox.shrink();
    return Positioned.fill(child: popover);
  }
}

/// Minimal bar for the loading / error states (no tools yet).
class _SimpleBar extends StatelessWidget {
  const _SimpleBar({required this.onBack, required this.title});

  final VoidCallback onBack;
  final String title;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: PaperChrome.readerToolbarCompact,
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: l10n.readerBack,
            onPressed: onBack,
            icon: const Icon(Symbols.arrow_back_rounded, size: PaperIconSize.md),
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}

