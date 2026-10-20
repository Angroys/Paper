import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/core_providers.dart';
import '../../domain/domain.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/paper_tokens.dart';
import '../../theme/theme_x.dart';
import 'ai_states.dart';
import 'explanation_tab.dart' show StarRating;
import 'panel_session.dart';
import 'reader_side_panel.dart';

/// Glossary tab: the open paper's terms (`aiService.glossary`), filter,
/// expandable tiles with the stored explanation, "Explain again" and
/// rating.
class GlossaryTab extends ConsumerStatefulWidget {
  const GlossaryTab({super.key, required this.panel});

  final ReaderPanelContext panel;

  @override
  ConsumerState<GlossaryTab> createState() => _GlossaryTabState();
}

class _GlossaryTabState extends ConsumerState<GlossaryTab> {
  final TextEditingController _filter = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final paperId = widget.panel.paperId;
    final online = ref.watch(isOnlineProvider).value ?? true;
    final async = ref.watch(glossaryProvider(paperId));
    final result = async.value;

    void retry() => ref.invalidate(glossaryProvider(paperId));

    if (online &&
        result is AiUnavailable<List<GlossaryTerm>> &&
        result.reason != AiUnavailableReason.offline) {
      return AiUnavailableState(onRetry: retry);
    }

    final Widget body;
    if (result == null) {
      body = const _SkeletonRows();
    } else {
      switch (result) {
        case AiSuccess(:final value):
          final q = _query.trim().toLowerCase();
          final terms = q.isEmpty
              ? value
              : value
                    .where(
                      (t) =>
                          t.term.toLowerCase().contains(q) ||
                          t.explanation.toLowerCase().contains(q),
                    )
                    .toList();
          if (value.isEmpty) {
            body = PanelEmptyState(
              icon: Symbols.menu_book_rounded,
              title: l10n.glossaryEmptyTitle,
              body: l10n.glossaryEmptyBody,
            );
          } else {
            body = ListView.separated(
              key: const PageStorageKey<String>('panel-glossary'),
              padding: const EdgeInsets.symmetric(
                horizontal: PaperSpacing.panePadding,
                vertical: PaperSpacing.sm,
              ),
              itemCount: terms.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: PaperSpacing.xs),
              itemBuilder: (context, i) => GlossaryTermTile(
                key: ValueKey<String>('glossary-${terms[i].id}'),
                term: terms[i],
                online: online,
                panel: widget.panel,
              ),
            );
          }
        case AiUnavailable():
          // Offline with nothing cached (the non-offline case returned above
          // when online; offline wins otherwise).
          body = PanelEmptyState(
            icon: Symbols.menu_book_rounded,
            title: l10n.glossaryEmptyTitle,
            body: l10n.glossaryOfflineUncached,
          );
        case AiFailure(:final retryable):
          body = Padding(
            padding: const EdgeInsets.all(PaperSpacing.panePadding),
            child: Align(
              alignment: Alignment.topCenter,
              child: InlineError(
                message: l10n.glossaryLoadFailed,
                onRetry: retryable ? retry : null,
              ),
            ),
          );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (!online) const AiOfflineStrip(),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            PaperSpacing.panePadding,
            PaperSpacing.md,
            PaperSpacing.panePadding,
            PaperSpacing.xs,
          ),
          child: TextField(
            key: const ValueKey<String>('glossary-filter'),
            controller: _filter,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              isDense: true,
              hintText: l10n.glossaryFilterHint,
              prefixIcon: const Icon(Symbols.search_rounded, size: 20),
            ),
          ),
        ),
        Expanded(child: body),
      ],
    );
  }
}

/// Static skeleton rows (motion #42: no shimmer).
class _SkeletonRows extends StatelessWidget {
  const _SkeletonRows();

  @override
  Widget build(BuildContext context) {
    final c = context.paper;
    final l10n = AppLocalizations.of(context);
    return Semantics(
      label: l10n.a11yLoading,
      child: ListView(
        padding: const EdgeInsets.all(PaperSpacing.panePadding),
        children: <Widget>[
          for (var i = 0; i < 6; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: PaperSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  FractionallySizedBox(
                    widthFactor: 0.6,
                    child: Container(height: 14, color: c.surfaceVariant),
                  ),
                  const SizedBox(height: PaperSpacing.xs),
                  FractionallySizedBox(
                    widthFactor: 0.9,
                    child: Container(height: 10, color: c.surfaceVariant),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// `GlossaryTermTile`: body snaps open (no height animation), fades in;
/// the chevron rotates (motion #45).
class GlossaryTermTile extends ConsumerStatefulWidget {
  const GlossaryTermTile({
    super.key,
    required this.term,
    required this.online,
    required this.panel,
  });

  final GlossaryTerm term;
  final bool online;
  final ReaderPanelContext panel;

  @override
  ConsumerState<GlossaryTermTile> createState() => _GlossaryTermTileState();
}

class _GlossaryTermTileState extends ConsumerState<GlossaryTermTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  bool _expanded = false;
  bool _busy = false;
  bool _failed = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _c.duration = PaperMotion.of(context, PaperMotion.fast);
    if (_expanded) {
      unawaited(_c.forward(from: 0));
    } else {
      _c.value = 0;
    }
  }

  Future<void> _reexplain() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    final result = await ref
        .read(glossaryProvider(widget.panel.paperId).notifier)
        .reexplain(widget.term);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _failed = result is! AiSuccess<Explanation>;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.paper;
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final term = widget.term;
    final summary = term.explanation.split('\n').first;
    final hasExplanation = term.explanation.trim().isNotEmpty;

    return Material(
      color: _expanded ? c.surfaceVariant : Colors.transparent,
      borderRadius: PaperRadii.borderMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          InkWell(
            borderRadius: PaperRadii.borderMd,
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: PaperSpacing.lg,
                vertical: PaperSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          term.term,
                          style: PaperTypography.glossaryTerm(c),
                        ),
                      ),
                      RotationTransition(
                        turns: Tween<double>(begin: 0, end: 0.25).animate(
                          CurvedAnimation(
                            parent: _c,
                            curve: PaperMotion.standard,
                          ),
                        ),
                        child: Icon(
                          Symbols.chevron_right_rounded,
                          size: 20,
                          color: c.textMuted,
                        ),
                      ),
                    ],
                  ),
                  if (!_expanded) ...<Widget>[
                    const SizedBox(height: PaperSpacing.xs),
                    Wrap(
                      spacing: PaperSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        for (final tag in term.tags.take(2)) _TagChip(tag),
                        Text(
                          hasExplanation
                              ? summary
                              : l10n.glossaryNoCachedExplanation,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodySmall?.copyWith(color: c.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_expanded)
            FadeTransition(
              opacity: CurvedAnimation(
                parent: _c,
                curve: PaperMotion.decelerate,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  PaperSpacing.lg,
                  0,
                  PaperSpacing.lg,
                  PaperSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (hasExplanation)
                      Text(
                        term.explanation,
                        style: PaperTypography.explanationBodyCompact(c),
                      )
                    else
                      Row(
                        children: <Widget>[
                          if (!widget.online) ...<Widget>[
                            Icon(
                              Symbols.cloud_off_rounded,
                              size: 16,
                              color: c.textMuted,
                            ),
                            const SizedBox(width: PaperSpacing.xs),
                          ],
                          Expanded(
                            child: Text(
                              widget.online
                                  ? l10n.glossaryNoCachedExplanation
                                  : l10n.glossaryOfflineUncached,
                              style: t.bodySmall?.copyWith(color: c.textMuted),
                            ),
                          ),
                        ],
                      ),
                    if (_failed) ...<Widget>[
                      const SizedBox(height: PaperSpacing.xs),
                      Text(
                        l10n.aiReexplainFailed,
                        style: t.bodySmall?.copyWith(color: c.error),
                      ),
                    ],
                    const SizedBox(height: PaperSpacing.sm),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: PaperSpacing.sm,
                      children: <Widget>[
                        StarRating(
                          rating: term.rating,
                          enabled: widget.online,
                          onRate: (stars) => unawaited(
                            ref
                                .read(
                                  glossaryProvider(widget.panel.paperId)
                                      .notifier,
                                )
                                .rate(term, stars),
                          ),
                        ),
                        Tooltip(
                          message: widget.online ? '' : l10n.aiNeedsConnection,
                          child: TextButton.icon(
                            onPressed: widget.online && !_busy
                                ? () => unawaited(_reexplain())
                                : null,
                            icon: const Icon(Symbols.refresh_rounded, size: 18),
                            label: Text(
                              _busy
                                  ? l10n.explanationReexplaining
                                  : l10n.glossaryExplainAgain,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.paper;
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: PaperSpacing.sm),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: PaperRadii.borderFull,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: c.textSecondary,
        ),
      ),
    );
  }
}
