import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/paper_tokens.dart';
import '../../../theme/theme_x.dart';
import '../reader_state.dart';

/// `ReaderLoadingState`: title + determinate bar "Downloading {done} of
/// {total}" + Cancel. The bar value is set directly (motion #46).
class ReaderLoadingState extends StatelessWidget {
  const ReaderLoadingState({
    super.key,
    required this.title,
    required this.progress,
    required this.onCancel,
  });

  final String title;

  /// 0..1, null = indeterminate (shown as an empty static track).
  final double? progress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.paper;
    final percent = ((progress ?? 0) * 100).round();
    return ColoredBox(
      color: c.readerBackdrop,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(PaperSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: PaperSpacing.lg),
              SizedBox(
                width: 280,
                child: RepaintBoundary(
                  child: LinearProgressIndicator(
                    // Never indeterminate: an idle reader schedules no frames.
                    value: progress ?? 0,
                    minHeight: 4,
                    borderRadius: PaperRadii.borderFull,
                  ),
                ),
              ),
              const SizedBox(height: PaperSpacing.sm),
              Semantics(
                liveRegion: true,
                child: Text(
                  l10n.readerDownloading('$percent%', '100%'),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: c.textMuted),
                ),
              ),
              const SizedBox(height: PaperSpacing.sm),
              TextButton(onPressed: onCancel, child: Text(l10n.commonCancel)),
            ],
          ),
        ),
      ),
    );
  }
}

/// `ReaderErrorState`: icon, message, primary + Back actions.
class ReaderErrorState extends StatelessWidget {
  const ReaderErrorState({
    super.key,
    required this.kind,
    required this.onRetry,
    required this.onBack,
  });

  final ReaderErrorKind kind;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.paper;
    final (message, primary, primaryAction) = switch (kind) {
      ReaderErrorKind.invalidPdf => (
        l10n.readerRenderFailed,
        l10n.readerRedownload,
        onRetry,
      ),
      ReaderErrorKind.downloadFailed || ReaderErrorKind.unknown => (
        l10n.readerDownloadFailed,
        l10n.commonRetry,
        onRetry,
      ),
      ReaderErrorKind.paperDeleted => (
        l10n.readerPaperDeleted,
        l10n.readerBack,
        onBack,
      ),
      ReaderErrorKind.offlineNotDownloaded => (
        l10n.readerUnavailableOffline,
        l10n.commonRetry,
        onRetry,
      ),
    };
    return ColoredBox(
      color: c.readerBackdrop,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(PaperSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Symbols.error_rounded, size: PaperIconSize.xl, color: c.error),
              const SizedBox(height: PaperSpacing.lg),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    message,
                    key: ValueKey<String>('reader-error-${kind.name}'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
              const SizedBox(height: PaperSpacing.lg),
              Wrap(
                spacing: PaperSpacing.sm,
                alignment: WrapAlignment.center,
                children: <Widget>[
                  FilledButton(onPressed: primaryAction, child: Text(primary)),
                  if (kind != ReaderErrorKind.paperDeleted)
                    OutlinedButton(onPressed: onBack, child: Text(l10n.commonBack)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
