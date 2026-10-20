import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/paper_tokens.dart';
import '../../theme/theme_x.dart';

/// `AiOfflineState` variants (components.md §5). Offline and "AI
/// unavailable while online" are different states and must never be
/// mixed up: the offline strip has no Retry (it recovers by itself), the
/// unavailable block replaces the tab body and has one.
enum AiOfflineVariant { offline, aiUnavailable }

/// Offline variant: `OfflineBanner.strip` at the top of the Glossary /
/// Explanation bodies (`aiOfflineStrip`). Announced once (live region).
class AiOfflineStrip extends StatelessWidget {
  const AiOfflineStrip({super.key});

  static const Key stripKey = Key('aiOfflineState.offline');

  @override
  Widget build(BuildContext context) {
    final c = context.paper;
    final l10n = AppLocalizations.of(context);
    return Semantics(
      key: stripKey,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surfaceVariant,
          border: Border(bottom: BorderSide(color: c.border)),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: PaperSpacing.lg,
              vertical: PaperSpacing.sm,
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Symbols.cloud_off_rounded,
                  size: 18,
                  color: c.textSecondary,
                ),
                const SizedBox(width: PaperSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.aiOfflineStrip,
                    style: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(fontSize: 13, color: c.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "AI unavailable while online" variant: replaces the tab body
/// (`aiUnavailableTitle` / `aiUnavailableBody` + Retry).
class AiUnavailableState extends StatelessWidget {
  const AiUnavailableState({super.key, required this.onRetry});

  static const Key blockKey = Key('aiOfflineState.aiUnavailable');

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.paper;
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Padding(
          padding: const EdgeInsets.all(PaperSpacing.lg),
          child: Semantics(
            key: blockKey,
            liveRegion: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Symbols.warning_rounded,
                  size: PaperIconSize.lg,
                  color: c.textSecondary,
                ),
                const SizedBox(height: PaperSpacing.md),
                Text(
                  l10n.aiUnavailableTitle,
                  style: t.titleSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: PaperSpacing.sm),
                Text(
                  l10n.aiUnavailableBody,
                  style: t.bodyMedium?.copyWith(color: c.textSecondary),
                  textAlign: TextAlign.center,
                ),
                if (onRetry != null) ...<Widget>[
                  const SizedBox(height: PaperSpacing.lg),
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Symbols.refresh_rounded, size: 18),
                    label: Text(l10n.aiRetry),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tab empty state: icon 32 + title + body, no illustration.
class PanelEmptyState extends StatelessWidget {
  const PanelEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.paper;
    final t = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(PaperSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: PaperIconSize.xl, color: c.textMuted),
            const SizedBox(height: PaperSpacing.md),
            Text(title, style: t.titleSmall, textAlign: TextAlign.center),
            const SizedBox(height: PaperSpacing.sm),
            Text(
              body,
              style: t.bodyMedium?.copyWith(color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...<Widget>[
              const SizedBox(height: PaperSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// `InlineError`: error block with Try again.
class InlineError extends StatelessWidget {
  const InlineError({
    super.key,
    required this.message,
    this.title,
    this.onRetry,
    this.retryLabel,
  });

  final String? title;
  final String message;
  final VoidCallback? onRetry;
  final String? retryLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.paper;
    final t = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: PaperSpacing.lg,
          vertical: PaperSpacing.md,
        ),
        decoration: BoxDecoration(
          color: c.errorSurface,
          border: Border.all(color: c.errorBorder),
          borderRadius: PaperRadii.borderLg,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Symbols.error_rounded, size: PaperIconSize.md, color: c.error),
            const SizedBox(width: PaperSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (title != null)
                    Text(
                      title!,
                      style: t.labelLarge?.copyWith(color: c.onErrorSurface),
                    ),
                  Text(
                    message,
                    style: t.bodyMedium?.copyWith(color: c.onErrorSurface),
                  ),
                  if (onRetry != null) ...<Widget>[
                    const SizedBox(height: PaperSpacing.sm),
                    OutlinedButton(
                      onPressed: onRetry,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: c.error,
                        side: BorderSide(color: c.errorBorder),
                      ),
                      child: Text(retryLabel ?? l10n.commonRetry),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
