import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/format.dart';
import '../../domain/domain.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/paper_tokens.dart';
import '../../theme/theme_x.dart';
import 'library_controller.dart';

/// `DownloadStateBadge` states (library.md).
enum PaperDownloadBadge {
  cloudOnly,
  downloading,
  availableOffline,
  failed,
  pendingUpload,
  unavailableOffline,
}

PaperDownloadBadge downloadBadgeFor(
  Paper paper, {
  required bool online,
  double? progress,
  bool failed = false,
}) {
  if (progress != null) return PaperDownloadBadge.downloading;
  if (failed) return PaperDownloadBadge.failed;
  if (paper.syncState == SyncState.pendingCreate) {
    return PaperDownloadBadge.pendingUpload;
  }
  if (paper.downloadState == DownloadState.downloaded) {
    return PaperDownloadBadge.availableOffline;
  }
  if (paper.downloadState == DownloadState.failed) {
    return PaperDownloadBadge.failed;
  }
  return online
      ? PaperDownloadBadge.cloudOnly
      : PaperDownloadBadge.unavailableOffline;
}

String downloadBadgeLabel(
  AppLocalizations l10n,
  PaperDownloadBadge state, {
  double? progress,
}) => switch (state) {
  PaperDownloadBadge.cloudOnly => l10n.downloadStateCloudOnly,
  PaperDownloadBadge.downloading => l10n.downloadStateDownloading(
    ((progress ?? 0) * 100).round(),
  ),
  PaperDownloadBadge.availableOffline => l10n.downloadStateAvailable,
  PaperDownloadBadge.failed => l10n.downloadStateFailed,
  PaperDownloadBadge.pendingUpload => l10n.downloadStatePendingUpload,
  PaperDownloadBadge.unavailableOffline => l10n.downloadStateUnavailableOffline,
};

/// Callbacks a paper card / row dispatches.
@immutable
class PaperActions {
  const PaperActions({
    required this.open,
    required this.rename,
    required this.delete,
    required this.download,
    required this.removeDownload,
    required this.badgeTap,
  });

  final ValueChanged<Paper> open;
  final ValueChanged<Paper> rename;
  final ValueChanged<Paper> delete;
  final ValueChanged<Paper> download;
  final ValueChanged<Paper> removeDownload;
  final void Function(Paper paper, PaperDownloadBadge state) badgeTap;
}

/// `DownloadStateBadge`: 28dp disc (card) or bare 20dp glyph (row).
class DownloadStateBadge extends StatelessWidget {
  const DownloadStateBadge({
    super.key,
    required this.state,
    required this.onTap,
    this.progress,
    this.disc = true,
  });

  final PaperDownloadBadge state;
  final double? progress;
  final bool disc;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.paper;
    final l10n = AppLocalizations.of(context);
    final (IconData icon, Color color) = switch (state) {
      PaperDownloadBadge.cloudOnly => (Symbols.cloud_rounded, c.textSecondary),
      PaperDownloadBadge.downloading => (Symbols.download_rounded, c.primary),
      PaperDownloadBadge.availableOffline => (
        Symbols.check_circle_rounded,
        c.success,
      ),
      PaperDownloadBadge.failed => (Symbols.error_rounded, c.error),
      PaperDownloadBadge.pendingUpload => (
        Symbols.arrow_upward_rounded,
        c.warning,
      ),
      PaperDownloadBadge.unavailableOffline => (
        Symbols.cloud_off_rounded,
        c.textMuted,
      ),
    };
    final size = disc ? 28.0 : 24.0;
    final Widget glyph = state == PaperDownloadBadge.downloading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 2.5,
              color: c.primary,
              backgroundColor: c.outlineVariant,
            ),
          )
        : Icon(icon, size: disc ? 18 : 20, color: color);
    final label = downloadBadgeLabel(l10n, state, progress: progress);
    return Semantics(
      button: onTap != null,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: InkResponse(
          key: const ValueKey<String>('download-badge'),
          onTap: onTap,
          radius: size,
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: disc
                ? BoxDecoration(
                    color: c.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.border),
                  )
                : null,
            child: glyph,
          ),
        ),
      ),
    );
  }
}

/// Small chip for a paper whose rename / delete is waiting to sync or
/// failed to (sync-state chip).
class PaperSyncChip extends StatelessWidget {
  const PaperSyncChip({super.key, required this.paper});

  final Paper paper;

  @override
  Widget build(BuildContext context) {
    final c = context.paper;
    final l10n = AppLocalizations.of(context);
    final (IconData icon, Color color, String text) = switch (paper.syncState) {
      SyncState.pendingUpdate || SyncState.pendingDelete => (
        Symbols.cloud_upload_rounded,
        c.statusSyncPending,
        l10n.syncStatePending,
      ),
      SyncState.failed => (
        Symbols.warning_rounded,
        c.statusSyncError,
        l10n.syncStateError,
      ),
      _ => (Symbols.check_rounded, c.textMuted, ''),
    };
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      key: const ValueKey<String>('paper-sync-chip'),
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: PaperRadii.borderFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 11, color: c.textSecondary)),
        ],
      ),
    );
  }
}

/// Chip for a paper kept on this device from an account that signed out
/// (guest mode). It is readable here and syncs again when that account
/// signs back in.
class PaperKeptChip extends StatelessWidget {
  const PaperKeptChip({super.key});

  static const Key chipKey = ValueKey<String>('paper-kept-chip');

  @override
  Widget build(BuildContext context) {
    final c = context.paper;
    final l10n = AppLocalizations.of(context);
    return Tooltip(
      message: l10n.libraryKeptFromAccountTooltip,
      child: Container(
        key: chipKey,
        height: 20,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: c.surfaceVariant,
          borderRadius: PaperRadii.borderFull,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Symbols.person_rounded, size: 12, color: c.textSecondary),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                l10n.libraryKeptFromAccount,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: c.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// [localOnly] (offline-only builds, guests) never mentions uploads.
String paperMeta(BuildContext context, Paper paper, {bool localOnly = false}) {
  final l10n = AppLocalizations.of(context);
  if (!localOnly && paper.syncState == SyncState.pendingCreate) {
    return l10n.paperPendingUpload;
  }
  return l10n.paperMetaAdded(paper.uploadedAt.toLocal());
}

/// Overflow / context menu: Open, Rename, Download ↔ Remove download,
/// Delete.
class PaperMenuButton extends StatelessWidget {
  const PaperMenuButton({
    super.key,
    required this.paper,
    required this.actions,
    required this.downloaded,
    this.downloadActions = true,
  });

  final Paper paper;
  final PaperActions actions;
  final bool downloaded;

  /// Download / Remove download items (off in offline-only builds).
  final bool downloadActions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.paper;
    return PopupMenuButton<String>(
      key: ValueKey<String>('paper-menu-${paper.id}'),
      tooltip: l10n.a11yPaperMenu(paper.title),
      icon: const Icon(Symbols.more_vert_rounded, size: 18),
      onSelected: (v) => switch (v) {
        'open' => actions.open(paper),
        'rename' => actions.rename(paper),
        'download' => actions.download(paper),
        'remove' => actions.removeDownload(paper),
        'delete' => actions.delete(paper),
        _ => null,
      },
      itemBuilder: (context) => <PopupMenuEntry<String>>[
        PopupMenuItem(value: 'open', child: Text(l10n.paperMenuOpen)),
        PopupMenuItem(value: 'rename', child: Text(l10n.paperMenuRename)),
        if (downloadActions && downloaded)
          PopupMenuItem(
            value: 'remove',
            child: Text(l10n.paperMenuRemoveDownload),
          )
        else if (downloadActions && !paper.isLinkless)
          PopupMenuItem(value: 'download', child: Text(l10n.paperMenuDownload)),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: Text(l10n.paperMenuDelete, style: TextStyle(color: c.error)),
        ),
      ],
    );
  }
}

/// `PaperThumbnail` placeholder: a white sheet with the title initials.
class PaperThumbnail extends StatelessWidget {
  const PaperThumbnail({super.key, required this.title, this.dimmed = false});

  final String title;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final c = context.paper;
    final initials = title
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w.characters.first.toUpperCase())
        .join();
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.pdfPage,
          borderRadius: PaperRadii.borderSm,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Center(
              child: Text(
                initials,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(color: const Color(0xFF737373)),
              ),
            ),
            // Offline + cloud-only: de-emphasise the thumbnail only, with a
            // surface wash (colour, not an Opacity layer).
            if (dimmed) ColoredBox(color: c.surface.withValues(alpha: 0.55)),
          ],
        ),
      ),
    );
  }
}

/// `PaperCard` (grid).
class PaperCard extends StatelessWidget {
  const PaperCard({
    super.key,
    required this.paper,
    required this.actions,
    required this.badge,
    this.progress,
  });

  final Paper paper;
  final PaperActions actions;

  /// Null in offline-only builds: every paper is local, so there is no
  /// download / sync state to show.
  final PaperDownloadBadge? badge;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final c = context.paper;
    final t = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final badge = this.badge;
    final localOnly = badge == null;
    return Semantics(
      label: badge == null
          ? paper.title
          : '${paper.title}, ${downloadBadgeLabel(l10n, badge, progress: progress)}',
      button: true,
      child: Material(
        color: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: PaperRadii.borderLg,
          side: BorderSide(color: c.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => actions.open(paper),
          child: Padding(
            padding: const EdgeInsets.all(PaperSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? c.surfaceVariant
                          : c.readerBackdrop,
                      borderRadius: PaperRadii.borderSm,
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        PaperThumbnail(
                          title: paper.title,
                          dimmed:
                              badge == PaperDownloadBadge.unavailableOffline,
                        ),
                        if (badge != null)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: DownloadStateBadge(
                              state: badge,
                              progress: progress,
                              onTap: () => actions.badgeTap(paper, badge),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: PaperSpacing.sm),
                SizedBox(
                  height: 40,
                  child: Text(
                    paper.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleSmall?.copyWith(
                      fontSize: 14,
                      height: 20 / 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        paperMeta(context, paper, localOnly: localOnly),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodySmall?.copyWith(color: c.textMuted),
                      ),
                    ),
                    if (!localOnly)
                      PaperSyncChip(paper: paper)
                    else if (!isGuestUserId(paper.userId))
                      const Flexible(child: PaperKeptChip()),
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: PaperMenuButton(
                        paper: paper,
                        actions: actions,
                        downloaded:
                            paper.downloadState == DownloadState.downloaded,
                        downloadActions: !localOnly,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `PaperRow` (list).
class PaperRow extends StatelessWidget {
  const PaperRow({
    super.key,
    required this.paper,
    required this.actions,
    required this.badge,
    this.progress,
  });

  final Paper paper;
  final PaperActions actions;

  /// Null in offline-only builds: every paper is local, so there is no
  /// download / sync state to show.
  final PaperDownloadBadge? badge;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final c = context.paper;
    final t = Theme.of(context).textTheme;
    final opened = paper.lastOpenedAt;
    final badge = this.badge;
    final localOnly = badge == null;
    return InkWell(
      onTap: () => actions.open(paper),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: PaperSpacing.md),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 28,
              height: 36,
              child: PaperThumbnail(
                title: paper.title,
                dimmed: badge == PaperDownloadBadge.unavailableOffline,
              ),
            ),
            const SizedBox(width: PaperSpacing.md),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    paper.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.labelLarge?.copyWith(fontSize: 14),
                  ),
                  Text(
                    paperMeta(context, paper, localOnly: localOnly),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodySmall?.copyWith(color: c.textMuted),
                  ),
                ],
              ),
            ),
            if (badge == null && !isGuestUserId(paper.userId)) ...<Widget>[
              const PaperKeptChip(),
              const SizedBox(width: PaperSpacing.sm),
            ],
            if (badge != null) ...<Widget>[
              PaperSyncChip(paper: paper),
              const SizedBox(width: PaperSpacing.sm),
              DownloadStateBadge(
                state: badge,
                progress: progress,
                disc: false,
                onTap: () => actions.badgeTap(paper, badge),
              ),
            ],
            SizedBox(
              width: 72,
              child: Text(
                opened == null ? '—' : formatWhen(context, opened),
                textAlign: TextAlign.end,
                style: t.bodySmall?.copyWith(color: c.textMuted),
              ),
            ),
            PaperMenuButton(
              paper: paper,
              actions: actions,
              downloaded: paper.downloadState == DownloadState.downloaded,
              downloadActions: !localOnly,
            ),
          ],
        ),
      ),
    );
  }
}

/// `SkeletonCard` / `SkeletonRow`: static blocks, no shimmer (motion #42).
class LibrarySkeleton extends StatelessWidget {
  const LibrarySkeleton({super.key, required this.list, required this.columns});

  final bool list;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final c = context.paper;
    final l10n = AppLocalizations.of(context);
    Widget bar(double f, double h) => FractionallySizedBox(
      widthFactor: f,
      alignment: Alignment.centerLeft,
      child: Container(
        height: h,
        decoration: BoxDecoration(
          color: c.surfaceVariant,
          borderRadius: PaperRadii.borderSm,
        ),
      ),
    );
    return Semantics(
      label: l10n.a11yLoading,
      child: list
          ? ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemExtent: 52,
              itemCount: 8,
              itemBuilder: (_, _) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: PaperSpacing.md,
                  vertical: PaperSpacing.sm,
                ),
                child: Row(
                  children: <Widget>[
                    Container(width: 28, height: 36, color: c.surfaceVariant),
                    const SizedBox(width: PaperSpacing.md),
                    Expanded(child: bar(0.6, 12)),
                  ],
                ),
              ),
            )
          : GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: PaperSpacing.xl,
                crossAxisSpacing: PaperSpacing.md,
                childAspectRatio: 0.55,
              ),
              itemCount: columns * 2,
              itemBuilder: (_, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: c.surfaceVariant,
                        borderRadius: PaperRadii.borderSm,
                      ),
                    ),
                  ),
                  const SizedBox(height: PaperSpacing.sm),
                  bar(0.9, 12),
                  const SizedBox(height: PaperSpacing.xs),
                  bar(0.6, 12),
                  const SizedBox(height: PaperSpacing.xs),
                  bar(0.5, 10),
                ],
              ),
            ),
    );
  }
}

/// `ImportProgressTile`: in progress or failed (reason + Retry / Dismiss).
class ImportProgressTile extends StatelessWidget {
  const ImportProgressTile({
    super.key,
    required this.job,
    required this.errorText,
    required this.onRetry,
    required this.onDismiss,
  });

  final ImportJob job;
  final String? errorText;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final c = context.paper;
    final t = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final failed = job.failed;
    return Semantics(
      liveRegion: failed,
      child: Container(
        padding: const EdgeInsets.all(PaperSpacing.md),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.border),
          borderRadius: PaperRadii.borderLg,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: failed ? c.errorSurface : c.primarySoft,
                borderRadius: PaperRadii.borderMd,
              ),
              child: Icon(
                failed
                    ? Symbols.error_rounded
                    : (job.source == ImportSource.url
                          ? Symbols.link_rounded
                          : Symbols.description_rounded),
                size: 18,
                color: failed ? c.error : c.onPrimarySoft,
              ),
            ),
            const SizedBox(width: PaperSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    job.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.labelLarge,
                  ),
                  Text(
                    failed ? (errorText ?? '') : l10n.importInProgress,
                    style: t.bodySmall?.copyWith(
                      color: failed ? c.error : c.textMuted,
                    ),
                  ),
                  if (!failed) ...<Widget>[
                    const SizedBox(height: PaperSpacing.xs),
                    RepaintBoundary(
                      child: LinearProgressIndicator(
                        minHeight: 4,
                        value: MediaQuery.disableAnimationsOf(context)
                            ? 0.3
                            : null,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (failed) ...<Widget>[
              const SizedBox(width: PaperSpacing.sm),
              OutlinedButton(onPressed: onRetry, child: Text(l10n.importRetry)),
              TextButton(onPressed: onDismiss, child: Text(l10n.importDismiss)),
            ],
          ],
        ),
      ),
    );
  }
}

/// `RenameDialog`: prefilled + selected; empty → `renameEmptyError`.
Future<String?> showRenameDialog(BuildContext context, String current) =>
    showDialog<String>(
      context: context,
      builder: (context) => _RenameDialog(current: current),
    );

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.current});

  final String current;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _c =
      TextEditingController(text: widget.current)
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.current.length,
        );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  bool get _empty => _c.text.trim().isEmpty;

  void _save() {
    if (_empty) return;
    Navigator.of(context).pop(_c.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.renameDialogTitle),
      content: TextField(
        key: const ValueKey<String>('rename-field'),
        controller: _c,
        autofocus: true,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _save(),
        decoration: InputDecoration(
          errorText: _empty ? l10n.renameEmptyError : null,
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.renameCancel),
        ),
        FilledButton(
          key: const ValueKey<String>('rename-save'),
          onPressed: _empty ? null : _save,
          child: Text(l10n.renameSave),
        ),
      ],
    );
  }
}

/// `ImportUrlDialog`. Returns the URL to import, or null.
Future<Uri?> showImportUrlDialog(
  BuildContext context, {
  required bool online,
}) => showDialog<Uri>(
  context: context,
  builder: (context) => _ImportUrlDialog(online: online),
);

/// Accepts only full http(s) URLs with a host.
Uri? parseImportUrl(String text) {
  final uri = Uri.tryParse(text.trim());
  if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
    return null;
  }
  return uri.host.isEmpty ? null : uri;
}

class _ImportUrlDialog extends StatefulWidget {
  const _ImportUrlDialog({required this.online});

  final bool online;

  @override
  State<_ImportUrlDialog> createState() => _ImportUrlDialogState();
}

class _ImportUrlDialogState extends State<_ImportUrlDialog> {
  final TextEditingController _c = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _submit() {
    final uri = parseImportUrl(_c.text);
    if (uri == null) {
      setState(() => _error = AppLocalizations.of(context).importUrlInvalid);
      return;
    }
    Navigator.of(context).pop(uri);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.importUrlDialogTitle),
      content: SizedBox(
        width: 480,
        child: TextField(
          key: const ValueKey<String>('import-url-field'),
          controller: _c,
          autofocus: true,
          keyboardType: TextInputType.url,
          onSubmitted: (_) {
            if (widget.online) _submit();
          },
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          decoration: InputDecoration(
            labelText: l10n.importUrlFieldLabel,
            errorText: _error,
            errorMaxLines: 2,
            helperText: widget.online ? null : l10n.importOfflineUrl,
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.importCancel),
        ),
        FilledButton(
          key: const ValueKey<String>('import-url-submit'),
          onPressed: widget.online ? _submit : null,
          child: Text(l10n.importUrlSubmit),
        ),
      ],
    );
  }
}
