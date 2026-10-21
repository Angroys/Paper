import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/core_providers.dart';
import '../../core/immersive.dart';
import '../../domain/domain.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/paper_tokens.dart';
import '../../theme/theme_x.dart';
import '../../ui/ui.dart';
import 'ai_states.dart';
import 'panel_session.dart';
import 'reader_side_panel.dart';

const TextStyle _xs = TextStyle(
  fontFamily: PaperTypography.sans,
  fontFamilyFallback: PaperTypography.sansFallback,
  fontSize: 12,
  height: 16 / 12,
  leadingDistribution: TextLeadingDistribution.even,
  color: PaperWeb.gray400,
);

/// Glossary tab (screens/glossary.md): the web `GlossarySearch` field
/// (38 tall, no leading icon, `×` clear) and `GlossaryEntryCard`s (`p-5`,
/// gap 16) with the stored explanation, "Explain again" and rating.
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

    final padding = SafeViewPadding.resolve(
      context,
      base: const EdgeInsets.all(PaperSpacing.tw4),
      left: false,
      top: false,
    );
    Widget search({bool enabled = true}) => PaperSearchField(
      fieldKey: const ValueKey<String>('glossary-filter'),
      controller: _filter,
      hintText: l10n.glossaryFilterHint,
      clearTooltip: l10n.a11yClearText,
      enabled: enabled,
      onChanged: (v) => setState(() => _query = v),
    );

    final Widget body;
    if (result == null) {
      // Loading: disabled search @ .5, then three skeleton cards.
      body = ListView(
        padding: padding,
        children: <Widget>[
          Semantics(
            label: l10n.a11yLoading,
            child: ExcludeSemantics(child: search(enabled: false)),
          ),
          for (var i = 0; i < 3; i++) ...<Widget>[
            SizedBox(height: i == 0 ? PaperSpacing.tw6 : PaperSpacing.tw4),
            const PaperCard(
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: FractionallySizedBox(
                      alignment: AlignmentDirectional.centerStart,
                      widthFactor: 0.4,
                      child: PaperSkeleton(),
                    ),
                  ),
                  PaperSkeleton(width: 64, height: 12),
                ],
              ),
            ),
          ],
        ],
      );
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
              title: l10n.glossaryEmptyTitle,
              body: l10n.glossaryEmptyBody,
            );
          } else {
            body = ListView.builder(
              key: const PageStorageKey<String>('panel-glossary'),
              padding: padding,
              itemCount: terms.isEmpty ? 2 : terms.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) return search();
                if (terms.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: PaperSpacing.tw6),
                    child: EmptyStateCard.compact(
                      key: const ValueKey<String>('glossary-no-match'),
                      body: l10n.glossarySearchNoMatch,
                    ),
                  );
                }
                return Padding(
                  padding: EdgeInsets.only(
                    top: i == 1 ? PaperSpacing.tw6 : PaperSpacing.tw4,
                  ),
                  child: GlossaryTermTile(
                    key: ValueKey<String>('glossary-${terms[i - 1].id}'),
                    term: terms[i - 1],
                    online: online,
                    panel: widget.panel,
                  ),
                );
              },
            );
          }
        case AiUnavailable():
          // Offline with nothing cached (the non-offline case returned above
          // when online; offline wins otherwise).
          body = PanelEmptyState(body: l10n.glossaryOfflineUncached);
        case AiFailure(:final retryable):
          body = SingleChildScrollView(
            padding: padding,
            child: InlineError(
              message: l10n.glossaryLoadFailed,
              onRetry: retryable ? retry : null,
            ),
          );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (!online) const AiOfflineStrip(),
        Expanded(child: body),
      ],
    );
  }
}

/// `GlossaryEntryCard` (glossary.md §2): `PaperCard p-5`; header row =
/// chevron 14 (rotates 90° in 150 ms) + term (`sm 600`, accent on hover) and
/// the `MMM d, yyyy` date; tags; the expanded panel appears instantly.
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

class _GlossaryTermTileState extends ConsumerState<GlossaryTermTile> {
  bool _expanded = false;
  bool _busy = false;
  bool _failed = false;

  void _toggle() => setState(() => _expanded = !_expanded);

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
    final term = widget.term;
    final hasExplanation = term.explanation.trim().isNotEmpty;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final date = DateFormat.yMMMd(locale).format(term.createdAt.toLocal());

    final headerRow = PaperPressable(
      onPressed: _toggle,
      semanticLabel: term.term,
      builder: (context, states) {
        final hover =
            states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.pressed);
        return Semantics(
          expanded: _expanded,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: PaperFocusRing(
                  show: states.contains(WidgetState.focused),
                  radius: PaperRadii.borderMd,
                  offset: 0,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: PaperRotatingIcon(
                          PaperIcons.chevronRightSmall,
                          size: 14,
                          color: PaperWeb.gray500,
                          turns: _expanded ? 0.25 : 0,
                          duration: PaperMotion.of(context, PaperMotion.fast),
                        ),
                      ),
                      const SizedBox(width: PaperSpacing.tw1_5),
                      Flexible(
                        child: Text(
                          term.term,
                          style: PaperTypography.glossaryTerm(c).copyWith(
                            color: hover ? PaperWeb.accent : PaperWeb.gray100,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: PaperSpacing.tw2),
              // Baseline-aligned with the 14/20 term: 12/16 sits 2 lower.
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(date, style: _xs),
              ),
            ],
          ),
        );
      },
    );

    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          headerRow,
          if (term.tags.isNotEmpty) ...<Widget>[
            const SizedBox(height: PaperSpacing.tw2),
            Wrap(
              spacing: PaperSpacing.tw1,
              runSpacing: PaperSpacing.tw1,
              children: <Widget>[
                for (final tag in term.tags.take(2))
                  PaperBadge(
                    label: tag,
                    tone: isTypeTag(tag)
                        ? PaperBadgeTone.accent
                        : PaperBadgeTone.neutral,
                  ),
              ],
            ),
          ],
          if (_expanded) ...<Widget>[
            const SizedBox(height: PaperSpacing.tw2),
            if (hasExplanation)
              Text(term.explanation, style: PaperTypography.explanationBody(c))
            else
              Text(
                widget.online
                    ? l10n.glossaryNoCachedExplanation
                    : l10n.glossaryOfflineUncached,
                style: PaperTypography.input(c).copyWith(
                  fontStyle: FontStyle.italic,
                  color: PaperWeb.gray400,
                ),
              ),
            const SizedBox(height: PaperSpacing.tw3),
            PaperRating(
              value: term.rating,
              label: l10n.explanationRateLabel,
              valueText: term.rating == null
                  ? l10n.ratingNotRated
                  : l10n.ratingValue(term.rating!),
              semanticValue: term.rating == null
                  ? l10n.ratingNotRated
                  : l10n.explanationRated(term.rating!),
              tooltip: widget.online ? null : l10n.aiNeedsConnection,
              onRate: widget.online
                  ? (stars) => unawaited(
                      ref
                          .read(glossaryProvider(widget.panel.paperId).notifier)
                          .rate(term, stars),
                    )
                  : null,
            ),
            const SizedBox(height: PaperSpacing.tw3),
            if (widget.online)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: PaperButton.secondary(
                  key: const ValueKey<String>('glossary-explain-again'),
                  label: _busy
                      ? l10n.explanationReexplaining
                      : l10n.glossaryExplainAgain,
                  size: PaperButtonSize.xs,
                  focusGap: PaperWeb.gray900,
                  onPressed: _busy ? null : () => unawaited(_reexplain()),
                ),
              )
            else
              Text(l10n.aiNeedsConnection, style: _xs),
            if (_failed) ...<Widget>[
              const SizedBox(height: PaperSpacing.tw1_5),
              Text(
                l10n.aiReexplainFailed,
                style: _xs.copyWith(color: PaperWeb.red400),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// The web's closed `TagChip.type` vocabulary (`lib/glossary/tags.ts`
/// `TYPE_TAGS`); every other tag is a `TagChip.topic`.
const Set<String> kGlossaryTypeTags = <String>{
  'dataset',
  'benchmark',
  'term',
  'method',
  'metric',
  'model',
  'architecture',
  'task',
  'library',
  'concept',
};

bool isTypeTag(String tag) =>
    kGlossaryTypeTags.contains(tag.trim().toLowerCase());
