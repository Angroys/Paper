import 'package:flutter/material.dart';

import '../../core/immersive.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/paper_tokens.dart';
import '../../ui/ui.dart';

/// `AiOfflineState` variants (components.md §5). Offline and "AI
/// unavailable while online" are different states and must never be
/// mixed up: the offline strip has no Retry (it recovers by itself), the
/// unavailable block replaces the tab body and has one.
enum AiOfflineVariant { offline, aiUnavailable }

const TextStyle _sm = TextStyle(
  fontFamily: PaperTypography.sans,
  fontFamilyFallback: PaperTypography.sansFallback,
  fontSize: 14,
  height: 20 / 14,
  leadingDistribution: TextLeadingDistribution.even,
);

const TextStyle _smRelaxed = TextStyle(
  fontFamily: PaperTypography.sans,
  fontFamilyFallback: PaperTypography.sansFallback,
  fontSize: 14,
  height: 22.75 / 14,
  leadingDistribution: TextLeadingDistribution.even,
);

/// Offline variant: the web `NoticeStrip` (components.md §17) as the first
/// child of the Glossary / Explanation bodies: full width, accent-soft fill,
/// accent-ink `sm`, `info.svg` 16, `px-4 py-2.5`, bottom border gray-800.
/// Announced once (live region).
class AiOfflineStrip extends StatelessWidget {
  const AiOfflineStrip({super.key});

  static const Key stripKey = Key('aiOfflineState.offline');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      key: stripKey,
      liveRegion: true,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: PaperWeb.accentSoft,
          border: Border(bottom: BorderSide(color: PaperWeb.gray800)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PaperSpacing.tw4,
            vertical: PaperSpacing.tw2_5,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: PaperIcon(PaperIcons.info, color: PaperWeb.accentInk),
              ),
              const SizedBox(width: PaperSpacing.tw3),
              Expanded(
                child: Text(
                  l10n.aiOfflineStrip,
                  style: _sm.copyWith(color: PaperWeb.accentInk),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "AI unavailable while online" variant: replaces the tab body with an
/// `EmptyStateCard` (`p-8`) inside `p-4` (side-panel.md §4):
/// `aiUnavailableTitle` / `aiUnavailableBody` + secondary "Try again".
class AiUnavailableState extends StatelessWidget {
  const AiUnavailableState({super.key, required this.onRetry});

  static const Key blockKey = Key('aiOfflineState.aiUnavailable');

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: SafeViewPadding.resolve(
        context,
        base: const EdgeInsets.all(PaperSpacing.tw4),
        left: false,
        top: false,
      ),
      child: Semantics(
        key: blockKey,
        liveRegion: true,
        child: EmptyStateCard(
          title: l10n.aiUnavailableTitle,
          body: l10n.aiUnavailableBody,
          action: onRetry == null
              ? null
              : PaperButton.secondary(
                  label: l10n.aiRetry,
                  onPressed: onRetry,
                  focusGap: PaperWeb.gray900,
                ),
        ),
      ),
    );
  }
}

/// `EmptyStateCard` (components.md §17): `PaperCard p-8 text-center`,
/// title `sm 600 gray-100`, body `mt-1 sm gray-400`, one action `mt-4`.
/// [compact] = the no-match variant: one `sm gray-400` sentence.
class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({super.key, this.title, required this.body, this.action})
    : compact = false;

  const EmptyStateCard.compact({super.key, required this.body, this.action})
    : title = null,
      compact = true;

  final String? title;
  final String body;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) => PaperCard(
    padding: const EdgeInsets.all(PaperSpacing.tw8),
    child: SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (title != null) ...<Widget>[
            Text(
              title!,
              textAlign: TextAlign.center,
              style: _sm.copyWith(
                fontWeight: FontWeight.w600,
                color: PaperWeb.gray100,
              ),
            ),
            const SizedBox(height: PaperSpacing.tw1),
          ],
          Text(
            body,
            textAlign: TextAlign.center,
            style: _sm.copyWith(color: PaperWeb.gray400),
          ),
          if (action != null) ...<Widget>[
            const SizedBox(height: PaperSpacing.tw4),
            action!,
          ],
        ],
      ),
    ),
  );
}

/// Panel-level empty state: the web `EmptyStateText` (`px-2 py-10
/// text-center`, no card, no icon): optional title `sm 600 gray-100`, body
/// `mt-1 sm-relaxed gray-400`.
class PanelEmptyState extends StatelessWidget {
  const PanelEmptyState({
    super.key,
    this.title,
    required this.body,
    this.action,
    this.scrollable = true,
  });

  final String? title;
  final String body;
  final Widget? action;

  /// False inside an existing scroll view (no own scroll / body padding).
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: PaperSpacing.tw2,
        vertical: PaperSpacing.tw10,
      ),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (title != null) ...<Widget>[
              Text(
                title!,
                textAlign: TextAlign.center,
                style: _sm.copyWith(
                  fontWeight: FontWeight.w600,
                  color: PaperWeb.gray100,
                ),
              ),
              const SizedBox(height: PaperSpacing.tw1),
            ],
            Text(
              body,
              textAlign: TextAlign.center,
              style: _smRelaxed.copyWith(color: PaperWeb.gray400),
            ),
            if (action != null) ...<Widget>[
              const SizedBox(height: PaperSpacing.tw4),
              action!,
            ],
          ],
        ),
      ),
    );
    if (!scrollable) return content;
    return SingleChildScrollView(
      padding: SafeViewPadding.resolve(
        context,
        base: const EdgeInsets.all(PaperSpacing.tw4),
        left: false,
        top: false,
      ),
      child: content,
    );
  }
}

/// `ErrorBanner` (components.md §17): `rounded-lg border red-900 bg red-950
/// p-4 sm red-300`, role alert; optional retry `mt-3 PaperButton.secondary
/// xs` ("Try again").
class InlineError extends StatelessWidget {
  const InlineError({
    super.key,
    required this.message,
    this.title,
    this.onRetry,
    this.retryLabel,
    this.padding = const EdgeInsets.all(PaperSpacing.tw4),
  });

  final String? title;
  final String message;
  final VoidCallback? onRetry;
  final String? retryLabel;

  /// `p-4` (panel / page) or `p-6` (reader-level).
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: PaperWeb.red950,
          border: Border.all(color: PaperWeb.red900),
          borderRadius: PaperRadii.borderLg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (title != null)
              Text(
                title!,
                style: _sm.copyWith(
                  fontWeight: FontWeight.w600,
                  color: PaperWeb.red200,
                ),
              ),
            Text(message, style: _sm.copyWith(color: PaperWeb.red300)),
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: PaperSpacing.tw3),
              PaperButton.secondary(
                label: retryLabel ?? l10n.commonRetry,
                onPressed: onRetry,
                size: PaperButtonSize.xs,
                focusGap: PaperWeb.red950,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Loading tab data (side-panel.md §4): three `PaperCard p-4` skeletons
/// (a 14 × 50% bar, then 12 × 90% / 70%, gap 8), gap 12, pulse.
class PanelSkeletonCards extends StatelessWidget {
  const PanelSkeletonCards({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      label: l10n.a11yLoading,
      child: ListView.separated(
        padding: const EdgeInsets.all(PaperSpacing.tw4),
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(height: PaperSpacing.tw3),
        itemBuilder: (context, _) => const PaperCard(
          padding: EdgeInsets.all(PaperSpacing.tw4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              FractionallySizedBox(widthFactor: 0.5, child: PaperSkeleton()),
              SizedBox(height: PaperSpacing.tw2),
              FractionallySizedBox(
                widthFactor: 0.9,
                child: PaperSkeleton(height: 12),
              ),
              SizedBox(height: PaperSpacing.tw2),
              FractionallySizedBox(
                widthFactor: 0.7,
                child: PaperSkeleton(height: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
