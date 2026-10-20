import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../ai/http_ai_service.dart' show SceneVisualAid;
import '../../core/core_providers.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/paper_tokens.dart';
import '../../theme/theme_x.dart';
import 'ai_states.dart';
import 'panel_session.dart';
import 'reader_side_panel.dart';

/// Explanation tab: `ExplanationStack` (newest first) of
/// `ExplanationCard`s, fed by `explanationStackProvider` (which handles
/// `ExplainRequestedEvent`). Offline → strip + queued / cached cards;
/// AI unavailable while online → `AiUnavailableState` with Retry.
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
        icon: Symbols.auto_awesome_rounded,
        title: l10n.explanationEmptyTitle,
        body: l10n.explanationEmptyBody,
      );
    } else {
      body = ListView.separated(
        key: const PageStorageKey<String>('panel-explanation'),
        padding: const EdgeInsets.all(PaperSpacing.panePadding),
        itemCount: entries.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: PaperSpacing.md),
        itemBuilder: (context, i) {
          if (i == entries.length) {
            return Text(
              l10n.aiPoweredNote,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: context.paper.textMuted),
            );
          }
          final entry = entries[i];
          return _FadeIn(
            key: ValueKey<String>(entry.id),
            child: ExplanationCard(entry: entry, online: online, panel: panel),
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

/// New cards fade in at the top; cards below jump (motion #43).
class _FadeIn extends StatefulWidget {
  const _FadeIn({super.key, required this.child});

  final Widget child;

  @override
  State<_FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<_FadeIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.status == AnimationStatus.dismissed) {
      _c.duration = PaperMotion.fade(context, PaperMotion.base);
      unawaited(_c.forward());
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: CurvedAnimation(parent: _c, curve: PaperMotion.decelerate),
    child: widget.child,
  );
}

/// One card of the stack. States per components.md §5.
class ExplanationCard extends ConsumerWidget {
  const ExplanationCard({
    super.key,
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
    final t = Theme.of(context).textTheme;
    final ctrl = ref.read(explanationStackProvider(panel.paperId).notifier);

    final isError = entry.status == ExplanationStatus.error;
    final isQueued = entry.status == ExplanationStatus.queued;
    final decoration = BoxDecoration(
      color: isError ? c.errorSurface : c.surface,
      border: Border.all(
        color: isError
            ? c.errorBorder
            : (isQueued ? c.outlineVariant : c.border),
      ),
      borderRadius: PaperRadii.borderLg,
    );

    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Text(
            entry.term,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: t.titleSmall?.copyWith(
              color: isError ? c.onErrorSurface : null,
            ),
          ),
        ),
        if (entry.pageNumber case final page?)
          Semantics(
            button: true,
            label: l10n.explanationJumpToPage(page),
            excludeSemantics: true,
            child: InkWell(
              borderRadius: PaperRadii.borderSm,
              onTap: () {
                final h = entry.highlight;
                if (h != null) {
                  panel.onJumpToHighlight(h);
                } else {
                  panel.onJumpToPage(page);
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(PaperSpacing.xs),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'p. $page',
                      style: PaperTypography.pageIndicator(c)
                          .copyWith(color: c.primary),
                    ),
                    const SizedBox(width: PaperSpacing.xs),
                    Icon(
                      Symbols.open_in_new_rounded,
                      size: 16,
                      color: c.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );

    final Widget content = switch (entry.status) {
      ExplanationStatus.pending || ExplanationStatus.unavailable => Semantics(
        key: const ValueKey<String>('explanation-pending'),
        label: l10n.explanationPending(entry.term),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const _ProgressBar(),
            const SizedBox(height: PaperSpacing.sm),
            Text(
              l10n.explanationPending(entry.term),
              style: t.bodySmall?.copyWith(color: c.textMuted),
            ),
          ],
        ),
      ),
      ExplanationStatus.error => Column(
        key: const ValueKey<String>('explanation-error'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Symbols.error_rounded, size: 18, color: c.error),
              const SizedBox(width: PaperSpacing.sm),
              Expanded(
                child: Text(
                  l10n.aiExplainFailed,
                  style: t.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: c.onErrorSurface,
                  ),
                ),
              ),
            ],
          ),
          if (entry.retryable) ...<Widget>[
            const SizedBox(height: PaperSpacing.sm),
            OutlinedButton(
              onPressed: () => unawaited(ctrl.retry(entry.id)),
              style: OutlinedButton.styleFrom(
                foregroundColor: c.error,
                side: BorderSide(color: c.errorBorder),
              ),
              child: Text(l10n.aiRetry),
            ),
          ],
        ],
      ),
      ExplanationStatus.queued => Column(
        key: const ValueKey<String>('explanation-queued'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Symbols.cloud_off_rounded, size: 18, color: c.textSecondary),
              const SizedBox(width: PaperSpacing.sm),
              Expanded(
                child: Text(l10n.aiOfflineCardTitle, style: t.labelLarge),
              ),
            ],
          ),
          const SizedBox(height: PaperSpacing.xs),
          Text(
            l10n.aiOfflineCardBody,
            style: t.bodyMedium?.copyWith(color: c.textSecondary),
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(l10n.aiExplainWhenOnline, style: t.bodyMedium),
              ),
              Switch(
                value: entry.explainWhenOnline,
                onChanged: (v) => ctrl.setExplainWhenOnline(entry.id, v),
              ),
            ],
          ),
        ],
      ),
      ExplanationStatus.complete || ExplanationStatus.reexplaining =>
        _CompleteBody(entry: entry, online: online, paperId: panel.paperId),
    };

    return Semantics(
      container: true,
      liveRegion: entry.status == ExplanationStatus.complete,
      child: DecoratedBox(
        decoration: decoration,
        child: Padding(
          padding: const EdgeInsets.all(PaperSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              header,
              const SizedBox(height: PaperSpacing.sm),
              AnimatedSwitcher(
                duration: PaperMotion.fade(context, PaperMotion.base),
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.topLeft,
                  children: <Widget>[...previous, ?current],
                ),
                child: content,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 6dp indeterminate bar (motion #44), static under reduced motion. Own
/// RepaintBoundary so the loop never repaints the panel.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar();

  @override
  Widget build(BuildContext context) {
    final c = context.paper;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: PaperRadii.borderFull,
        child: LinearProgressIndicator(
          minHeight: 6,
          value: reduced ? 1 / 3 : null,
          color: c.primary,
          backgroundColor: c.outlineVariant,
        ),
      ),
    );
  }
}

class _CompleteBody extends ConsumerWidget {
  const _CompleteBody({
    required this.entry,
    required this.online,
    required this.paperId,
  });

  final ExplanationEntry entry;
  final bool online;
  final String paperId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.paper;
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final ctrl = ref.read(explanationStackProvider(paperId).notifier);
    final explanation = entry.explanation;
    final reexplaining = entry.status == ExplanationStatus.reexplaining;
    final text = explanation?.explanation ?? '';
    final paragraphs = text.split(RegExp(r'\n\s*\n'));
    final analogy = paragraphs.first.trim();
    final formal = paragraphs.skip(1).join('\n\n').trim();
    final bodyStyle = PaperTypography.explanationBody(c).copyWith(
      // Re-explaining dims the previous text by colour, not an Opacity
      // layer (motion.md §1.7).
      color: c.textSecondary.withValues(alpha: reexplaining ? 0.6 : 1),
    );
    final overline = t.labelSmall?.copyWith(
      color: c.textMuted,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.44,
    );
    final canUseAi = online && explanation?.glossaryTermId != null;

    return Column(
      key: const ValueKey<String>('explanation-complete'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (reexplaining) ...<Widget>[
          const _ProgressBar(),
          const SizedBox(height: PaperSpacing.xs),
          Text(
            l10n.explanationReexplaining,
            style: t.bodySmall?.copyWith(color: c.textMuted),
          ),
          const SizedBox(height: PaperSpacing.sm),
        ],
        if (formal.isNotEmpty) ...<Widget>[
          Text(l10n.explanationAnalogyHeading.toUpperCase(), style: overline),
          const SizedBox(height: PaperSpacing.xs),
        ],
        Text(analogy, style: bodyStyle),
        if (formal.isNotEmpty) ...<Widget>[
          const SizedBox(height: PaperSpacing.md),
          Text(l10n.explanationFormalHeading.toUpperCase(), style: overline),
          const SizedBox(height: PaperSpacing.xs),
          Text(formal, style: bodyStyle),
        ],
        if (explanation?.fromCache ?? false) ...<Widget>[
          const SizedBox(height: PaperSpacing.sm),
          Text(
            l10n.aiCachedExplanation,
            style: t.bodySmall?.copyWith(color: c.textMuted),
          ),
        ],
        if (entry.reexplainFailed) ...<Widget>[
          const SizedBox(height: PaperSpacing.sm),
          Text(
            l10n.aiReexplainFailed,
            style: t.bodySmall?.copyWith(color: c.error),
          ),
        ],
        const SizedBox(height: PaperSpacing.md),
        _VisualAid(entry: entry, online: online, paperId: paperId),
        const SizedBox(height: PaperSpacing.sm),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: PaperSpacing.sm,
          children: <Widget>[
            if (explanation?.glossaryTermId != null)
              StarRating(
                rating: entry.rating,
                enabled: canUseAi && !reexplaining,
                onRate: (stars) => unawaited(ctrl.rate(entry.id, stars)),
              ),
            if (explanation?.glossaryTermId != null)
              Tooltip(
                message: online ? '' : l10n.aiNeedsConnection,
                child: TextButton.icon(
                  onPressed: canUseAi && !reexplaining
                      ? () => unawaited(ctrl.reexplain(entry.id))
                      : null,
                  icon: const Icon(Symbols.refresh_rounded, size: 18),
                  label: Text(l10n.explanationReexplain),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// `VisualAidPlayer` stand-in: the app ships no video player dependency,
/// so a ready video / image opens in the system player or browser; a
/// scene-only result shows a text summary. The text explanation stays the
/// primary content.
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
    final c = context.paper;
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final ctrl = ref.read(explanationStackProvider(paperId).notifier);
    if (!online || entry.visualStatus == VisualStatus.offline) {
      if (entry.visualStatus == VisualStatus.ready) {
        // Already fetched: still link it.
      } else {
        return Text(
          l10n.aiVisualOffline,
          style: t.bodySmall?.copyWith(color: c.textMuted),
        );
      }
    }
    switch (entry.visualStatus) {
      case VisualStatus.none:
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: () => unawaited(ctrl.requestVisual(entry.id)),
            icon: const Icon(Symbols.movie_rounded, size: 18),
            label: Text(l10n.aiVisualShow),
          ),
        );
      case VisualStatus.loading:
        return Row(
          children: <Widget>[
            const Expanded(child: _ProgressBar()),
            const SizedBox(width: PaperSpacing.sm),
            Text(l10n.commonLoading, style: t.bodySmall),
          ],
        );
      case VisualStatus.failed:
      case VisualStatus.offline:
        return const SizedBox.shrink();
      case VisualStatus.ready:
        final visual = entry.visual;
        final url = visual?.videoUrl ?? visual?.imageUrl;
        if (url != null) {
          return Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              onPressed: () => unawaited(
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
              ),
              icon: const Icon(Symbols.play_arrow_rounded, size: 18),
              label: Text(l10n.aiVisualPlay),
            ),
          );
        }
        final summary = visual is SceneVisualAid
            ? sceneSummary(visual.sceneJson)
            : null;
        if (summary == null) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.all(PaperSpacing.md),
          decoration: BoxDecoration(
            color: c.surfaceVariant,
            borderRadius: PaperRadii.borderMd,
          ),
          child: Text(summary, style: t.bodySmall),
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

/// 1–5 stars (single tap, changeable). Disabled offline with
/// `aiNeedsConnection`.
class StarRating extends StatelessWidget {
  const StarRating({
    super.key,
    required this.rating,
    required this.enabled,
    required this.onRate,
  });

  final int? rating;
  final bool enabled;
  final ValueChanged<int> onRate;

  @override
  Widget build(BuildContext context) {
    final c = context.paper;
    final l10n = AppLocalizations.of(context);
    final current = rating ?? 0;
    return Semantics(
      label: l10n.explanationRateLabel,
      value: current > 0 ? l10n.explanationRated(current) : null,
      child: Tooltip(
        message: enabled ? l10n.explanationRateLabel : l10n.aiNeedsConnection,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (var i = 1; i <= 5; i++)
              InkResponse(
                key: ValueKey<String>('star-$i'),
                radius: 16,
                onTap: enabled ? () => onRate(i) : null,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Symbols.star_rounded,
                    fill: i <= current ? 1 : 0,
                    size: 22,
                    color: i <= current
                        ? PaperHighlightColor.yellow.wash
                        : c.textMuted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
