import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import '../../data/data_providers.dart';
import '../../domain/domain.dart';

/// Search debounce (library.md: as-you-type, 150 ms).
const Duration kLibrarySearchDebounce = Duration(milliseconds: 150);

enum LibraryFilter { all, downloaded, unread }

enum LibraryViewMode { grid, list }

/// Search / sort / filter / view choices of the Library screen.
@immutable
class LibraryViewState {
  const LibraryViewState({
    this.query = '',
    this.sort = PaperSort.recentlyOpened,
    this.filter = LibraryFilter.all,
    this.viewOverride,
  });

  final String query;
  final PaperSort sort;
  final LibraryFilter filter;

  /// Set once the user picks grid / list; null = adaptive default.
  final LibraryViewMode? viewOverride;

  LibraryViewState copyWith({
    String? query,
    PaperSort? sort,
    LibraryFilter? filter,
    LibraryViewMode? viewOverride,
  }) => LibraryViewState(
    query: query ?? this.query,
    sort: sort ?? this.sort,
    filter: filter ?? this.filter,
    viewOverride: viewOverride ?? this.viewOverride,
  );
}

class LibraryViewController extends Notifier<LibraryViewState> {
  @override
  LibraryViewState build() => const LibraryViewState();

  void setQuery(String query) => state = state.copyWith(query: query);
  void setSort(PaperSort sort) => state = state.copyWith(sort: sort);
  void setFilter(LibraryFilter filter) =>
      state = state.copyWith(filter: filter);
  void setView(LibraryViewMode mode) =>
      state = state.copyWith(viewOverride: mode);
}

final libraryViewProvider =
    NotifierProvider<LibraryViewController, LibraryViewState>(
      LibraryViewController.new,
    );

/// Library rows for a (query, sort), local DB first.
final libraryPapersProvider = StreamProvider.autoDispose
    .family<List<Paper>, (String, PaperSort)>(
      (ref, key) => ref
          .watch(paperRepositoryProvider)
          .watchPapers(query: key.$1, sort: key.$2),
    );

/// Applies the filter chips (local, instant).
List<Paper> applyLibraryFilter(List<Paper> papers, LibraryFilter filter) =>
    switch (filter) {
      LibraryFilter.all => papers,
      LibraryFilter.downloaded =>
        papers
            .where((p) => p.downloadState == DownloadState.downloaded)
            .toList(),
      LibraryFilter.unread =>
        papers.where((p) => p.lastOpenedAt == null && !p.isRead).toList(),
    };

/// A file the user picked.
@immutable
class PickedPdf {
  const PickedPdf({required this.path, required this.name});
  final String path;
  final String name;
}

/// Native PDF picker (PDF filter only). Overridden in tests.
final pdfPickerProvider = Provider<Future<List<PickedPdf>> Function()>(
  (ref) => () async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['pdf'],
    );
    return <PickedPdf>[
      for (final f in files)
        if (f.path != null) PickedPdf(path: f.path!, name: f.name),
    ];
  },
);

enum ImportSource { url, file }

/// One `ImportProgressTile`.
@immutable
class ImportJob {
  const ImportJob({
    required this.id,
    required this.source,
    required this.label,
    this.error,
  });

  final int id;
  final ImportSource source;

  /// URL or file name.
  final String label;

  /// Null while running; the failure otherwise.
  final Object? error;

  bool get failed => error != null;
}

/// Running / failed imports and in-flight downloads.
@immutable
class LibraryActivity {
  const LibraryActivity({
    this.imports = const <ImportJob>[],
    this.downloads = const <String, double>{},
    this.failedDownloads = const <String>{},
  });

  final List<ImportJob> imports;

  /// paperId → 0..1.
  final Map<String, double> downloads;
  final Set<String> failedDownloads;
}

class LibraryActivityController extends Notifier<LibraryActivity> {
  int _serial = 0;
  final Map<int, Future<Paper> Function()> _retries =
      <int, Future<Paper> Function()>{};

  @override
  LibraryActivity build() => const LibraryActivity();

  PaperRepository get _repo => ref.read(paperRepositoryProvider);

  void _set({
    List<ImportJob>? imports,
    Map<String, double>? downloads,
    Set<String>? failedDownloads,
  }) {
    if (!ref.mounted) return;
    state = LibraryActivity(
      imports: imports ?? state.imports,
      downloads: downloads ?? state.downloads,
      failedDownloads: failedDownloads ?? state.failedDownloads,
    );
  }

  Future<Paper?> importFromUrl(Uri url) =>
      _import(ImportSource.url, url.toString(), () => _repo.importFromUrl(url));

  Future<Paper?> importFile(PickedPdf file) => _import(
    ImportSource.file,
    file.name,
    () => _repo.importFile(file.path, fileName: file.name),
  );

  Future<Paper?> _import(
    ImportSource source,
    String label,
    Future<Paper> Function() run, {
    int? reuseId,
  }) async {
    final id = reuseId ?? ++_serial;
    _retries[id] = run;
    final job = ImportJob(id: id, source: source, label: label);
    _set(imports: <ImportJob>[job, ...state.imports.where((j) => j.id != id)]);
    try {
      final paper = await run();
      _retries.remove(id);
      _set(imports: state.imports.where((j) => j.id != id).toList());
      return paper;
    } on Object catch (e) {
      _set(
        imports: <ImportJob>[
          for (final j in state.imports)
            j.id == id
                ? ImportJob(id: id, source: source, label: label, error: e)
                : j,
        ],
      );
      return null;
    }
  }

  Future<Paper?> retryImport(int jobId) async {
    final job = state.imports.where((j) => j.id == jobId).firstOrNull;
    final run = _retries[jobId];
    if (job == null || run == null) return null;
    return _import(job.source, job.label, run, reuseId: jobId);
  }

  void dismissImport(int jobId) {
    _retries.remove(jobId);
    _set(imports: state.imports.where((j) => j.id != jobId).toList());
  }

  /// "Download for offline".
  Future<void> download(String paperId) async {
    _set(
      downloads: <String, double>{...state.downloads, paperId: 0},
      failedDownloads: <String>{...state.failedDownloads}..remove(paperId),
    );
    try {
      await _repo.ensureLocalFile(
        paperId,
        onProgress: (p) =>
            _set(downloads: <String, double>{...state.downloads, paperId: p}),
      );
      _set(downloads: <String, double>{...state.downloads}..remove(paperId));
    } on Object {
      _set(
        downloads: <String, double>{...state.downloads}..remove(paperId),
        failedDownloads: <String>{...state.failedDownloads, paperId},
      );
    }
  }

  Future<void> removeDownload(String paperId) => _repo.removeDownload(paperId);
}

final libraryActivityProvider =
    NotifierProvider<LibraryActivityController, LibraryActivity>(
      LibraryActivityController.new,
    );
