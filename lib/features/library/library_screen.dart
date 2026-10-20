import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app/app_commands.dart';
import '../../app/app_shell.dart';
import '../../app/routes.dart';
import '../../core/core_providers.dart';
import '../../data/data_providers.dart';
import '../../domain/domain.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/motion_extras.dart';
import '../../theme/paper_tokens.dart';
import '../../theme/theme_x.dart';
import '../panel/ai_states.dart' show InlineError;
import '../sync/sync_sheet.dart';
import 'library_controller.dart';
import 'library_widgets.dart';

/// Library (screens/library.md): search (debounced), sort, filters,
/// adaptive grid / list, import by link or file, rename, delete with undo,
/// download / remove download, and the empty / offline / loading states.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  static const Key searchFieldKey = Key('library.search');
  static const Key gridKey = Key('library.grid');
  static const Key listKey = Key('library.list');
  static const Key importButtonKey = Key('library.import');

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

/// Grid columns per window class (library.md: medium 3, expanded 4–5,
/// extraLarge 6; auto-fill by min card width).
int libraryGridColumns(PaperWindowClass wc, double width) => switch (wc) {
  PaperWindowClass.compact => 2,
  PaperWindowClass.medium => 3,
  PaperWindowClass.expanded => (width / 196).floor().clamp(4, 5),
  PaperWindowClass.large => (width / 200).floor().clamp(4, 6),
  PaperWindowClass.extraLarge => 6,
};

/// List is the default on large+ with a pointer (desktop); grid on touch.
bool libraryDefaultsToList(PaperWindowClass wc, TargetPlatform platform) =>
    wc.usesSidebar &&
    (platform == TargetPlatform.windows ||
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.linux);

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final MenuController _importMenu = MenuController();
  Timer? _debounce;

  /// Last (query, count) announced as `librarySearchResultCount`.
  (String, int)? _announced;

  /// Last loaded rows: shown while the next search query loads, so typing
  /// never flashes the skeleton (results change instantly, motion #21).
  List<Paper>? _lastPapers;

  /// Grid ↔ list crossfade key (unique per toggle).
  bool? _lastList;
  int _viewSerial = 0;

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
          unawaited(_importUrl());
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
    super.dispose();
  }

  bool get _online => ref.read(isOnlineProvider).value ?? true;

  void _onSearchChanged(String value) {
    setState(() {}); // clear button
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
    setState(() {});
  }

  void _snack(String text, {SnackBarAction? action, Duration? duration}) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          action: action,
          duration: duration ?? const Duration(seconds: 5),
        ),
      );
  }

  // ---------------------------------------------------------------- Actions

  void _open(Paper paper) {
    final l10n = AppLocalizations.of(context);
    if (paper.downloadState != DownloadState.downloaded && !_online) {
      _snack(l10n.readerUnavailableOffline);
      return;
    }
    unawaited(GoRouter.maybeOf(context)?.push(AppRoutes.reader(paper.id)));
  }

  Future<void> _rename(Paper paper) async {
    final title = await showRenameDialog(context, paper.title);
    if (title == null || title == paper.title) return;
    await ref.read(paperRepositoryProvider).rename(paper.id, title);
  }

  Future<void> _delete(Paper paper) async {
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(paperRepositoryProvider);
    try {
      await repo.delete(paper.id);
    } on Object {
      if (mounted) {
        _snack(
          l10n.libraryDeleteFailed(paper.title),
          action: SnackBarAction(
            label: l10n.commonRetry,
            onPressed: () => unawaited(_delete(paper)),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    // PaperRepository keeps a 10 s undo window; the snackbar shows for 8 s.
    _snack(
      l10n.libraryDeletedUndo(paper.title),
      duration: kUndoSnackbarDurationLibraryDelete,
      action: SnackBarAction(
        label: l10n.undo,
        onPressed: () => unawaited(repo.undoDelete(paper.id)),
      ),
    );
  }

  void _badgeTap(Paper paper, PaperDownloadBadge state) {
    final activity = ref.read(libraryActivityProvider.notifier);
    switch (state) {
      case PaperDownloadBadge.cloudOnly:
      case PaperDownloadBadge.failed:
        unawaited(activity.download(paper.id));
      case PaperDownloadBadge.unavailableOffline:
        _snack(AppLocalizations.of(context).readerUnavailableOffline);
      case PaperDownloadBadge.pendingUpload:
        unawaited(showSyncSheet(context));
      case PaperDownloadBadge.availableOffline:
      case PaperDownloadBadge.downloading:
        break;
    }
  }

  late final PaperActions _actions = PaperActions(
    open: _open,
    rename: (p) => unawaited(_rename(p)),
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
    final activity = ref.read(libraryActivityProvider.notifier);
    var added = 0;
    Paper? last;
    for (final f in files) {
      final paper = await activity.importFile(f);
      if (paper != null) {
        added++;
        last = paper;
      }
    }
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    if (files.length > 1) {
      _snack(l10n.importBatchSummary(added, files.length - added));
    } else if (last != null) {
      final opened = last;
      _snack(
        l10n.importSuccess,
        action: SnackBarAction(
          label: l10n.commonOpen,
          onPressed: () => _open(opened),
        ),
      );
    }
  }

  Future<void> _importUrl() async {
    final url = await showImportUrlDialog(context, online: _online);
    if (url == null || !mounted) return;
    final paper = await ref
        .read(libraryActivityProvider.notifier)
        .importFromUrl(url);
    if (paper == null || !mounted) return;
    final l10n = AppLocalizations.of(context);
    _snack(
      l10n.importSuccess,
      action: SnackBarAction(
        label: l10n.commonOpen,
        onPressed: () => _open(paper),
      ),
    );
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

  // ------------------------------------------------------------------ Build

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.paper;
    final view = ref.watch(libraryViewProvider);
    final activity = ref.watch(libraryActivityProvider);
    final online = ref.watch(isOnlineProvider).value ?? true;
    final async = ref.watch(libraryPapersProvider((view.query, view.sort)));

    return LayoutBuilder(
      builder: (context, constraints) {
        final wc = PaperWindowClass.of(constraints.maxWidth);
        final margin = PaperSpacing.margin(wc);
        final compact = wc == PaperWindowClass.compact;
        final contentWidth =
            (wc == PaperWindowClass.extraLarge
                ? constraints.maxWidth.clamp(0, 1440).toDouble()
                : constraints.maxWidth) -
            2 * margin;
        final list =
            (view.viewOverride ??
                (libraryDefaultsToList(wc, Theme.of(context).platform)
                    ? LibraryViewMode.list
                    : LibraryViewMode.grid)) ==
            LibraryViewMode.list;
        final columns = libraryGridColumns(wc, contentWidth);

        final header = _Header(
          compact: compact,
          search: _search,
          searchFocus: _searchFocus,
          onSearchChanged: _onSearchChanged,
          onClearSearch: _clearSearch,
          importMenu: _importMenu,
          online: online,
          onImportFile: () => unawaited(_importFile()),
          onImportUrl: () => unawaited(_importUrl()),
          list: list,
        );

        if (_lastList != null && _lastList != list) _viewSerial++;
        _lastList = list;
        final loaded = async.value ?? _lastPapers;
        if (async.hasValue) _lastPapers = async.value;

        Widget content;
        if (async.hasError && loaded == null) {
          content = Align(
            alignment: Alignment.topCenter,
            child: InlineError(
              title: l10n.libraryLoadFailedTitle,
              message: l10n.libraryLoadFailedBody,
              onRetry: () {
                unawaited(ref.read(paperRepositoryProvider).refresh());
                ref.invalidate(libraryPapersProvider);
              },
            ),
          );
        } else if (loaded == null) {
          content = LibrarySkeleton(list: list, columns: columns);
        } else {
          final all = loaded;
          final papers = applyLibraryFilter(all, view.filter);
          if (all.isEmpty && view.query.isEmpty) {
            content = _EmptyLibrary(
              online: online,
              onImportFile: () => unawaited(_importFile()),
              onImportUrl: () => unawaited(_importUrl()),
            );
          } else if (all.isEmpty) {
            content = _NoResults(query: view.query, onClear: _clearSearch);
          } else if (papers.isEmpty) {
            content = _FilterEmpty(
              filter: view.filter,
              onShowAll: () => ref
                  .read(libraryViewProvider.notifier)
                  .setFilter(LibraryFilter.all),
            );
          } else {
            content = _PaperCollection(
              papers: papers,
              list: list,
              columns: columns,
              online: online,
              activity: activity,
              actions: _actions,
            );
          }
          final announce = (view.query, papers.length);
          if (view.query.isNotEmpty && announce != _announced) {
            _announced = announce;
            final count = papers.length;
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
        }

        final body = Padding(
          padding: EdgeInsets.symmetric(horizontal: margin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              header,
              _FilterRow(view: view, list: list),
              for (final job in activity.imports)
                Padding(
                  padding: const EdgeInsets.only(bottom: PaperSpacing.sm),
                  child: ImportProgressTile(
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
                ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: PaperMotion.fade(context, PaperMotion.fast),
                  child: KeyedSubtree(
                    key: ValueKey<Object>((_viewSerial, loaded != null)),
                    child: content,
                  ),
                ),
              ),
            ],
          ),
        );

        return Scaffold(
          backgroundColor: c.background,
          floatingActionButton: compact
              ? FloatingActionButton(
                  key: LibraryScreen.importButtonKey,
                  tooltip: l10n.importButton,
                  onPressed: () => unawaited(_showImportSheet(online)),
                  child: const Icon(Symbols.add_rounded),
                )
              : null,
          body: wc == PaperWindowClass.extraLarge
              ? Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1440),
                    child: body,
                  ),
                )
              : body,
        );
      },
    );
  }

  Future<void> _showImportSheet(bool online) async {
    final l10n = AppLocalizations.of(context);
    final choice = await showModalBottomSheet<ImportSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Symbols.description_rounded),
              title: Text(l10n.importFromFile),
              onTap: () => Navigator.of(context).pop(ImportSource.file),
            ),
            ListTile(
              enabled: online,
              leading: const Icon(Symbols.link_rounded),
              title: Text(l10n.importFromUrl),
              subtitle: online ? null : Text(l10n.importOfflineUrl),
              onTap: () => Navigator.of(context).pop(ImportSource.url),
            ),
          ],
        ),
      ),
    );
    switch (choice) {
      case ImportSource.file:
        await _importFile();
      case ImportSource.url:
        await _importUrl();
      case null:
        break;
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.compact,
    required this.search,
    required this.searchFocus,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.importMenu,
    required this.online,
    required this.onImportFile,
    required this.onImportUrl,
    required this.list,
  });

  final bool compact;
  final TextEditingController search;
  final FocusNode searchFocus;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final MenuController importMenu;
  final bool online;
  final VoidCallback onImportFile;
  final VoidCallback onImportUrl;
  final bool list;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.paper;
    final platform = Theme.of(context).platform;
    final apple =
        platform == TargetPlatform.macOS || platform == TargetPlatform.iOS;
    final desktop =
        apple ||
        platform == TargetPlatform.windows ||
        platform == TargetPlatform.linux;

    final title = Semantics(
      header: true,
      child: Text(
        l10n.libraryTitle,
        style: Theme.of(context).textTheme.headlineLarge,
      ),
    );
    final field = TextField(
      key: LibraryScreen.searchFieldKey,
      controller: search,
      focusNode: searchFocus,
      onChanged: onSearchChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        isDense: true,
        hintText: l10n.librarySearchHint,
        prefixIcon: const Icon(Symbols.search_rounded, size: 20),
        suffixIcon: search.text.isNotEmpty
            ? IconButton(
                tooltip: l10n.librarySearchClear,
                onPressed: onClearSearch,
                icon: const Icon(Symbols.close_rounded, size: 18),
              )
            : (desktop
                  ? Padding(
                      padding: const EdgeInsets.only(right: PaperSpacing.sm),
                      child: Center(
                        widthFactor: 1,
                        child: Text(
                          apple ? '⌘K' : 'Ctrl K',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: c.textSecondary),
                        ),
                      ),
                    )
                  : null),
      ),
    );
    final importButton = MenuAnchor(
      controller: importMenu,
      menuChildren: <Widget>[
        MenuItemButton(
          leadingIcon: const Icon(Symbols.description_rounded, size: 20),
          onPressed: onImportFile,
          child: Text(l10n.importFromFile),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Symbols.link_rounded, size: 20),
          onPressed: online ? onImportUrl : null,
          child: online
              ? Text(l10n.importFromUrl)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(l10n.importFromUrl),
                    Text(
                      l10n.importOfflineUrl,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
        ),
      ],
      builder: (context, controller, _) => FilledButton.icon(
        key: LibraryScreen.importButtonKey,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        icon: const Icon(Symbols.add_rounded, size: 20),
        label: Text(l10n.importButton),
      ),
    );

    if (compact) {
      return Padding(
        padding: const EdgeInsets.only(top: PaperSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: title),
                const ShellSyncBadge(),
              ],
            ),
            const SizedBox(height: PaperSpacing.md),
            field,
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: PaperSpacing.xl),
      child: Row(
        children: <Widget>[
          Expanded(child: title),
          SizedBox(width: 340, child: field),
          const SizedBox(width: PaperSpacing.md),
          importButton,
        ],
      ),
    );
  }
}

class _FilterRow extends ConsumerWidget {
  const _FilterRow({required this.view, required this.list});

  final LibraryViewState view;
  final bool list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final ctrl = ref.read(libraryViewProvider.notifier);
    String sortLabel(PaperSort s) => switch (s) {
      PaperSort.recentlyOpened => l10n.librarySortRecentlyOpened,
      PaperSort.recentlyAdded => l10n.librarySortRecentlyAdded,
      PaperSort.title => l10n.librarySortTitle,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: PaperSpacing.md),
      child: Row(
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  for (final f in LibraryFilter.values) ...<Widget>[
                    FilterChip(
                      key: ValueKey<String>('filter-${f.name}'),
                      selected: view.filter == f,
                      showCheckmark: true,
                      label: Text(switch (f) {
                        LibraryFilter.all => l10n.libraryFilterAll,
                        LibraryFilter.downloaded =>
                          l10n.libraryFilterDownloaded,
                        LibraryFilter.unread => l10n.libraryFilterUnread,
                      }),
                      onSelected: (_) => ctrl.setFilter(f),
                    ),
                    const SizedBox(width: PaperSpacing.sm),
                  ],
                ],
              ),
            ),
          ),
          PopupMenuButton<PaperSort>(
            key: const ValueKey<String>('library-sort'),
            tooltip: l10n.librarySortLabel,
            initialValue: view.sort,
            onSelected: ctrl.setSort,
            itemBuilder: (context) => <PopupMenuEntry<PaperSort>>[
              for (final s in PaperSort.values)
                PopupMenuItem(value: s, child: Text(sortLabel(s))),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: PaperSpacing.sm),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Symbols.sort_rounded, size: 20),
                  const SizedBox(width: PaperSpacing.xs),
                  Text(sortLabel(view.sort)),
                ],
              ),
            ),
          ),
          const SizedBox(width: PaperSpacing.sm),
          SegmentedButton<LibraryViewMode>(
            showSelectedIcon: false,
            segments: <ButtonSegment<LibraryViewMode>>[
              ButtonSegment(
                value: LibraryViewMode.grid,
                tooltip: l10n.libraryViewGrid,
                icon: const Icon(Symbols.grid_view_rounded, size: 18),
              ),
              ButtonSegment(
                value: LibraryViewMode.list,
                tooltip: l10n.libraryViewList,
                icon: const Icon(Symbols.view_list_rounded, size: 18),
              ),
            ],
            selected: <LibraryViewMode>{
              list ? LibraryViewMode.list : LibraryViewMode.grid,
            },
            onSelectionChanged: (s) => ctrl.setView(s.first),
          ),
        ],
      ),
    );
  }
}

class _PaperCollection extends StatelessWidget {
  const _PaperCollection({
    required this.papers,
    required this.list,
    required this.columns,
    required this.online,
    required this.activity,
    required this.actions,
  });

  final List<Paper> papers;
  final bool list;
  final int columns;
  final bool online;
  final LibraryActivity activity;
  final PaperActions actions;

  @override
  Widget build(BuildContext context) {
    final c = context.paper;
    PaperDownloadBadge badge(Paper p) => downloadBadgeFor(
      p,
      online: online,
      progress: activity.downloads[p.id],
      failed: activity.failedDownloads.contains(p.id),
    );
    if (list) {
      final pointer = Theme.of(context).platform != TargetPlatform.android;
      return DecoratedBox(
        key: LibraryScreen.listKey,
        decoration: BoxDecoration(
          border: Border.all(color: c.border),
          borderRadius: PaperRadii.borderLg,
        ),
        child: ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: papers.length,
          separatorBuilder: (_, _) => Divider(height: 1, color: c.border),
          itemBuilder: (context, i) => SizedBox(
            height: pointer ? 44 : 56,
            child: PaperRow(
              key: ValueKey<String>('paper-${papers[i].id}'),
              paper: papers[i],
              actions: actions,
              badge: badge(papers[i]),
              progress: activity.downloads[papers[i].id],
            ),
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = PaperSpacing.md;
        final cardWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        final extent = (cardWidth - 28) * 4 / 3 + 104;
        return GridView.builder(
          key: LibraryScreen.gridKey,
          padding: const EdgeInsets.only(bottom: 96),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: gap,
            mainAxisSpacing: PaperSpacing.xl,
            mainAxisExtent: extent,
          ),
          itemCount: papers.length,
          itemBuilder: (context, i) => PaperCard(
            key: ValueKey<String>('paper-${papers[i].id}'),
            paper: papers[i],
            actions: actions,
            badge: badge(papers[i]),
            progress: activity.downloads[papers[i].id],
          ),
        );
      },
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({
    required this.online,
    required this.onImportFile,
    required this.onImportUrl,
  });

  final bool online;
  final VoidCallback onImportFile;
  final VoidCallback onImportUrl;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.paper;
    final t = Theme.of(context).textTheme;
    final desktop = <TargetPlatform>{
      TargetPlatform.windows,
      TargetPlatform.macOS,
      TargetPlatform.linux,
    }.contains(Theme.of(context).platform);
    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Symbols.description_rounded, size: 48, color: c.textMuted),
              const SizedBox(height: PaperSpacing.lg),
              Text(
                l10n.libraryEmptyTitle,
                style: t.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: PaperSpacing.sm),
              Text(
                l10n.libraryEmptyBody,
                style: t.bodyLarge?.copyWith(color: c.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: PaperSpacing.xl),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: PaperSpacing.md,
                runSpacing: PaperSpacing.sm,
                children: <Widget>[
                  FilledButton(
                    onPressed: onImportFile,
                    child: Text(l10n.importFromFile),
                  ),
                  OutlinedButton(
                    onPressed: online ? onImportUrl : null,
                    child: Text(l10n.importFromUrl),
                  ),
                ],
              ),
              if (!online) ...<Widget>[
                const SizedBox(height: PaperSpacing.sm),
                Text(
                  l10n.importOfflineUrl,
                  style: t.bodySmall?.copyWith(color: c.textMuted),
                  textAlign: TextAlign.center,
                ),
              ],
              if (desktop && !kIsWeb) ...<Widget>[
                const SizedBox(height: PaperSpacing.md),
                Text(
                  l10n.libraryEmptyDropHint,
                  style: t.bodySmall?.copyWith(color: c.textMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.query, required this.onClear});

  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.paper;
    final t = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Symbols.search_rounded, size: 32, color: c.textMuted),
          const SizedBox(height: PaperSpacing.md),
          Text(
            l10n.librarySearchNoResultsTitle(query),
            style: t.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: PaperSpacing.xs),
          Text(
            l10n.librarySearchNoResultsBody,
            style: t.bodyMedium?.copyWith(color: c.textSecondary),
          ),
          TextButton(onPressed: onClear, child: Text(l10n.librarySearchClear)),
        ],
      ),
    );
  }
}

class _FilterEmpty extends StatelessWidget {
  const _FilterEmpty({required this.filter, required this.onShowAll});

  final LibraryFilter filter;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.paper;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            filter == LibraryFilter.downloaded
                ? l10n.libraryFilterDownloadedEmpty
                : l10n.libraryFilterUnreadEmpty,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: c.textSecondary),
          ),
          TextButton(onPressed: onShowAll, child: Text(l10n.libraryShowAll)),
        ],
      ),
    );
  }
}
