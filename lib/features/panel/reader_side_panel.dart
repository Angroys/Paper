import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/auth_providers.dart';
import '../../core/build_flags.dart';
import '../../domain/domain.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/paper_tokens.dart';
import '../../ui/ui.dart';
import '../auth/sign_in_prompt.dart';
import 'ai_states.dart';
import 'highlights_tab.dart';
import 'panel_tab.dart';

export 'panel_tab.dart';

/// What a tab body gets from the reader. Tab bodies never talk to the PDF
/// directly; they call these.
@immutable
class ReaderPanelContext {
  const ReaderPanelContext({
    required this.paperId,
    required this.currentPage,
    required this.onJumpToHighlight,
    required this.onJumpToPage,
    required this.onClose,
  });

  final String paperId;

  /// 1-based page at the viewport centre (e.g. "New note on page 12").
  final int currentPage;

  /// Scrolls the PDF to [Highlight], ring-flashes it and shows "Back to page
  /// N" (motion #31/#32).
  final ValueChanged<Highlight> onJumpToHighlight;
  final ValueChanged<int> onJumpToPage;
  final VoidCallback onClose;
}

typedef ReaderPanelTabBuilder = Widget Function(
  BuildContext context,
  ReaderPanelContext panel,
);

/// Tab-body slots. SCREENS AGENT: provide the Notes, Glossary and
/// Explanation bodies by overriding [readerPanelSlotsProvider] (or by
/// changing its default below). A null slot shows a placeholder. The
/// Highlights tab is built in ([HighlightsTab]) unless [highlights] is set.
///
/// Explain / Note requests from the reader arrive on
/// `ReaderController.events` as `ExplainRequestedEvent` /
/// `NoteRequestedEvent` (the highlight is already saved and the panel is
/// already open on the matching tab).
@immutable
class ReaderPanelSlots {
  const ReaderPanelSlots({
    this.notes,
    this.glossary,
    this.explanation,
    this.highlights,
  });

  final ReaderPanelTabBuilder? notes;
  final ReaderPanelTabBuilder? glossary;
  final ReaderPanelTabBuilder? explanation;
  final ReaderPanelTabBuilder? highlights;

  ReaderPanelTabBuilder? operator [](ReaderPanelTab tab) => switch (tab) {
    ReaderPanelTab.notes => notes,
    ReaderPanelTab.glossary => glossary,
    ReaderPanelTab.explanation => explanation,
    ReaderPanelTab.highlights => highlights,
  };
}

/// Override in the app (screens agent) or in tests.
final readerPanelSlotsProvider = Provider<ReaderPanelSlots>(
  (ref) => const ReaderPanelSlots(),
);

/// Tabs shown in the tab bar, in order. Offline-only builds drop the AI
/// tabs (Glossary, Explanation): only Notes and Highlights remain.
final readerPanelTabsProvider = Provider<List<ReaderPanelTab>>(
  (ref) => ref.watch(offlineOnlyProvider)
      ? const <ReaderPanelTab>[ReaderPanelTab.notes, ReaderPanelTab.highlights]
      : ReaderPanelTab.values,
);

/// Localised tab label.
String panelTabLabel(AppLocalizations l10n, ReaderPanelTab tab) =>
    switch (tab) {
      ReaderPanelTab.notes => l10n.panelTabNotes,
      ReaderPanelTab.glossary => l10n.panelTabGlossary,
      ReaderPanelTab.explanation => l10n.panelTabExplanation,
      ReaderPanelTab.highlights => l10n.panelTabHighlights,
    };

/// `ReaderSidePanel`: `PanelTabBar` + tab bodies (reader-side-panel.md).
/// The container (split / overlay / sheet) is `ReaderSplitView`; this is
/// the content, placed in its own RepaintBoundary (B6) by the container.
class ReaderSidePanel extends ConsumerWidget {
  const ReaderSidePanel({
    super.key,
    required this.panel,
    required this.tab,
    required this.onTabChanged,
    this.newResultTabs = const <ReaderPanelTab>{},
  });

  final ReaderPanelContext panel;
  final ReaderPanelTab tab;
  final ValueChanged<ReaderPanelTab> onTabChanged;

  /// Tabs showing the "new result" dot (`panelTabNewResult`).
  final Set<ReaderPanelTab> newResultTabs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slots = ref.watch(readerPanelSlotsProvider);
    // Guests see the AI tabs with a "Sign in to use …" prompt (sign-in is
    // optional; the tabs stay visible).
    final guest = ref.watch(isGuestProvider);
    final l10n = AppLocalizations.of(context);
    return Semantics(
      container: true,
      label: panelTabLabel(l10n, tab),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PanelTabBar(
            tabs: ref.watch(readerPanelTabsProvider),
            tab: tab,
            onTabChanged: onTabChanged,
            onClose: panel.onClose,
            newResultTabs: newResultTabs,
          ),
          Expanded(
            // IME: only the panel body lifts (side-panel.md §5); the reader
            // Scaffold never resizes.
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: _TabBodies(
                tab: tab,
                builder: (context, t) {
                  if (guest && t == ReaderPanelTab.glossary) {
                    return const SignInPrompt(feature: GuestFeature.glossary);
                  }
                  if (guest && t == ReaderPanelTab.explanation) {
                    return const SignInPrompt(
                      feature: GuestFeature.explanation,
                    );
                  }
                  final slot = slots[t];
                  if (slot != null) return slot(context, panel);
                  if (t == ReaderPanelTab.highlights) {
                    return HighlightsTab(panel: panel);
                  }
                  return PanelTabPlaceholder(tab: t);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `PanelTabBar`: the web panel header (side-panel.md §2, components
/// §12.1): `px-3 py-2`, 40 + 1px gray-800 bottom border, gray-950 fill.
/// Left: `PaperTabs` (24 tall ghost tabs, selected accent-soft /
/// accent-ink, 6px accent "new result" dot). Right: the 32 hide button
/// (`panel-hide.svg` 20, `-m-1`), 8 after the tabs.
class PanelTabBar extends StatelessWidget {
  const PanelTabBar({
    super.key,
    required this.tab,
    required this.onTabChanged,
    required this.onClose,
    this.newResultTabs = const <ReaderPanelTab>{},
    this.tabs = ReaderPanelTab.values,
  });

  /// Header height without its 1px bottom border.
  static const double height = 40;

  final ReaderPanelTab tab;
  final ValueChanged<ReaderPanelTab> onTabChanged;
  final VoidCallback onClose;
  final Set<ReaderPanelTab> newResultTabs;

  /// Tabs to show, in order (`readerPanelTabsProvider`).
  final List<ReaderPanelTab> tabs;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final right = MediaQuery.viewPaddingOf(context).right;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: PaperWeb.gray950,
        border: Border(bottom: BorderSide(color: PaperWeb.gray800)),
      ),
      child: Padding(
        // 40 + the 1px bottom border = 41.
        padding: EdgeInsets.only(
          left: PaperSpacing.tw3,
          right: PaperSpacing.tw3 + right,
          bottom: 1,
        ),
        child: SizedBox(
          height: height,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: PaperTabs(
                    tabs: <PaperTab>[
                      for (final t in tabs)
                        PaperTab(
                          key: ValueKey<String>('panel-tab-${t.name}'),
                          label: panelTabLabel(l10n, t),
                          showDot: newResultTabs.contains(t) && t != tab,
                        ),
                    ],
                    selectedIndex: tabs.indexOf(tab),
                    onSelected: (i) => onTabChanged(tabs[i]),
                    dotSemanticLabel: l10n.panelTabNewResult,
                  ),
                ),
              ),
              const SizedBox(width: PaperSpacing.tw2),
              // `-m-1`: a 32 box laid out in 24.
              SizedBox(
                width: 24,
                height: 24,
                child: OverflowBox(
                  maxWidth: 32,
                  maxHeight: 32,
                  child: PaperIconButton(
                    key: const ValueKey<String>('panel-hide'),
                    tooltip: l10n.panelClose,
                    icon: const PaperIcon(PaperIcons.panelHide, size: 20),
                    onPressed: onClose,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Keeps every visited tab alive (scroll position per tab, IndexedStack) and
/// fades the incoming body in (motion #7, `fast`; reduced motion keeps the
/// fade capped at `fast`).
class _TabBodies extends StatefulWidget {
  const _TabBodies({required this.tab, required this.builder});

  final ReaderPanelTab tab;
  final Widget Function(BuildContext context, ReaderPanelTab tab) builder;

  @override
  State<_TabBodies> createState() => _TabBodiesState();
}

class _TabBodiesState extends State<_TabBodies>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    value: 1,
  );
  late final Set<ReaderPanelTab> _visited = <ReaderPanelTab>{widget.tab};

  @override
  void didUpdateWidget(_TabBodies old) {
    super.didUpdateWidget(old);
    if (old.tab != widget.tab) {
      _visited.add(widget.tab);
      _fade
        ..duration = PaperMotion.fade(context, PaperMotion.fast)
        ..forward(from: 0);
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.tab.index,
      sizing: StackFit.expand,
      children: <Widget>[
        for (final t in ReaderPanelTab.values)
          if (!_visited.contains(t))
            const SizedBox.shrink()
          else if (t == widget.tab)
            FadeTransition(
              key: ValueKey<ReaderPanelTab>(t),
              opacity: CurvedAnimation(
                parent: _fade,
                curve: PaperMotion.standard,
              ),
              child: widget.builder(context, t),
            )
          else
            KeyedSubtree(
              key: ValueKey<ReaderPanelTab>(t),
              child: widget.builder(context, t),
            ),
      ],
    );
  }
}

/// PLACEHOLDER (screens agent): replaced by the Notes / Glossary /
/// Explanation bodies via [readerPanelSlotsProvider].
class PanelTabPlaceholder extends StatelessWidget {
  const PanelTabPlaceholder({super.key, required this.tab});

  final ReaderPanelTab tab;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (title, body) = switch (tab) {
      ReaderPanelTab.notes => (l10n.notesEmptyTitle, l10n.notesEmptyBody),
      ReaderPanelTab.glossary => (
        l10n.glossaryEmptyTitle,
        l10n.glossaryEmptyBody,
      ),
      ReaderPanelTab.explanation => (
        l10n.explanationEmptyTitle,
        l10n.explanationEmptyBody,
      ),
      ReaderPanelTab.highlights => (null, l10n.readerFirstHighlightHint),
    };
    return PanelEmptyState(title: title, body: body);
  }
}
