import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../ai/http_ai_service.dart' show SceneVisualAid;
import '../../core/core_providers.dart';
import '../../core/format.dart';
import '../../core/immersive.dart';
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

/// Explanation tab: the web `ExplanationSidebar` (side-panel.md §3.4): a
/// newest-first `flex-col gap-3 p-4` stack of `ExplanationCard`s, fed by
/// `explanationStackProvider` (which handles `ExplainRequestedEvent`).
/// Offline → notice strip + queued / cached cards; AI unavailable while
/// online → `AiUnavailableState` with Try again.
class ExplanationTab extends ConsumerWidget {
  const ExplanationTab({super.key, required this.panel});

  final ReaderPanelContext panel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final online = ref.watch(isOnlineProvider).value ?? true;
    final stack = ref.watch(explanationStackProvider(panel.paperId));
    final ctrl = ref.read(explanationStackProvider(panel.paperId).notifier);

    if (online && stack.unavailableReason != null) {
      return AiUnavailableState(
        onRetry: () => unawaited(ctrl.retryUnavailable()),
      );
    }

    final entries = stack.entries;
    final Widget body;
    if (entries.isEmpty) {
      body = PanelEmptyState(
        title: l10n.explanationEmptyTitle,
        body: l10n.explanationEmptyBody,
      );
    } else {
      // New cards prepend with no animation (web parity).
      body = ListView.separated(
        key: const PageStorageKey<String>('panel-explanation'),
        padding: SafeViewPadding.resolve(
          context,
          base: const EdgeInsets.all(PaperSpacing.tw4),
          left: false,
          top: false,
        ),
        itemCount: entries.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: PaperSpacing.tw3),
        itemBuilder: (context, i) {
          if (i == entries.length) {
            return Text(l10n.aiPoweredNote, style: _xs);
          }
          final entry = entries[i];
          return ExplanationCard(
            key: ValueKey<String>(entry.id),
            entry: entry,
            online: online,
            panel: panel,
          );
        },
      );
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

/// One `ExplanationCard` (components.md §12.3) in every state: pending /
/// progress, complete, error, offline (queued). Used by the Explanation
/// tab and by the reader's floating explanation popover.
class ExplanationCard extends ConsumerWidget {
  const ExplanationCard({
    super.key,
    required this.entry,
    required this.online,
    required this.panel,
    this.onDismiss,
  });

  final ExplanationEntry entry;
  final bool online;
  final ReaderPanelContext panel;

  /// The `×`; defaults to removing the card from the stack.
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.paper;
    final l10n = AppLocalizations.of(context);
    final ctrl = ref.read(explanationStackProvider(panel.paperId).notifier);
    final dismiss = onDismiss ?? () => ctrl.dismiss(entry.id);
    final isError = entry.status == ExplanationStatus.error;

    // Header: term (cardTitle, break-words) + 24 `×` overhanging by 4.
    Widget header({bool error = false}) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Text(
            entry.term,
            style: PaperTypography.cardTitle(c)
                .copyWith(color: error ? PaperWeb.red200 : PaperWeb.gray100),
          ),
        ),
        const SizedBox(width: PaperSpacing.tw2),
        Transform.translate(
          offset: const Offset(4, -4),
          child: PaperIconButton(
            size: PaperIconButtonSize.s24,
            tone: error
                ? PaperIconButtonTone.error
                : PaperIconButtonTone.neutral,
            tooltip: l10n.commonClose,
            icon: const PaperCloseGlyph(),
            onPressed: dismiss,
          ),
        ),
      ],
    );

    final Widget card;
    switch (entry.status) {
      case ExplanationStatus.pending || ExplanationStatus.unavailable:
        card = PaperCard(
          padding: const EdgeInsets.all(PaperSpacing.tw4),
          child: Semantics(
            key: const ValueKey<String>('explanation-pending'),
            label: l10n.explanationPending(entry.term),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                header(),
                const SizedBox(height: PaperSpacing.tw1),
                const RepaintBoundary(child: PaperProgressBar()),
                const SizedBox(height: PaperSpacing.tw2),
                Text(l10n.explanationPending(entry.term), style: _xs),
              ],
            ),
          ),
        );
      case ExplanationStatus.error:
        card = Container(
          key: const ValueKey<String>('explanation-error'),
          padding: const EdgeInsets.all(PaperSpacing.tw4),
          decoration: BoxDecoration(
            color: PaperWeb.red950,
            border: Border.all(color: PaperWeb.red900),
            borderRadius: PaperRadii.borderLg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              header(error: true),
              const SizedBox(height: PaperSpacing.tw2),
              Text(
                l10n.aiExplainFailed,
                style: PaperTypography.explanationBody(c)
                    .copyWith(color: PaperWeb.red300),
              ),
              if (entry.retryable) ...<Widget>[
                const SizedBox(height: PaperSpacing.tw3),
                PaperButton.secondary(
                  label: l10n.aiRetry,
                  size: PaperButtonSize.xs,
                  focusGap: PaperWeb.red950,
                  onPressed: () => unawaited(ctrl.retry(entry.id)),
                ),
              ],
            ],
          ),
        );
      case ExplanationStatus.queued:
        card = PaperCard(
          key: const ValueKey<String>('explanation-queued'),
          padding: const EdgeInsets.all(PaperSpacing.tw4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              header(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const PaperIcon(
                    PaperIcons.infoSmall,
                    color: PaperWeb.gray400,
                  ),
                  const SizedBox(width: PaperSpacing.tw2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          l10n.aiOfflineCardTitle,
                          style: _xs.copyWith(
                            fontWeight: FontWeight.w500,
                            color: PaperWeb.gray300,
                          ),
                        ),
                        Text(l10n.aiOfflineCardBody, style: _xs),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: PaperSpacing.tw3),
              PaperCheckboxRow(
                value: entry.explainWhenOnline,
                label: l10n.aiExplainWhenOnline,
                onChanged: (v) => ctrl.setExplainWhenOnline(entry.id, v),
              ),
            ],
          ),
        );
      case ExplanationStatus.complete || ExplanationStatus.reexplaining:
        card = PaperCard(
          padding: const EdgeInsets.all(PaperSpacing.tw4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              header(),
              const SizedBox(height: PaperSpacing.tw2),
              _CompleteBody(entry: entry, online: online, panel: panel),
            ],
          ),
        );
    }

    return Semantics(
      container: true,
      liveRegion: entry.status == ExplanationStatus.complete && !isError,
      child: card,
    );
  }
}

class _CompleteBody extends ConsumerWidget {
  const _CompleteBody({
    required this.entry,
    required this.online,
    required this.panel,
  });

  final ExplanationEntry entry;
  final bool online;
  final ReaderPanelContext panel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.paper;
    final l10n = AppLocalizations.of(context);
    final ctrl = ref.read(explanationStackProvider(panel.paperId).notifier);
    final explanation = entry.explanation;
    final reexplaining = entry.status == ExplanationStatus.reexplaining;
    final text = explanation?.explanation ?? '';
    final paragraphs = text.split(RegExp(r'\n\s*\n'));
    final analogy = paragraphs.first.trim();
    final formal = paragraphs.skip(1).join('\n\n').trim();
    final bodyStyle = PaperTypography.explanationBody(c).copyWith(
      // Re-explaining dims the previous text by colour, not an Opacity
      // layer (motion.md §1.7).
      color: PaperWeb.gray300.withValues(alpha: reexplaining ? 0.6 : 1),
    );
    final eyebrow = PaperTypography.eyebrow(c);
    final hasTerm = explanation?.glossaryTermId != null;
    final canUseAi = online && hasTerm;
    final page = entry.pageNumber;
    final showVisual =
        online &&
        entry.visualStatus == VisualStatus.none &&
        explanation != null;

    return Column(
      key: const ValueKey<String>('explanation-complete'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (explanation?.fromCache ?? false) ...<Widget>[
          Text(l10n.aiCachedExplanation, style: _xs),
          const SizedBox(height: PaperSpacing.tw2),
        ],
        if (reexplaining) ...<Widget>[
          const RepaintBoundary(child: PaperProgressBar()),
          const SizedBox(height: PaperSpacing.tw1),
          Text(l10n.explanationReexplaining, style: _xs),
          const SizedBox(height: PaperSpacing.tw2),
        ],
        if (formal.isNotEmpty) ...<Widget>[
          Text(l10n.explanationAnalogyHeading.toUpperCase(), style: eyebrow),
          const SizedBox(height: PaperSpacing.tw1),
        ],
        Text(analogy, style: bodyStyle),
        if (formal.isNotEmpty) ...<Widget>[
          const SizedBox(height: PaperSpacing.tw3),
          Text(l10n.explanationFormalHeading.toUpperCase(), style: eyebrow),
          const SizedBox(height: PaperSpacing.tw1),
          Text(formal, style: bodyStyle),
        ],
        if (entry.reexplainFailed) ...<Widget>[
          const SizedBox(height: PaperSpacing.tw2),
          Text(
            l10n.aiReexplainFailed,
            style: _xs.copyWith(color: PaperWeb.red400),
          ),
        ],
        _VisualAid(entry: entry, online: online, paperId: panel.paperId),
        if (explanation != null) ...<Widget>[
          const SizedBox(height: PaperSpacing.tw3),
          Text(formatWhen(context, explanation.createdAt), style: _xs),
        ],
        if (hasTerm) ...<Widget>[
          const SizedBox(height: PaperSpacing.tw3),
          PaperRating(
            value: entry.rating,
            label: l10n.explanationRateLabel,
            valueText: entry.rating == null
                ? l10n.ratingNotRated
                : l10n.ratingValue(entry.rating!),
            semanticValue: entry.rating == null
                ? l10n.ratingNotRated
                : l10n.explanationRated(entry.rating!),
            tooltip: online ? null : l10n.aiNeedsConnection,
            onRate: canUseAi && !reexplaining
                ? (stars) => unawaited(ctrl.rate(entry.id, stars))
                : null,
          ),
        ],
        const SizedBox(height: PaperSpacing.tw2),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: PaperSpacing.tw1,
          runSpacing: PaperSpacing.tw1,
          children: <Widget>[
            if (hasTerm)
              PaperButton.quiet(
                label: l10n.explanationReexplain,
                tooltip: online ? null : l10n.aiNeedsConnection,
                onPressed: canUseAi && !reexplaining
                    ? () => unawaited(ctrl.reexplain(entry.id))
                    : null,
              ),
            if (page != null)
              PaperButton.quiet(
                label: l10n.explanationJumpToPage(page),
                onPressed: () {
                  final h = entry.highlight;
                  if (h != null) {
                    panel.onJumpToHighlight(h);
                  } else {
                    panel.onJumpToPage(page);
                  }
                },
              ),
            if (showVisual)
              PaperButton.quiet(
                label: l10n.aiVisualShow,
                onPressed: () => unawaited(ctrl.requestVisual(entry.id)),
              ),
          ],
        ),
      ],
    );
  }
}

/// `VisualAidPlayer` stand-in (`mt-3`): the app ships no video player
/// dependency, so a ready video / image opens in the system player or
/// browser; a scene-only result shows a text summary. The text explanation
/// stays the primary content. "Show a visual" is a card action.
class _VisualAid extends ConsumerWidget {
  const _VisualAid({
    required this.entry,
    required this.online,
    required this.paperId,
  });

  final ExplanationEntry entry;
  final bool online;
  final String paperId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    Widget wrap(Widget child) => Padding(
      padding: const EdgeInsets.only(top: PaperSpacing.tw3),
      child: child,
    );
    if ((!online || entry.visualStatus == VisualStatus.offline) &&
        entry.visualStatus != VisualStatus.ready) {
      if (entry.visualStatus == VisualStatus.none) {
        return const SizedBox.shrink();
      }
      return wrap(Text(l10n.aiVisualOffline, style: _xs));
    }
    switch (entry.visualStatus) {
      case VisualStatus.none:
      case VisualStatus.failed:
      case VisualStatus.offline:
        return const SizedBox.shrink();
      case VisualStatus.loading:
        return wrap(
          Row(
            children: <Widget>[
              const Expanded(child: RepaintBoundary(child: PaperProgressBar())),
              const SizedBox(width: PaperSpacing.tw2),
              Text(l10n.commonLoading, style: _xs),
            ],
          ),
        );
      case VisualStatus.ready:
        final visual = entry.visual;
        final url = visual?.videoUrl ?? visual?.imageUrl;
        if (url != null) {
          return wrap(
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: PaperButton.quiet(
                label: '${l10n.aiVisualPlay} ↗',
                onPressed: () => unawaited(
                  launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ),
            ),
          );
        }
        final summary = visual is SceneVisualAid
            ? sceneSummary(visual.sceneJson)
            : null;
        if (summary == null) return const SizedBox.shrink();
        return wrap(
          Container(
            padding: const EdgeInsets.all(PaperSpacing.tw3),
            decoration: BoxDecoration(
              color: PaperWeb.gray950,
              border: Border.all(color: PaperWeb.gray700),
              borderRadius: PaperRadii.borderMd,
            ),
            child: Text(summary, style: _xs.copyWith(height: 1.625)),
          ),
        );
    }
  }
}

/// Human-readable lines from a Manim storyboard `sceneJson` (title /
/// narration / captions), or null when it has none.
String? sceneSummary(Map<String, Object?> scene) {
  final lines = <String>[];
  void take(Object? v) {
    if (v is String && v.trim().isNotEmpty) lines.add(v.trim());
  }

  take(scene['title']);
  take(scene['summary']);
  for (final key in <String>['steps', 'scenes', 'beats']) {
    final list = scene[key];
    if (list is List<Object?>) {
      for (final item in list) {
        if (item is Map<String, Object?>) {
          take(item['narration'] ?? item['caption'] ?? item['text']);
        } else {
          take(item);
        }
      }
    }
  }
  if (lines.isEmpty) return null;
  return lines.take(6).join('\n');
}
