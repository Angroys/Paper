import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_commands.dart';
import '../../app/routes.dart';
import '../../auth/auth_providers.dart';
import '../../core/build_flags.dart';
import '../../core/core_providers.dart';
import '../../data/data_providers.dart';
import '../../domain/domain.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/motion_extras.dart';
import '../../theme/paper_tokens.dart';
import '../../ui/ui.dart';
import '../auth/sign_in_prompt.dart';
import '../sync/sync_sheet.dart';
import 'library_controller.dart';
import 'library_widgets.dart';

/// Library (design/web-parity/screens/library.md): "Library" title, the
/// add-paper disclosure (From a file · From a link cards), import progress,
/// then "Your papers": search, filter, sort and the papers table. Rename
/// inline, delete with undo, download / remove download, and the empty /
/// no-match / offline / loading / error states.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  static const Key searchFieldKey = Key('library.search');
  static const Key tableKey = Key('library.table');
  static const Key importButtonKey = Key('library.import');
  static const Key chooseFileKey = Key('library.chooseFile');
  static const Key addPanelKey = Key('library.addPanel');

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

/// Inline status line tone (components.md §17 `InlineStatus`).
enum _Tone { neutral, success, error }

typedef _Status = ({String text, _Tone tone});

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final FocusNode _triggerFocus = FocusNode();
  final FocusNode _chooseFocus = FocusNode();
  final FocusNode _linkFocus = FocusNode();
  final TextEditingController _link = TextEditingController();
  Timer? _debounce;

  /// Add-paper disclosure.
  bool _addOpen = false;
  String? _fileName;
  _Status? _fileStatus;
  _Status? _linkStatus;
  bool _linkBusy = false;

  /// Last (query, count) announced as `librarySearchResultCount`.
  (String, int)? _announced;

  /// Last loaded rows: shown while the next search query loads, so typing
  /// never flashes the skeleton.
  List<Paper>? _lastPapers;

  @override
  void initState() {
    super.initState();
    _search.text = ref.read(libraryViewProvider).query;
    ref.listenManual<LibraryCommand?>(libraryCommandProvider, (_, next) {
      if (next != null) _runPendingCommand();
    }, fireImmediately: true);
  }

  void _runPendingCommand() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cmd = ref.read(libraryCommandProvider.notifier).take();
      switch (cmd?.kind) {
        case LibraryCommandKind.focusSearch:
          _searchFocus.requestFocus();
          _search.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _search.text.length,
          );
        case LibraryCommandKind.importFile:
          unawaited(_importFile());
        case LibraryCommandKind.importUrl:
          // No import by link in offline-only builds.
          if (!_offlineOnly) _showLinkCard();
        case null:
          break;
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    _triggerFocus.dispose();
    _chooseFocus.dispose();
    _linkFocus.dispose();
    _link.dispose();
    super.dispose();
  }

  bool get _online => ref.read(isOnlineProvider).value ?? true;

  bool get _offlineOnly => ref.read(offlineOnlyProvider);

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(kLibrarySearchDebounce, () {
      if (!mounted) return;
      ref.read(libraryViewProvider.notifier).setQuery(value.trim());
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _search.clear();
    ref.read(libraryViewProvider.notifier).setQuery('');
  }

  void _toast(
    String text, {
    PaperToastTone tone = PaperToastTone.plain,
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
  }) {
    if (!mounted) return;
    showPaperToast(
      context,
      message: text,
      tone: tone,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
      dismissTooltip: AppLocalizations.of(context).commonDismiss,
    );
  }

  // ------------------------------------------------------------ Disclosure

  void _toggleAdd() {
    setState(() => _addOpen = !_addOpen);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      (_addOpen ? _chooseFocus : _triggerFocus).requestFocus();
    });
  }

  /// Ctrl+Shift+O / "import from link" command: open the panel on the link
  /// card (guests get the sign-in prompt instead).
  void _showLinkCard() {
    if (ref.read(isGuestProvider)) {
      unawaited(showSignInPromptDialog(context, GuestFeature.importLink));
      return;
    }
    setState(() => _addOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _linkFocus.requestFocus();
    });
  }

  // ---------------------------------------------------------------- Actions

  void _open(Paper paper) {
    final l10n = AppLocalizations.of(context);
    if (paper.downloadState != DownloadState.downloaded && !_online) {
      _toast(l10n.readerUnavailableOffline, tone: PaperToastTone.error);
      return;
    }
    unawaited(GoRouter.maybeOf(context)?.push(AppRoutes.reader(paper.id)));
  }

  Future<void> _rename(Paper paper, String title) =>
      ref.read(paperRepositoryProvider).rename(paper.id, title);

  Future<void> _delete(Paper paper) async {
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(paperRepositoryProvider);
    try {
      await repo.delete(paper.id);
    } on Object {
      _toast(
        l10n.libraryDeleteFailed(paper.title),
        tone: PaperToastTone.error,
        actionLabel: l10n.commonRetry,
        onAction: () => unawaited(_delete(paper)),
        duration: kUndoSnackbarDurationLibraryDelete,
      );
      return;
    }
    // PaperRepository keeps a 10 s undo window; the toast shows for 8 s.
    _toast(
      l10n.libraryDeletedUndo(paper.title),
      duration: kUndoSnackbarDurationLibraryDelete,
      actionLabel: l10n.undo,
      onAction: () => unawaited(repo.undoDelete(paper.id)),
    );
  }

  void _badgeTap(Paper paper, PaperDownloadBadge state) {
    final activity = ref.read(libraryActivityProvider.notifier);
    switch (state) {
      case PaperDownloadBadge.cloudOnly:
      case PaperDownloadBadge.failed:
        unawaited(activity.download(paper.id));
      case PaperDownloadBadge.unavailableOffline:
        _toast(
          AppLocalizations.of(context).readerUnavailableOffline,
          tone: PaperToastTone.error,
        );
      case PaperDownloadBadge.pendingUpload:
        unawaited(showSyncSheet(context));
      case PaperDownloadBadge.availableOffline:
      case PaperDownloadBadge.downloading:
        break;
    }
  }

  late final PaperActions _actions = PaperActions(
    open: _open,
    rename: _rename,
    delete: (p) => unawaited(_delete(p)),
    download: (p) =>
        unawaited(ref.read(libraryActivityProvider.notifier).download(p.id)),
    removeDownload: (p) => unawaited(
      ref.read(libraryActivityProvider.notifier).removeDownload(p.id),
    ),
    badgeTap: _badgeTap,
  );

  Future<void> _importFile() async {
    final List<PickedPdf> files;
    try {
      files = await ref.read(pdfPickerProvider)();
    } on Object {
      return;
    }
    if (!mounted || files.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _fileName = files.length == 1 ? files.single.name : null;
      _fileStatus = (text: l10n.importInProgress, tone: _Tone.neutral);
    });
    final activity = ref.read(libraryActivityProvider.notifier);
    var added = 0;
    for (final f in files) {
      if (await activity.importFile(f) != null) added++;
    }
    if (!mounted) return;
    setState(() {
      if (files.length > 1) {
        _fileStatus = (
          text: l10n.importBatchSummary(added, files.length - added),
          tone: added == files.length ? _Tone.success : _Tone.error,
        );
      } else {
        // Failures show in their import card (reason + Try again).
        _fileStatus = added == 1
            ? (text: l10n.importSuccess, tone: _Tone.success)
            : null;
      }
    });
  }

  Future<void> _importUrl() async {
    // Guests: import by link runs on the server, so ask to sign in.
    if (ref.read(isGuestProvider)) {
      return showSignInPromptDialog(context, GuestFeature.importLink);
    }
    final l10n = AppLocalizations.of(context);
    final url = parseImportUrl(_link.text);
    if (url == null) {
      setState(
        () => _linkStatus = (text: l10n.importUrlInvalid, tone: _Tone.error),
      );
      return;
    }
    setState(() {
      _linkBusy = true;
      _linkStatus = null;
    });
    final paper = await ref
        .read(libraryActivityProvider.notifier)
        .importFromUrl(url);
    if (!mounted) return;
    setState(() {
      _linkBusy = false;
      if (paper != null) {
        _link.clear();
        _linkStatus = (text: l10n.importSuccess, tone: _Tone.success);
      }
    });
  }

  /// User-facing text for an import failure.
  String importErrorText(AppLocalizations l10n, ImportJob job) {
    final e = job.error;
    final url = job.source == ImportSource.url;
    return switch (e) {
      FileTooLargeException(:final maxBytes) => l10n.importFileTooLarge(
        (maxBytes / (1024 * 1024)).round(),
      ),
      InvalidPdfException() =>
        url ? l10n.importUrlNotPdf : l10n.importFileInvalid,
      NotFoundException() =>
        url ? l10n.importUrlFetchFailed : l10n.importFileInvalid,
      OfflineException() => url ? l10n.importOfflineUrl : l10n.errorNetwork,
      AuthExpiredException() => l10n.errorAuthExpired,
      StorageException() => l10n.errorStorageFull,
      _ => url ? l10n.importUrlFetchFailed : l10n.importUploadFailed,
    };
  }

  void _announceCount(AppLocalizations l10n, String query, int count) {
    final announce = (query, count);
    if (query.isEmpty || announce == _announced) return;
    _announced = announce;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        SemanticsService.sendAnnouncement(
          View.of(context),
          l10n.librarySearchResultCount(count),
          Directionality.of(context),
        ),
      );
    });
  }

  // ------------------------------------------------------------------ Build

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final view = ref.watch(libraryViewProvider);
    final activity = ref.watch(libraryActivityProvider);
    final online = ref.watch(isOnlineProvider).value ?? true;
    // Offline-only builds: file import only, no download / sync states.
    final offlineOnly = ref.watch(offlineOnlyProvider);
    final guest = ref.watch(isGuestProvider);
    // Guests (no account): papers live on this device only, so no download
    // or sync states either; import by link asks to sign in.
    final localOnly = offlineOnly || guest;
    final async = ref.watch(libraryPapersProvider((view.query, view.sort)));
    final bp = WebBreakpoint.of(context);
    final pad = MediaQuery.viewPaddingOf(context);

    final loaded = async.value ?? _lastPapers;
    if (async.hasValue) _lastPapers = async.value;
    final papers = loaded == null
        ? null
        : applyLibraryFilter(loaded, view.filter);
    if (papers != null) _announceCount(l10n, view.query, papers.length);
    final empty = loaded != null && loaded.isEmpty && view.query.isEmpty;
    // The Status column only exists when some row has a chip.
    final showStatus =
        !localOnly ||
        (loaded ?? const <Paper>[]).any((p) => !isGuestUserId(p.userId));

    return Scaffold(
      backgroundColor: PaperWeb.gray950,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          // `mx-auto max-w-7xl px-6`: box ≤ 1280 incl. its 24 padding.
          final side = (width - math.min(width, 1280)) / 2 + 24;
          final left = side + pad.left;
          final right = side + pad.right;
          final contentWidth = math.max(0.0, width - left - right);
          final top = bp.isSmUp ? PaperSpacing.tw12 : PaperSpacing.tw10;
          final bottom = top + pad.bottom;

          final header = <Widget>[
            Semantics(
              header: true,
              child: Text(
                l10n.libraryTitle,
                style: PaperTypography.pageTitle(PaperColors.dark),
              ),
            ),
            const SizedBox(height: PaperSpacing.tw8),
            if (empty)
              _EmptyLibraryCard(
                fileOnly: offlineOnly,
                trigger: _addTrigger(l10n),
              )
            else
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: _addTrigger(l10n),
              ),
            if (_addOpen) ...<Widget>[
              const SizedBox(height: PaperSpacing.tw4),
              _addPanel(l10n, bp, online: online, offlineOnly: offlineOnly),
            ],
            for (final job in activity.imports) ...<Widget>[
              const SizedBox(height: PaperSpacing.tw2),
              ImportProgressTile(
                key: ValueKey<String>('import-${job.id}'),
                job: job,
                errorText: job.failed ? importErrorText(l10n, job) : null,
                onRetry: () => unawaited(
                  ref
                      .read(libraryActivityProvider.notifier)
                      .retryImport(job.id),
                ),
                onDismiss: () => ref
                    .read(libraryActivityProvider.notifier)
                    .dismissImport(job.id),
              ),
            ],
            if (!empty) ...<Widget>[
              const SizedBox(height: PaperSpacing.tw8),
              Semantics(
                header: true,
                child: Text(
                  l10n.libraryYourPapers,
                  style: PaperTypography.sectionTitle(PaperColors.dark),
                ),
              ),
              const SizedBox(height: PaperSpacing.tw4),
              _Toolbar(
                search: _search,
                searchFocus: _searchFocus,
                onSearchChanged: _onSearchChanged,
                view: view,
                localOnly: localOnly,
              ),
              if (view.query.isNotEmpty && papers != null) ...<Widget>[
                const SizedBox(height: PaperSpacing.tw2),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: PaperSpacing.tw1,
                  ),
                  child: Text(
                    l10n.librarySearchResultCount(papers.length),
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: PaperWeb.gray400),
                  ),
                ),
              ],
              const SizedBox(height: PaperSpacing.tw3),
            ],
          ];

          final slivers = <Widget>[
            SliverPadding(
              padding: EdgeInsets.fromLTRB(left, top, right, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: header,
                ),
              ),
            ),
          ];

          Widget? slot;
          List<Widget>? rows;
          if (empty) {
            slot = null;
          } else if (async.hasError && loaded == null) {
            slot = _ErrorBanner(
              title: l10n.libraryLoadFailedTitle,
              body: l10n.libraryLoadFailedBody,
              retryLabel: l10n.commonRetry,
              onRetry: () {
                unawaited(ref.read(paperRepositoryProvider).refresh());
                ref.invalidate(libraryPapersProvider);
              },
            );
          } else if (papers == null) {
            rows = <Widget>[
              Semantics(
                label: l10n.a11yLoading,
                child: LibraryTableHeader(showStatus: showStatus),
              ),
              for (var i = 0; i < 4; i++)
                LibrarySkeletonRow(showStatus: showStatus),
            ];
          } else if (loaded!.isEmpty) {
            slot = _EmptyStateCard(
              title: l10n.librarySearchNoResultsTitle(view.query),
              body: l10n.librarySearchNoResultsBody,
              action: PaperButton.secondary(
                label: l10n.librarySearchClear,
                onPressed: _clearSearch,
              ),
            );
          } else if (papers.isEmpty) {
            slot = _EmptyStateCard(
              body: view.filter == LibraryFilter.downloaded
                  ? l10n.libraryFilterDownloadedEmpty
                  : l10n.libraryFilterUnreadEmpty,
              action: PaperButton.secondary(
                label: l10n.libraryShowAll,
                onPressed: () => ref
                    .read(libraryViewProvider.notifier)
                    .setFilter(LibraryFilter.all),
              ),
            );
          } else {
            PaperDownloadBadge? badge(Paper p) => localOnly
                ? null
                : downloadBadgeFor(
                    p,
                    online: online,
                    progress: activity.downloads[p.id],
                    failed: activity.failedDownloads.contains(p.id),
                  );
            Widget row(int i) => PaperTableRow(
              key: ValueKey<String>('paper-${papers[i].id}'),
              paper: papers[i],
              actions: _actions,
              badge: badge(papers[i]),
              progress: activity.downloads[papers[i].id],
              showStatus: showStatus,
              last: i == papers.length - 1,
            );
            if (contentWidth >= LibraryTableColumns.minTableWidth) {
              slivers.add(
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(left, 0, right, bottom),
                  sliver: DecoratedSliver(
                    key: LibraryScreen.tableKey,
                    decoration: _cardDecoration,
                    sliver: SliverPadding(
                      padding: const EdgeInsets.all(1),
                      sliver: SliverList.builder(
                        itemCount: papers.length + 1,
                        itemBuilder: (context, i) => i == 0
                            ? LibraryTableHeader(showStatus: showStatus)
                            : row(i - 1),
                      ),
                    ),
                  ),
                ),
              );
            } else {
              rows = <Widget>[
                LibraryTableHeader(showStatus: showStatus),
                for (var i = 0; i < papers.length; i++) row(i),
              ];
            }
          }
          if (rows != null) {
            slot = _TableCard(
              key: LibraryScreen.tableKey,
              width: contentWidth,
              children: rows,
            );
          }
          if (slot != null || empty || rows != null) {
            slivers.add(
              SliverPadding(
                padding: EdgeInsets.fromLTRB(left, 0, right, bottom),
                sliver: SliverToBoxAdapter(child: slot ?? const SizedBox()),
              ),
            );
          }

          return CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
            slivers: slivers,
          );
        },
      ),
    );
  }

  Widget _addTrigger(AppLocalizations l10n) => PaperButton.primary(
    key: LibraryScreen.importButtonKey,
    focusNode: _triggerFocus,
    label: _addOpen ? l10n.commonClose : l10n.importButton,
    trailing: PaperRotatingIcon(
      PaperIcons.chevronDown,
      turns: _addOpen ? 0.5 : 0,
      duration: PaperMotion.of(context, PaperMotion.fast),
    ),
    onPressed: _toggleAdd,
  );

  Widget _addPanel(
    AppLocalizations l10n,
    WebBreakpoint bp, {
    required bool online,
    required bool offlineOnly,
  }) {
    final fileCard = _FileCard(
      fileName: _fileName,
      status: _fileStatus,
      focusNode: _chooseFocus,
      onChoose: () => unawaited(_importFile()),
    );
    final Widget? linkCard = offlineOnly
        ? null
        : ref.watch(isGuestProvider)
        ? const _GuestLinkCard()
        : _LinkCard(
            controller: _link,
            focusNode: _linkFocus,
            online: online,
            busy: _linkBusy,
            status: _linkStatus,
            onChanged: () {
              if (_linkStatus != null) setState(() => _linkStatus = null);
            },
            onSubmit: () => unawaited(_importUrl()),
          );
    final Widget panel;
    if (bp >= WebBreakpoint.md) {
      panel = IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(child: fileCard),
            const SizedBox(width: PaperSpacing.tw4),
            Expanded(child: linkCard ?? const SizedBox()),
          ],
        ),
      );
    } else {
      panel = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          fileCard,
          if (linkCard != null) ...<Widget>[
            const SizedBox(height: PaperSpacing.tw4),
            linkCard,
          ],
        ],
      );
    }
    return KeyedSubtree(key: LibraryScreen.addPanelKey, child: panel);
  }
}

const BoxDecoration _cardDecoration = BoxDecoration(
  color: PaperWeb.gray900,
  borderRadius: PaperRadii.borderLg,
  border: Border.fromBorderSide(BorderSide(color: PaperWeb.gray800)),
);

/// The papers table drawn eagerly (loading skeleton, or a content width
/// below the 704 table minimum, where it scrolls sideways in its card).
class _TableCard extends StatelessWidget {
  const _TableCard({super.key, required this.width, required this.children});

  final double width;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tableWidth = math.max(width, LibraryTableColumns.minTableWidth);
    final table = SizedBox(
      width: tableWidth - 2,
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
    return Container(
      decoration: _cardDecoration,
      padding: const EdgeInsets.all(1),
      clipBehavior: Clip.antiAlias,
      child: width >= LibraryTableColumns.minTableWidth
          ? table
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: table,
            ),
    );
  }
}

/// Search (320, full width below 640) · All / Downloaded / Unread · sort.
class _Toolbar extends ConsumerWidget {
  const _Toolbar({
    required this.search,
    required this.searchFocus,
    required this.onSearchChanged,
    required this.view,
    required this.localOnly,
  });

  final TextEditingController search;
  final FocusNode searchFocus;
  final ValueChanged<String> onSearchChanged;
  final LibraryViewState view;

  /// Offline-only builds and guests: no "Downloaded" filter.
  final bool localOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final ctrl = ref.read(libraryViewProvider.notifier);
    String sortLabel(PaperSort s) => switch (s) {
      PaperSort.recentlyOpened => l10n.librarySortRecentlyOpened,
      PaperSort.recentlyAdded => l10n.librarySortRecentlyAdded,
      PaperSort.title => l10n.librarySortTitle,
    };
    final field = PaperSearchField(
      fieldKey: LibraryScreen.searchFieldKey,
      controller: search,
      focusNode: searchFocus,
      hintText: l10n.librarySearchHint,
      clearTooltip: l10n.librarySearchClear,
      onChanged: onSearchChanged,
    );
    final filter = PaperSegmented<LibraryFilter>(
      segments: <PaperSegment<LibraryFilter>>[
        for (final f in LibraryFilter.values)
          if (!localOnly || f != LibraryFilter.downloaded)
            PaperSegment<LibraryFilter>(
              key: ValueKey<String>('filter-${f.name}'),
              value: f,
              label: switch (f) {
                LibraryFilter.all => l10n.libraryFilterAll,
                LibraryFilter.downloaded => l10n.libraryFilterDownloaded,
                LibraryFilter.unread => l10n.libraryFilterUnread,
              },
            ),
      ],
      selected: view.filter,
      onChanged: ctrl.setFilter,
    );
    final sort = MenuAnchor(
      alignmentOffset: const Offset(0, 4),
      menuChildren: <Widget>[
        for (final s in PaperSort.values)
          PaperMenuItem(
            label: sortLabel(s),
            selected: s == view.sort,
            onPressed: () => ctrl.setSort(s),
          ),
      ],
      builder: (context, controller, _) => PaperButton.ghost(
        key: const ValueKey<String>('library-sort'),
        label: sortLabel(view.sort),
        open: controller.isOpen,
        tooltip: l10n.librarySortLabel,
        trailing: const PaperIcon(PaperIcons.chevronDown),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
    if (!WebBreakpoint.of(context).isSmUp) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          field,
          const SizedBox(height: PaperSpacing.tw2),
          Row(
            children: <Widget>[
              Flexible(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: filter,
                ),
              ),
              const Spacer(),
              sort,
            ],
          ),
        ],
      );
    }
    return Row(
      children: <Widget>[
        SizedBox(width: 320, child: field),
        const SizedBox(width: PaperSpacing.tw3),
        filter,
        const Spacer(),
        sort,
      ],
    );
  }
}

TextStyle? _sm(BuildContext context, Color color) =>
    Theme.of(context).textTheme.bodyMedium?.copyWith(color: color);

Color _toneColor(_Tone tone) => switch (tone) {
  _Tone.neutral => PaperWeb.gray400,
  _Tone.success => PaperWeb.green400,
  _Tone.error => PaperWeb.red400,
};

/// A `min-h-5` status line (`sm`): neutral / success / error.
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.status});

  final _Status? status;

  @override
  Widget build(BuildContext context) {
    final s = status;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 20),
      child: s == null
          ? const SizedBox()
          : Semantics(
              liveRegion: true,
              child: Text(s.text, style: _sm(context, _toneColor(s.tone))),
            ),
    );
  }
}

/// "From a file" card: `PaperFilePickerButton` + file name, status line.
class _FileCard extends StatelessWidget {
  const _FileCard({
    required this.fileName,
    required this.status,
    required this.focusNode,
    required this.onChoose,
  });

  final String? fileName;
  final _Status? status;
  final FocusNode focusNode;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.importFromFile,
            style: PaperTypography.cardTitle(PaperColors.dark),
          ),
          const SizedBox(height: PaperSpacing.tw4),
          Row(
            children: <Widget>[
              _FilePickerButton(
                label: l10n.importChooseFile,
                focusNode: focusNode,
                onPressed: onChoose,
              ),
              const SizedBox(width: PaperSpacing.tw3),
              Flexible(
                child: Text(
                  fileName ?? l10n.importNoFileChosen,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _sm(context, PaperWeb.gray400),
                ),
              ),
            ],
          ),
          const SizedBox(height: PaperSpacing.tw4),
          _StatusLine(status: status),
        ],
      ),
    );
  }
}

/// `PaperFilePickerButton` (components.md §4.3): gray-800 fill, 32 tall,
/// radius 6, `sm 500 gray-200`; hover gray-700; focus ring, no offset.
class _FilePickerButton extends StatelessWidget {
  const _FilePickerButton({
    required this.label,
    required this.onPressed,
    required this.focusNode,
  });

  final String label;
  final VoidCallback? onPressed;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) => PaperPressable(
    key: LibraryScreen.chooseFileKey,
    onPressed: onPressed,
    focusNode: focusNode,
    builder: (context, states) {
      final hot =
          states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.pressed);
      return Opacity(
        opacity: states.contains(WidgetState.disabled) ? 0.5 : 1,
        child: PaperFocusRing(
          show: states.contains(WidgetState.focused),
          radius: PaperRadii.borderMd,
          offset: 0,
          child: PaperColorBox(
            color: hot ? PaperWeb.gray700 : PaperWeb.gray800,
            radius: PaperRadii.borderMd,
            constraints: const BoxConstraints.tightFor(height: 32),
            padding: const EdgeInsets.symmetric(horizontal: PaperSpacing.tw3),
            alignment: Alignment.center,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: PaperWeb.gray200),
            ),
          ),
        ),
      );
    },
  );
}

/// "From a link" card: label + field, Add + inline status; disabled with
/// a reason while offline.
class _LinkCard extends StatelessWidget {
  const _LinkCard({
    required this.controller,
    required this.focusNode,
    required this.online,
    required this.busy,
    required this.status,
    required this.onChanged,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool online;
  final bool busy;
  final _Status? status;
  final VoidCallback onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final enabled = online && !busy;
    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.importUrlDialogTitle,
            style: PaperTypography.cardTitle(PaperColors.dark),
          ),
          const SizedBox(height: PaperSpacing.tw4),
          PaperTextField(
            fieldKey: const ValueKey<String>('import-url-field'),
            controller: controller,
            focusNode: focusNode,
            label: l10n.importUrlFieldLabel,
            enabled: online,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.go,
            autocorrect: false,
            onChanged: (_) => onChanged(),
            onSubmitted: (_) {
              if (enabled) onSubmit();
            },
          ),
          if (!online) ...<Widget>[
            const SizedBox(height: PaperSpacing.tw2),
            Text(
              l10n.importOfflineUrl,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: PaperWeb.gray400),
            ),
          ],
          const SizedBox(height: PaperSpacing.tw4),
          Row(
            children: <Widget>[
              PaperButton.primary(
                key: const ValueKey<String>('import-url-submit'),
                label: l10n.importUrlSubmit,
                focusGap: PaperWeb.gray900,
                onPressed: enabled ? onSubmit : null,
              ),
              const SizedBox(width: PaperSpacing.tw3),
              Expanded(child: _StatusLine(status: status)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Guests: the link card explains that import by link needs an account.
class _GuestLinkCard extends StatelessWidget {
  const _GuestLinkCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PaperCard(
      child: Semantics(
        key: SignInPrompt.keyFor(GuestFeature.importLink),
        container: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.guestImportLinkTitle,
              style: PaperTypography.cardTitle(PaperColors.dark),
            ),
            const SizedBox(height: PaperSpacing.tw2),
            Text(
              l10n.guestImportLinkBody,
              style: _sm(context, PaperWeb.gray400),
            ),
            const SizedBox(height: PaperSpacing.tw4),
            PaperButton.primary(
              key: SignInPrompt.buttonKey,
              label: l10n.commonSignIn,
              focusGap: PaperWeb.gray900,
              onPressed: () => unawaited(openSignIn(context)),
            ),
          ],
        ),
      ),
    );
  }
}

/// `EmptyStateCard` (page level, components.md §17), with the add trigger
/// as its action.
class _EmptyLibraryCard extends StatelessWidget {
  const _EmptyLibraryCard({required this.fileOnly, required this.trigger});

  final bool fileOnly;
  final Widget trigger;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final desktop = <TargetPlatform>{
      TargetPlatform.windows,
      TargetPlatform.macOS,
      TargetPlatform.linux,
    }.contains(Theme.of(context).platform);
    return PaperCard(
      padding: const EdgeInsets.all(PaperSpacing.tw8),
      child: Column(
        children: <Widget>[
          Text(
            l10n.libraryEmptyTitle,
            textAlign: TextAlign.center,
            style: PaperTypography.cardTitle(PaperColors.dark),
          ),
          const SizedBox(height: PaperSpacing.tw1),
          Text(
            fileOnly ? l10n.libraryEmptyBodyFileOnly : l10n.libraryEmptyBody,
            textAlign: TextAlign.center,
            style: _sm(context, PaperWeb.gray400),
          ),
          const SizedBox(height: PaperSpacing.tw4),
          trigger,
          if (desktop && !kIsWeb) ...<Widget>[
            const SizedBox(height: PaperSpacing.tw2),
            Text(
              l10n.libraryEmptyDropHint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: PaperWeb.gray400),
            ),
          ],
        ],
      ),
    );
  }
}

/// `EmptyStateCard.compact` (no search results / empty filter).
class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({required this.body, required this.action, this.title});

  final String? title;
  final String body;
  final Widget action;

  @override
  Widget build(BuildContext context) => PaperCard(
    padding: const EdgeInsets.all(PaperSpacing.tw8),
    child: Column(
      children: <Widget>[
        if (title != null) ...<Widget>[
          Text(
            title!,
            textAlign: TextAlign.center,
            style: PaperTypography.cardTitle(PaperColors.dark),
          ),
          const SizedBox(height: PaperSpacing.tw1),
        ],
        Text(
          body,
          textAlign: TextAlign.center,
          style: _sm(context, PaperWeb.gray400),
        ),
        const SizedBox(height: PaperSpacing.tw4),
        action,
      ],
    ),
  );
}

/// `ErrorBanner` (components.md §17): red-950 / red-900 / red-300, `p-4`,
/// with a Try again button.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.title,
    required this.body,
    required this.retryLabel,
    required this.onRetry,
  });

  final String title;
  final String body;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(PaperSpacing.tw4),
      decoration: BoxDecoration(
        color: PaperWeb.red950,
        borderRadius: PaperRadii.borderLg,
        border: Border.all(color: PaperWeb.red900),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: PaperWeb.red200),
          ),
          Text(body, style: _sm(context, PaperWeb.red300)),
          const SizedBox(height: PaperSpacing.tw3),
          PaperButton.secondary(
            label: retryLabel,
            size: PaperButtonSize.xs,
            focusGap: PaperWeb.red950,
            onPressed: onRetry,
          ),
        ],
      ),
    ),
  );
}
