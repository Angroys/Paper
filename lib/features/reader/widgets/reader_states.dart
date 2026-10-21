import 'package:flutter/material.dart';

import '../../../core/immersive.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/paper_tokens.dart';
import '../../../ui/ui.dart';
import '../reader_state.dart';

const TextStyle _sm = TextStyle(
  fontFamily: PaperTypography.sans,
  fontFamilyFallback: PaperTypography.sansFallback,
  fontSize: 14,
  height: 20 / 14,
  leadingDistribution: TextLeadingDistribution.even,
);

/// The pane wrapper for reader states: gray-950, `p-6` + view padding.
class _PaneState extends StatelessWidget {
  const _PaneState({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: PaperWeb.gray950,
    child: SingleChildScrollView(
      padding: SafeViewPadding.resolve(
        context,
        base: const EdgeInsets.all(PaperSpacing.tw6),
        top: false,
      ),
      child: SizedBox(width: double.infinity, child: child),
    ),
  );
}

/// The web `PlaceholderCard` (components.md §17): `rounded-lg border
/// gray-800 bg gray-900 p-6 sm gray-300`, first line `font-medium
/// gray-100`.
class ReaderPlaceholderCard extends StatelessWidget {
  const ReaderPlaceholderCard({
    super.key,
    this.title,
    required this.body,
    this.children = const <Widget>[],
    this.center = false,
    this.padding = const EdgeInsets.all(PaperSpacing.tw6),
  });

  final String? title;
  final String body;
  final List<Widget> children;
  final bool center;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => PaperCard(
    padding: padding,
    child: Column(
      crossAxisAlignment: center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (title != null) ...<Widget>[
          Text(
            title!,
            textAlign: center ? TextAlign.center : TextAlign.start,
            style: _sm.copyWith(
              fontWeight: FontWeight.w500,
              color: PaperWeb.gray100,
            ),
          ),
          const SizedBox(height: PaperSpacing.tw1),
        ],
        Text(
          body,
          textAlign: center ? TextAlign.center : TextAlign.start,
          style: _sm.copyWith(color: PaperWeb.gray400),
        ),
        ...children,
      ],
    ),
  );
}

/// `ReaderLoadingState` (reader.md §10): inside the pane `p-6`, a
/// `PlaceholderCard`-style box (`p-8 text-center sm gray-400`) with the
/// download progress (determinate bar, set directly) and Cancel.
class ReaderLoadingState extends StatelessWidget {
  const ReaderLoadingState({
    super.key,
    required this.title,
    required this.progress,
    required this.onCancel,
  });

  final String title;

  /// 0..1, null = not started (an empty static track).
  final double? progress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final percent = ((progress ?? 0) * 100).round();
    return _PaneState(
      child: ReaderPlaceholderCard(
        center: true,
        padding: const EdgeInsets.all(PaperSpacing.tw8),
        title: title.isEmpty ? null : title,
        body: l10n.commonLoading,
        children: <Widget>[
          const SizedBox(height: PaperSpacing.tw4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: RepaintBoundary(
              // Never indeterminate: an idle reader schedules no frames.
              child: PaperProgressBar(value: progress ?? 0),
            ),
          ),
          const SizedBox(height: PaperSpacing.tw2),
          Semantics(
            liveRegion: true,
            child: Text(
              l10n.readerDownloading('$percent%', '100%'),
              style: _sm
                  .copyWith(fontSize: 12, height: 16 / 12)
                  .copyWith(color: PaperWeb.gray400),
            ),
          ),
          const SizedBox(height: PaperSpacing.tw3),
          PaperButton.secondary(
            label: l10n.commonCancel,
            size: PaperButtonSize.xs,
            focusGap: PaperWeb.gray900,
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

/// `ReaderErrorState` (reader.md §10): download / render failures are an
/// `ErrorBanner` (`p-6`, red) + `mt-3 PaperButton.secondary xs` retry; a
/// deleted paper or one not downloaded while offline is a neutral
/// `PlaceholderCard` + `mt-3 PaperButton.primary sm` action.
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
    final text = Semantics(
      liveRegion: true,
      child: Text(
        message,
        key: ValueKey<String>('reader-error-${kind.name}'),
        style: _sm.copyWith(
          color: _neutral ? PaperWeb.gray300 : PaperWeb.red300,
        ),
      ),
    );
    if (_neutral) {
      return _PaneState(
        child: PaperCard(
          padding: const EdgeInsets.all(PaperSpacing.tw6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              text,
              const SizedBox(height: PaperSpacing.tw3),
              PaperButton.primary(
                label: primary,
                size: PaperButtonSize.sm,
                focusGap: PaperWeb.gray900,
                onPressed: primaryAction,
              ),
            ],
          ),
        ),
      );
    }
    return _PaneState(
      child: Container(
        padding: const EdgeInsets.all(PaperSpacing.tw6),
        decoration: BoxDecoration(
          color: PaperWeb.red950,
          border: Border.all(color: PaperWeb.red900),
          borderRadius: PaperRadii.borderLg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            text,
            const SizedBox(height: PaperSpacing.tw3),
            Wrap(
              spacing: PaperSpacing.tw2,
              runSpacing: PaperSpacing.tw2,
              children: <Widget>[
                PaperButton.secondary(
                  label: primary,
                  size: PaperButtonSize.xs,
                  focusGap: PaperWeb.red950,
                  onPressed: primaryAction,
                ),
                PaperButton.secondary(
                  label: l10n.commonBack,
                  size: PaperButtonSize.xs,
                  focusGap: PaperWeb.red950,
                  onPressed: onBack,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool get _neutral =>
      kind == ReaderErrorKind.paperDeleted ||
      kind == ReaderErrorKind.offlineNotDownloaded;
}
