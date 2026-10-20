import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../domain/domain.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/paper_tokens.dart';
import '../../theme/theme_x.dart';
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

typedef ReaderPanelTabBuilder =
    Widget Function(BuildContext context, ReaderPanelContext panel);

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
    final l10n = AppLocalizations.of(context);
    return Semantics(
      container: true,
      label: panelTabLabel(l10n, tab),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PanelTabBar(
            tab: tab,
            onTabChanged: onTabChanged,
            onClose: panel.onClose,
            newResultTabs: newResultTabs,
          ),
          Expanded(
            child: _TabBodies(
              tab: tab,
              builder: (context, t) {
                final slot = slots[t];
                if (slot != null) return slot(context, panel);
                if (t == ReaderPanelTab.highlights) {
                  return HighlightsTab(panel: panel);
                }
                return PanelTabPlaceholder(tab: t);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// `PanelTabBar`: text tabs + close. Selected = weight 600 + 3dp indicator
/// (not colour only); new-result dot 7dp.
class PanelTabBar extends StatelessWidget {
  const PanelTabBar({
    super.key,
    required this.tab,
    required this.onTabChanged,
    required this.onClose,
    this.newResultTabs = const <ReaderPanelTab>{},
  });

  final ReaderPanelTab tab;
  final ValueChanged<ReaderPanelTab> onTabChanged;
  final VoidCallback onClose;
  final Set<ReaderPanelTab> newResultTabs;

  @override
  Widget build(BuildContext context) {
    final c = context.paper;
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.border))),
      child: SizedBox(
        height: 48,
        child: Row(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    for (final t2 in ReaderPanelTab.values)
                      _Tab(
                        key: ValueKey<String>('panel-tab-${t2.name}'),
                        label: panelTabLabel(l10n, t2),
                        selected: t2 == tab,
                        dot: newResultTabs.contains(t2) && t2 != tab,
                        dotLabel: l10n.panelTabNewResult,
                        style: t.labelLarge,
                        onTap: () => onTabChanged(t2),
                      ),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: l10n.panelClose,
              onPressed: onClose,
              icon: const Icon(Symbols.close_rounded, size: PaperIconSize.md),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    super.key,
    required this.label,
    required this.selected,
    required this.dot,
    required this.dotLabel,
    required this.style,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool dot;
  final String dotLabel;
  final TextStyle? style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.paper;
    return Semantics(
      selected: selected,
      button: true,
      label: dot ? '$label, $dotLabel' : label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: PaperSpacing.md),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: <Widget>[
              Text(
                label,
                style: style?.copyWith(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? c.textPrimary : c.textSecondary,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SizedBox(
                  height: 3,
                  child: selected
                      ? DecoratedBox(
                          decoration: BoxDecoration(
                            color: c.primary,
                            borderRadius: PaperRadii.borderFull,
                          ),
                        )
                      : null,
                ),
              ),
              if (dot)
                Positioned(
                  top: 10,
                  right: -8,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: c.primary,
                      shape: BoxShape.circle,
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
              opacity: CurvedAnimation(parent: _fade, curve: PaperMotion.standard),
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
      ReaderPanelTab.glossary => (l10n.glossaryEmptyTitle, l10n.glossaryEmptyBody),
      ReaderPanelTab.explanation => (
        l10n.explanationEmptyTitle,
        l10n.explanationEmptyBody,
      ),
      ReaderPanelTab.highlights => (l10n.panelTabHighlights, ''),
    };
    final c = context.paper;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PaperSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall,
              textAlign: TextAlign.center,
            ),
            if (body.isNotEmpty) ...<Widget>[
              const SizedBox(height: PaperSpacing.sm),
              Text(
                body,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: c.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
