import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../domain/domain.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/paper_tokens.dart';
import '../../ui/ui.dart';
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

/// Callbacks a table row dispatches.
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

  /// Saves a new (trimmed, non-empty) title.
  final Future<void> Function(Paper paper, String title) rename;
  final ValueChanged<Paper> delete;
  final ValueChanged<Paper> download;
  final ValueChanged<Paper> removeDownload;
  final void Function(Paper paper, PaperDownloadBadge state) badgeTap;
}

TextStyle _chipStyle(Color color) => TextStyle(
  fontFamily: PaperTypography.sans,
  fontFamilyFallback: PaperTypography.sansFallback,
  fontSize: PaperTypography.text11,
  height: 16 / 11,
  leadingDistribution: TextLeadingDistribution.even,
  fontWeight: FontWeight.w500,
  color: color,
);

/// `NeutralChip` / `StatusChip.error` (components.md §9.4, §9.7): 20 tall
/// `px-2 py-0.5` 11/16 500. Wraps onto a second line inside the narrow
/// Status column instead of clipping.
class _StatusChip extends StatelessWidget {
  const _StatusChip({super.key, required this.label, this.error = false});

  final String label;
  final bool error;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 20),
    padding: const EdgeInsets.symmetric(
      horizontal: PaperSpacing.tw2,
      vertical: PaperSpacing.tw0_5,
    ),
    decoration: BoxDecoration(
      color: error ? PaperWeb.red950 : PaperWeb.gray800,
      borderRadius: const BorderRadius.all(Radius.circular(10)),
    ),
    child: Text(
      label,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: _chipStyle(error ? PaperWeb.red300 : PaperWeb.gray300),
    ),
  );
}

/// `DownloadStateBadge`, drawn as a status chip. Tappable when [onTap] is
/// set (download, retry, explain offline, open the sync sheet).
class DownloadStateBadge extends StatelessWidget {
  const DownloadStateBadge({
    super.key,
    required this.state,
    required this.onTap,
    this.progress,
  });

  final PaperDownloadBadge state;
  final double? progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final full = downloadBadgeLabel(l10n, state, progress: progress);
    // Offline + cloud-only: the chip says "Not downloaded"; the longer
    // reason is its tooltip / semantics.
    final short = state == PaperDownloadBadge.unavailableOffline
        ? l10n.downloadStateCloudOnly
        : full;
    return PaperPressable(
      key: const ValueKey<String>('download-badge'),
      onPressed: onTap,
      semanticLabel: full,
      excludeSemantics: true,
      tooltip: full == short ? null : full,
      builder: (context, states) => PaperFocusRing(
        show: states.contains(WidgetState.focused),
        radius: const BorderRadius.all(Radius.circular(10)),
        offset: 0,
        child: _StatusChip(
          label: short,
          error: state == PaperDownloadBadge.failed,
        ),
      ),
    );
  }
}

/// Chip for a paper whose rename / delete is waiting to sync or failed to.
class PaperSyncChip extends StatelessWidget {
  const PaperSyncChip({super.key, required this.paper});

  final Paper paper;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (String text, bool error) = switch (paper.syncState) {
      SyncState.pendingUpdate ||
      SyncState.pendingDelete => (l10n.syncStatePending, false),
      SyncState.failed => (l10n.syncStateError, true),
      _ => ('', false),
    };
    if (text.isEmpty) return const SizedBox.shrink();
    return _StatusChip(
      key: const ValueKey<String>('paper-sync-chip'),
      label: text,
      error: error,
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
    final l10n = AppLocalizations.of(context);
    return Tooltip(
      message: l10n.libraryKeptFromAccountTooltip,
      child: _StatusChip(key: chipKey, label: l10n.libraryKeptFromAccount),
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

/// `PaperThumbnail.row` (components.md §7.2): 48×64, radius 6, 1px
/// gray-700 border, gray-800 fill, `file.svg` 20 gray-600. [dimmed]
/// (offline, not downloaded) = opacity .5.
class PaperThumbnail extends StatelessWidget {
  const PaperThumbnail({super.key, this.dimmed = false});

  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: 48,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: PaperWeb.gray800,
        borderRadius: PaperRadii.borderMd,
        border: Border.all(color: PaperWeb.gray700),
      ),
      child: const PaperIcon(
        PaperIcons.file,
        size: 20,
        color: PaperWeb.gray600,
      ),
    );
    return dimmed ? Opacity(opacity: 0.5, child: box) : box;
  }
}

/// `ReadMeter` (components.md §7.3): 40×16 sparkline; read = solid 2
/// accent, unread = dashed 1.5 gray-500. Display only.
class ReadMeter extends StatelessWidget {
  const ReadMeter({super.key, required this.read});

  final bool read;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      size: const Size(40, 16),
      painter: _ReadMeterPainter(read),
    ),
  );
}

class _ReadMeterPainter extends CustomPainter {
  _ReadMeterPainter(this.read);

  final bool read;

  static const List<Offset> _points = <Offset>[
    Offset(1, 12),
    Offset(8, 5),
    Offset(15, 11),
    Offset(22, 3),
    Offset(29, 10),
    Offset(39, 6),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(_points.first.dx, _points.first.dy);
    for (final p in _points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..color = read ? PaperWeb.accent : PaperWeb.gray500
      ..strokeWidth = read ? 2 : 1.5;
    if (read) {
      canvas.drawPath(path, paint);
      return;
    }
    paint.strokeCap = StrokeCap.butt;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 3), paint);
        d += 6;
      }
    }
  }

  @override
  bool shouldRepaint(_ReadMeterPainter old) => old.read != read;
}

/// Column widths of the papers table (library.md §2.2).
abstract final class LibraryTableColumns {
  static const double photo = 80;
  static const double nameMin = 200;
  static const double nameContentMax = 288;
  static const double rate = 72;
  static const double status = 104;
  static const double opened = 96;
  static const double action = 180;

  /// `min-w-[44rem]`: below this the table scrolls sideways in its card.
  static const double minTableWidth = 704;
  static const double headerHeight = 48;
  static const double rowHeight = 88;
}

const EdgeInsets _cellPad = EdgeInsets.symmetric(horizontal: PaperSpacing.tw4);

/// The table header row: 48 tall, eyebrow labels, 1px gray-800 bottom
/// border. [showStatus] adds the app-only Status column.
class LibraryTableHeader extends StatelessWidget {
  const LibraryTableHeader({super.key, required this.showStatus});

  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final style = PaperTypography.eyebrow(PaperColors.dark)
        .copyWith(color: PaperWeb.gray400);
    Widget cell(String text, {double? width, bool end = false}) {
      final label = Padding(
        padding: _cellPad,
        child: Text(
          text.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: end ? TextAlign.end : TextAlign.start,
          style: style,
        ),
      );
      return width == null
          ? Expanded(child: label)
          : SizedBox(width: width, child: label);
    }

    return Semantics(
      container: true,
      child: Container(
        height: LibraryTableColumns.headerHeight,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: PaperWeb.gray800)),
        ),
        child: Row(
          children: <Widget>[
            cell(l10n.libraryColumnPhoto, width: LibraryTableColumns.photo),
            cell(l10n.libraryColumnName),
            cell(l10n.libraryColumnRate, width: LibraryTableColumns.rate),
            if (showStatus)
              cell(l10n.libraryColumnStatus, width: LibraryTableColumns.status),
            cell(l10n.libraryColumnOpened, width: LibraryTableColumns.opened),
            cell(
              l10n.libraryColumnAction,
              width: LibraryTableColumns.action,
              end: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// One `PaperTableRow` (components.md §7.1): 88 tall + 1px divider, hover
/// `#1F1F1F`, tap opens the paper; Open · ··· · Delete actions; the "···"
/// detail row (Rename, Download / Remove download); inline rename at ≥ 640
/// (a [PaperDialog] below).
class PaperTableRow extends StatefulWidget {
  const PaperTableRow({
    super.key,
    required this.paper,
    required this.actions,
    required this.badge,
    required this.showStatus,
    this.progress,
    this.last = false,
  });

  final Paper paper;
  final PaperActions actions;

  /// Null for local-only libraries (offline-only builds, guests): no
  /// download / sync state.
  final PaperDownloadBadge? badge;
  final bool showStatus;
  final double? progress;

  /// No divider under the last row.
  final bool last;

  @override
  State<PaperTableRow> createState() => _PaperTableRowState();
}

class _PaperTableRowState extends State<PaperTableRow> {
  bool _hover = false;
  bool _expanded = false;
  bool _renaming = false;
  bool _saving = false;
  final TextEditingController _rename = TextEditingController();
  final FocusNode _renameFocus = FocusNode();

  Paper get _paper => widget.paper;

  @override
  void dispose() {
    _rename.dispose();
    _renameFocus.dispose();
    super.dispose();
  }

  Future<void> _startRename() async {
    if (!WebBreakpoint.of(context).isSmUp) {
      final title = await showRenameDialog(context, _paper.title);
      if (title == null || title == _paper.title) return;
      await widget.actions.rename(_paper, title);
      return;
    }
    setState(() {
      _renaming = true;
      _rename
        ..text = _paper.title
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: _paper.title.length,
        );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _renameFocus.requestFocus();
    });
  }

  void _cancelRename() {
    if (_saving) return;
    setState(() => _renaming = false);
  }

  Future<void> _saveRename() async {
    final title = _rename.text.trim();
    if (title.isEmpty || _saving) return;
    if (title == _paper.title) return _cancelRename();
    setState(() => _saving = true);
    try {
      await widget.actions.rename(_paper, title);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _renaming = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final badge = widget.badge;
    final localOnly = badge == null;
    final opened = _paper.lastOpenedAt;
    final downloaded = _paper.downloadState == DownloadState.downloaded;

    final name = _renaming ? _renameCell(l10n) : _nameCell(context, localOnly);

    final row = SizedBox(
      height: LibraryTableColumns.rowHeight,
      child: Row(
        children: <Widget>[
          SizedBox(
            width: LibraryTableColumns.photo,
            child: Padding(
              padding: _cellPad,
              child: PaperThumbnail(
                dimmed: badge == PaperDownloadBadge.unavailableOffline,
              ),
            ),
          ),
          Expanded(
            child: Padding(padding: _cellPad, child: name),
          ),
          SizedBox(
            width: LibraryTableColumns.rate,
            child: Padding(
              padding: _cellPad,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: ReadMeter(read: _paper.isRead),
              ),
            ),
          ),
          if (widget.showStatus)
            SizedBox(
              width: LibraryTableColumns.status,
              child: Padding(
                padding: _cellPad,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Wrap(
                    spacing: PaperSpacing.tw1,
                    runSpacing: PaperSpacing.tw1,
                    children: <Widget>[
                      if (badge == null && !isGuestUserId(_paper.userId))
                        const PaperKeptChip(),
                      if (badge != null) ...<Widget>[
                        PaperSyncChip(paper: _paper),
                        DownloadStateBadge(
                          state: badge,
                          progress: widget.progress,
                          onTap: () => widget.actions.badgeTap(_paper, badge),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          SizedBox(
            width: LibraryTableColumns.opened,
            child: Padding(
              padding: _cellPad,
              child: opened == null
                  ? Semantics(
                      label: l10n.libraryNeverOpened,
                      child: ExcludeSemantics(
                        child: Text(
                          '—',
                          style: t.bodySmall?.copyWith(color: PaperWeb.gray500),
                        ),
                      ),
                    )
                  : Text(
                      formatWhen(context, opened),
                      style: t.bodySmall?.copyWith(color: PaperWeb.gray400),
                    ),
            ),
          ),
          SizedBox(
            width: LibraryTableColumns.action,
            child: Padding(
              padding: _cellPad,
              // Exactly 148 wide on the web; scaleDown keeps wider fallback
              // fonts from overflowing.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerEnd,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    PaperButton.ghost(
                      key: ValueKey<String>('paper-open-${_paper.id}'),
                      label: l10n.paperMenuOpen,
                      size: PaperButtonSize.xs,
                      focusGap: PaperWeb.gray900,
                      onPressed: () => widget.actions.open(_paper),
                    ),
                    const SizedBox(width: PaperSpacing.tw1),
                    PaperButton.ghost(
                      key: ValueKey<String>('paper-menu-${_paper.id}'),
                      label: '···',
                      size: PaperButtonSize.xs,
                      open: _expanded,
                      focusGap: PaperWeb.gray900,
                      semanticLabel: l10n.a11yPaperMenu(_paper.title),
                      onPressed: () => setState(() => _expanded = !_expanded),
                    ),
                    const SizedBox(width: PaperSpacing.tw1),
                    PaperButton.destructive(
                      key: ValueKey<String>('paper-delete-${_paper.id}'),
                      label: l10n.paperMenuDelete,
                      focusGap: PaperWeb.gray900,
                      onPressed: () => widget.actions.delete(_paper),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final detail = !_expanded
        ? null
        : Padding(
            key: ValueKey<String>('paper-detail-${_paper.id}'),
            padding: const EdgeInsets.fromLTRB(
              PaperSpacing.tw4,
              0,
              PaperSpacing.tw4,
              PaperSpacing.tw3,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: PaperSpacing.tw1,
                  runSpacing: PaperSpacing.tw1,
                  children: <Widget>[
                    PaperButton.ghost(
                      key: ValueKey<String>('paper-rename-${_paper.id}'),
                      label: l10n.paperMenuRename,
                      size: PaperButtonSize.xs,
                      focusGap: PaperWeb.gray800Half,
                      onPressed: _renaming
                          ? null
                          : () {
                              setState(() => _expanded = false);
                              unawaited(_startRename());
                            },
                    ),
                    if (!localOnly && downloaded)
                      PaperButton.ghost(
                        label: l10n.paperMenuRemoveDownload,
                        size: PaperButtonSize.xs,
                        focusGap: PaperWeb.gray800Half,
                        onPressed: () => widget.actions.removeDownload(_paper),
                      )
                    else if (!localOnly && !_paper.isLinkless)
                      PaperButton.ghost(
                        label: l10n.paperMenuDownload,
                        size: PaperButtonSize.xs,
                        focusGap: PaperWeb.gray800Half,
                        onPressed: widget.progress != null
                            ? null
                            : () => widget.actions.download(_paper),
                      ),
                  ],
                ),
                if (badge == PaperDownloadBadge.failed) ...<Widget>[
                  const SizedBox(height: PaperSpacing.tw1_5),
                  Text(
                    l10n.downloadStateFailed,
                    style: t.bodySmall?.copyWith(color: PaperWeb.red400),
                  ),
                ],
              ],
            ),
          );

    final hot = _hover || _expanded;
    Widget body = AnimatedContainer(
      duration: PaperMotion.of(context, PaperMotion.colors),
      decoration: BoxDecoration(
        color: hot ? PaperWeb.gray800Half : Colors.transparent,
        border: widget.last
            ? null
            : const Border(bottom: BorderSide(color: PaperWeb.gray800)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _renaming ? null : () => widget.actions.open(_paper),
            child: row,
          ),
          ?detail,
        ],
      ),
    );
    body = MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: body,
    );
    if (widget.last) {
      body = ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(7)),
        child: body,
      );
    }
    return Semantics(container: true, child: body);
  }

  Widget _nameCell(BuildContext context, bool localOnly) {
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: LibraryTableColumns.nameContentMax,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Flexible(
                  child: PaperPressable(
                    onPressed: () => widget.actions.open(_paper),
                    excludeSemantics: true,
                    semanticLabel: _paper.title,
                    builder: (context, states) {
                      final hot =
                          states.contains(WidgetState.hovered) ||
                          states.contains(WidgetState.pressed);
                      final color = hot ? PaperWeb.accent : PaperWeb.gray100;
                      return PaperFocusRing(
                        show: states.contains(WidgetState.focused),
                        radius: PaperRadii.borderMd,
                        offset: 0,
                        child: Text(
                          _paper.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                          style: t.labelLarge?.copyWith(
                            color: color,
                            decoration: hot
                                ? TextDecoration.underline
                                : TextDecoration.none,
                            decorationColor: color,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (_paper.isRead) ...<Widget>[
                  const SizedBox(width: PaperSpacing.tw2),
                  PaperBadge(label: l10n.libraryReadBadge),
                ],
              ],
            ),
            const SizedBox(height: PaperSpacing.tw0_5),
            Text(
              paperMeta(context, _paper, localOnly: localOnly),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.bodySmall?.copyWith(color: PaperWeb.gray400),
            ),
          ],
        ),
      ),
    );
  }

  Widget _renameCell(AppLocalizations l10n) {
    final empty = _rename.text.trim().isEmpty;
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): _cancelRename,
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: PaperTextField(
                  fieldKey: const ValueKey<String>('rename-field'),
                  controller: _rename,
                  focusNode: _renameFocus,
                  size: PaperTextFieldSize.sm,
                  enabled: !_saving,
                  semanticLabel: l10n.renameDialogTitle,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => unawaited(_saveRename()),
                ),
              ),
              const SizedBox(width: PaperSpacing.tw2),
              PaperButton.primary(
                key: const ValueKey<String>('rename-save'),
                label: _saving ? l10n.commonSaving : l10n.renameSave,
                size: PaperButtonSize.xs,
                focusGap: PaperWeb.gray900,
                onPressed: _saving || empty
                    ? null
                    : () => unawaited(_saveRename()),
              ),
              const SizedBox(width: PaperSpacing.tw2),
              PaperButton.secondary(
                label: l10n.renameCancel,
                size: PaperButtonSize.xs,
                focusGap: PaperWeb.gray900,
                onPressed: _saving ? null : _cancelRename,
              ),
            ],
          ),
          if (empty) ...<Widget>[
            const SizedBox(height: PaperSpacing.tw1),
            Text(
              l10n.renameEmptyError,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: PaperWeb.red400),
            ),
          ],
        ],
      ),
    );
  }
}

/// Loading (library.md §4): 4 skeleton rows, 88 tall.
class LibrarySkeletonRow extends StatelessWidget {
  const LibrarySkeletonRow({super.key, required this.showStatus});

  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    Widget bar(double f, double h) => FractionallySizedBox(
      widthFactor: f,
      alignment: AlignmentDirectional.centerStart,
      child: PaperSkeleton(height: h),
    );
    return Container(
      height: LibraryTableColumns.rowHeight + 1,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: PaperWeb.gray800)),
      ),
      child: Row(
        children: <Widget>[
          const SizedBox(
            width: LibraryTableColumns.photo,
            child: Padding(
              padding: _cellPad,
              child: ClipRRect(
                borderRadius: PaperRadii.borderMd,
                child: PaperSkeleton(width: 48, height: 64),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: _cellPad,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  bar(0.4, 14),
                  const SizedBox(height: PaperSpacing.tw1_5),
                  bar(0.25, 12),
                ],
              ),
            ),
          ),
          SizedBox(
            width: LibraryTableColumns.rate,
            child: Padding(padding: _cellPad, child: bar(0.4, 12)),
          ),
          if (showStatus) const SizedBox(width: LibraryTableColumns.status),
          SizedBox(
            width: LibraryTableColumns.opened,
            child: Padding(padding: _cellPad, child: bar(0.4, 12)),
          ),
          const SizedBox(width: LibraryTableColumns.action),
        ],
      ),
    );
  }
}

/// Import progress card (library.md §3.3): running (spinner, label,
/// "Adding…", progress bar) or failed (error glyph, reason, Try again /
/// Dismiss).
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
    final t = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final failed = job.failed;
    return Semantics(
      liveRegion: failed,
      child: PaperCard(
        padding: const EdgeInsets.all(PaperSpacing.tw3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: failed
                      ? const PaperIcon(
                          PaperIcons.toastError,
                          color: PaperWeb.red400,
                        )
                      : const PaperSpinner(),
                ),
                const SizedBox(width: PaperSpacing.tw2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        job.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.labelLarge?.copyWith(color: PaperWeb.gray100),
                      ),
                      Text(
                        failed ? (errorText ?? '') : l10n.importInProgress,
                        style: t.bodySmall?.copyWith(
                          color: failed ? PaperWeb.red400 : PaperWeb.gray400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: PaperSpacing.tw2),
            if (!failed)
              const PaperProgressBar()
            else
              Wrap(
                spacing: PaperSpacing.tw1,
                runSpacing: PaperSpacing.tw1,
                children: <Widget>[
                  PaperButton.secondary(
                    label: l10n.importRetry,
                    size: PaperButtonSize.xs,
                    focusGap: PaperWeb.gray900,
                    onPressed: onRetry,
                  ),
                  PaperButton.ghost(
                    label: l10n.importDismiss,
                    size: PaperButtonSize.xs,
                    focusGap: PaperWeb.gray900,
                    onPressed: onDismiss,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Rename dialog (below 640, where inline rename doesn't fit): prefilled
/// and selected; empty → `renameEmptyError`.
Future<String?> showRenameDialog(BuildContext context, String current) =>
    showPaperDialog<String>(
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
    return PaperDialog(
      title: l10n.renameDialogTitle,
      content: PaperTextField(
        fieldKey: const ValueKey<String>('rename-field'),
        controller: _c,
        autofocus: true,
        errorText: _empty ? l10n.renameEmptyError : null,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _save(),
      ),
      actions: <Widget>[
        PaperButton.secondary(
          label: l10n.renameCancel,
          focusGap: PaperWeb.gray900,
          onPressed: () => Navigator.of(context).pop(),
        ),
        PaperButton.primary(
          key: const ValueKey<String>('rename-save'),
          label: l10n.renameSave,
          focusGap: PaperWeb.gray900,
          onPressed: _empty ? null : _save,
        ),
      ],
    );
  }
}

/// Accepts only full http(s) URLs with a host.
Uri? parseImportUrl(String text) {
  final uri = Uri.tryParse(text.trim());
  if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
    return null;
  }
  return uri.host.isEmpty ? null : uri;
}
