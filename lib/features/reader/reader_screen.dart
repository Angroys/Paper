import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../auth/auth_providers.dart';
import '../../core/core_providers.dart';
import '../../domain/domain.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/motion_extras.dart';
import '../../theme/paper_tokens.dart';
import '../../theme/theme_x.dart';
import '../../ui/ui.dart';
import '../auth/sign_in_prompt.dart';
import '../panel/ai_states.dart';
import '../panel/explanation_tab.dart';
import '../panel/panel_layout.dart';
import '../panel/panel_session.dart';
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

/// Full-screen reader route (`/reader/:paperId`, screens/reader.md): the
/// 52 + 1 header strip, then the PDF pane and the side panel (docked 384 at
/// ≥ 1024, overlay at 640–1023, bottom sheet below). No app nav bar.
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

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  PanelLayout? _panelLayout;
  bool _dockedDefaultApplied = false;
  StreamSubscription<ReaderEvent>? _events;
  PaperToastHandle? _toast;

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
    _toast?.dismiss();
    super.dispose();
  }

  void _showToast(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
    PaperToastTone tone = PaperToastTone.plain,
  }) {
    final l10n = AppLocalizations.of(context);
    _toast = showPaperToast(
      context,
      message: message,
      dismissTooltip: l10n.commonDismiss,
      tone: tone,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  void _onEvent(ReaderEvent event) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
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
        _showToast(
          l10n.highlightCreatedUndo,
          actionLabel: l10n.commonUndo,
          onAction: () => unawaited(_ctrl.undoCreate(highlight)),
          duration: kUndoSnackbarDurationHighlight,
        );
      case HighlightDeletedEvent(:final highlight):
        _showToast(
          l10n.highlightDeletedUndo,
          actionLabel: l10n.commonUndo,
          onAction: () => unawaited(_ctrl.undoDelete(highlight)),
          duration: kUndoSnackbarDurationHighlight,
        );
      case HighlightSaveFailedEvent(:final retry):
        _showToast(
          l10n.highlightSaveFailed,
          tone: PaperToastTone.error,
          actionLabel: l10n.commonRetry,
          onAction: () => unawaited(retry()),
          duration: kUndoSnackbarDurationHighlight,
        );
      case FigureHighlightSavedEvent():
      case ExplainRequestedEvent():
      case NoteRequestedEvent():
        // Consumed by the side panel tabs.
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

  void _onPanelLayout(PanelLayout layout) {
    _panelLayout = layout;
    // Docked (≥ 1024) defaults to open, as on web desktop; overlay and
    // sheet default to closed (side-panel.md §1).
    if (!_dockedDefaultApplied && mounted) {
      _dockedDefaultApplied = true;
      if (layout.isSplit) _ctrl.openPanel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = readerControllerProvider(_paperId);
    final phase = ref.watch(provider.select((s) => s.phase));
    final title = ref.watch(provider.select((s) => s.paper?.title)) ?? '';

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
      backgroundColor: PaperWeb.gray950,
      // IME never resizes the reader (README §4.6); panel fields lift
      // their own container.
      resizeToAvoidBottomInset: false,
      body: phase is ReaderOpening || phase is ReaderReady
          ? body
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _SimpleBar(onBack: _back, title: title),
                Expanded(
                  child: MediaQuery.removeViewPadding(
                    context: context,
                    removeTop: true,
                    child: body,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildReader(BuildContext context, String filePath) {
    final provider = readerControllerProvider(_paperId);
    final panelOpen = ref.watch(provider.select((s) => s.panelOpen));
    final panelTab = ref.watch(provider.select((s) => s.panelTab));
    final canPop = ref.watch(
      provider.select(
        (s) =>
            !s.hasPopover &&
            !s.search.open &&
            !(s.panelOpen && _panelIsOverlay),
      ),
    );
    final currentPage = ref.watch(provider.select((s) => s.currentPage));

    final panelContext = ReaderPanelContext(
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
    );

    final split = ReaderSplitView(
      open: panelOpen,
      onClose: _ctrl.closePanel,
      preferOverlay: widget.preferOverlayPanel,
      onLayoutChanged: _onPanelLayout,
      reader: _ReaderArea(
        paperId: _paperId,
        filePath: filePath,
        panel: panelContext,
      ),
      panel: ReaderSidePanel(
        tab: panelTab,
        onTabChanged: _ctrl.setPanelTab,
        panel: panelContext,
      ),
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        RepaintBoundary(
          child: ReaderToolbar(
            paperId: _paperId,
            onBack: _back,
            onGoToPage: () => unawaited(_goToPage()),
          ),
        ),
        Expanded(
          // The strip owns the top inset.
          child: MediaQuery.removeViewPadding(
            context: context,
            removeTop: true,
            child: split,
          ),
        ),
      ],
    );

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
        onCopySelection: () => unawaited(copySelection(context, ref, _paperId)),
        child: content,
      ),
    );
  }
}

/// The PDF pane (reader.md §3): the viewport plus everything anchored to it
/// — popovers (B7), the zoom pill, the show-panel button, the "Back to
/// page N" pill, the tool dock (< 640) and the no-text-layer notice. The
/// gray-950 backdrop is full-bleed; the chrome is inset by the view padding.
class _ReaderArea extends ConsumerWidget {
  const _ReaderArea({
    required this.paperId,
    required this.filePath,
    required this.panel,
  });

  final String paperId;
  final String filePath;
  final ReaderPanelContext panel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final builder = ref.watch(readerViewportBuilderProvider);
    final provider = readerControllerProvider(paperId);
    final hasText = ref.watch(provider.select((s) => s.hasTextLayer));
    final panelOpen = ref.watch(provider.select((s) => s.panelOpen));
    final popover = ref.watch(provider.select((s) => s.hasPopover));
    final returnPage = ref.watch(provider.select((s) => s.returnPage));
    final ctrl = ref.read(provider.notifier);
    final l10n = AppLocalizations.of(context);
    final pad = MediaQuery.viewPaddingOf(context);
    final narrow = !WebBreakpoint.of(context).isSmUp;
    final dock = narrow && !popover;
    final bottom = PaperSpacing.tw6 + pad.bottom;
    return ColoredBox(
      color: PaperWeb.gray950,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          builder(
            context,
            ReaderViewportArgs(paperId: paperId, filePath: filePath),
          ),
          // Zoom pill: centred on the pane, 24 below its top; pages scroll
          // under it (PaperLayer.readerChrome, above the selection popover).
          Positioned(
            top: PaperSpacing.tw6,
            left: pad.left,
            right: pad.right,
            child: Center(child: ZoomControl(paperId: paperId)),
          ),
          if (!hasText)
            Positioned(
              top: PaperSpacing.tw6 + 36 + PaperSpacing.tw2,
              left: PaperSpacing.tw4 + pad.left,
              right: PaperSpacing.tw4 + pad.right,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: PaperSpacing.tw4,
                    vertical: PaperSpacing.tw2_5,
                  ),
                  decoration: BoxDecoration(
                    color: PaperWeb.accentSoft,
                    border: Border.all(color: PaperWeb.gray800),
                    borderRadius: PaperRadii.borderMd,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: PaperIcon(
                          PaperIcons.info,
                          color: PaperWeb.accentInk,
                        ),
                      ),
                      const SizedBox(width: PaperSpacing.tw3),
                      Flexible(
                        child: Text(
                          l10n.readerNoTextLayer,
                          style: PaperTypography.input(context.paper)
                              .copyWith(color: PaperWeb.accentInk),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (!panelOpen)
            Positioned(
              top: PaperSpacing.tw3,
              right: PaperSpacing.tw3 + pad.right,
              child: ShowPanelButton(onPressed: ctrl.openPanel),
            ),
          if (returnPage != null)
            Positioned(
              left: pad.left,
              right: pad.right,
              bottom: dock ? bottom + 36 + PaperSpacing.tw2 : bottom,
              child: Center(child: ReturnPill(paperId: paperId)),
            ),
          if (dock)
            Positioned(
              left: pad.left,
              right: pad.right,
              bottom: bottom,
              child: Center(child: ToolDock(paperId: paperId)),
            ),
          _PopoverLayer(paperId: paperId, panel: panel),
        ],
      ),
    );
  }
}

/// Popover layer (motion.md §1.4 B7): SelectionPopover, HighlightPicker,
/// CitationPopover and the floating explanation, anchored in pane-local
/// coordinates. Hidden while the page moves under them (motion #12).
class _PopoverLayer extends ConsumerWidget {
  const _PopoverLayer({required this.paperId, required this.panel});

  final String paperId;
  final ReaderPanelContext panel;

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
    final explain = ref.watch(provider.select((s) => s.explainAnchor));
    final panelOpen = ref.watch(provider.select((s) => s.panelOpen));
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
        maxWidth: 320,
        gap: 6,
        preferBelow: true,
        child: CitationPopover(paperId: paperId, target: citation),
      );
    } else if (explain?.local != null && !panelOpen) {
      final width = math.min(320.0, MediaQuery.sizeOf(context).width - 16);
      popover = AnchoredPopover(
        key: const ValueKey<String>('floating-explanation'),
        anchor: explain!.local!,
        maxWidth: width,
        preferBelow: true,
        child: TapRegion(
          onTapOutside: (_) => ref.read(provider.notifier).dismissExplanation(),
          child: FloatingExplanationPopover(
            paperId: paperId,
            panel: panel,
            width: width,
          ),
        ),
      );
    }
    if (popover == null) return const SizedBox.shrink();
    return Positioned.fill(child: popover);
  }
}

/// `FloatingExplanationPopover` (components.md §10.3, reader.md §6): a
/// `min(320, window − 16)` gray-950 shell (1px gray-800, radius 8,
/// shadow-xl, ≤ 70% of the window tall, scrolls inside) holding the newest
/// `ExplanationCard`. Shown while the side panel is not visible; the card
/// stays in the Explanation tab.
class FloatingExplanationPopover extends ConsumerWidget {
  const FloatingExplanationPopover({
    super.key,
    required this.paperId,
    required this.panel,
    required this.width,
  });

  static const Key shellKey = ValueKey<String>('floating-explanation-shell');

  final String paperId;
  final ReaderPanelContext panel;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final online = ref.watch(isOnlineProvider).value ?? true;
    final stack = ref.watch(explanationStackProvider(paperId));
    final ctrl = ref.read(readerControllerProvider(paperId).notifier);
    final Widget content;
    if (ref.watch(isGuestProvider)) {
      content = const SignInPrompt(
        feature: GuestFeature.explanation,
        dense: true,
      );
    } else if (online && stack.unavailableReason != null) {
      content = EmptyStateCard(
        title: l10n.aiUnavailableTitle,
        body: l10n.aiUnavailableBody,
        action: PaperButton.secondary(
          label: l10n.aiRetry,
          focusGap: PaperWeb.gray900,
          onPressed: () => unawaited(
            ref
                .read(explanationStackProvider(paperId).notifier)
                .retryUnavailable(),
          ),
        ),
      );
    } else if (stack.entries.isEmpty) {
      return const SizedBox.shrink();
    } else {
      content = ExplanationCard(
        entry: stack.entries.first,
        online: online,
        panel: panel,
        onDismiss: ctrl.dismissExplanation,
      );
    }
    return Container(
      key: shellKey,
      width: width,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      decoration: BoxDecoration(
        color: PaperWeb.gray950,
        border: Border.all(color: PaperWeb.gray800),
        borderRadius: PaperRadii.borderLg,
        boxShadow: PaperElevation.shadowXl,
      ),
      child: ClipRRect(
        borderRadius: PaperRadii.borderLg,
        child: SingleChildScrollView(child: content),
      ),
    );
  }
}

/// The header strip for the loading / error states: back + title only.
class _SimpleBar extends StatelessWidget {
  const _SimpleBar({required this.onBack, required this.title});

  final VoidCallback onBack;
  final String title;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pad = MediaQuery.viewPaddingOf(context);
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
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PaperTypography.sectionTitle(context.paper),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
