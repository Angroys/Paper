import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:paper/data/data_providers.dart';
import 'package:paper/domain/domain.dart';
import 'package:paper/features/reader/reader_controller.dart';
import 'package:paper/features/reader/reader_viewport.dart';

Paper testPaper({ReadingPosition? position, String id = 'p1'}) => Paper(
  id: id,
  userId: 'u1',
  title: 'Attention Is All You Need',
  uploadedAt: DateTime.utc(2026, 1, 1),
  readingPosition: position,
);

/// In-memory [PaperRepository] for reader tests.
class FakePaperRepository implements PaperRepository {
  FakePaperRepository({this.paper, this.filePath = '/tmp/paper.pdf'});

  Paper? paper;
  String filePath;

  /// When set, [ensureLocalFile] waits for it (to observe the downloading
  /// phase); it reports progress through [lastProgress].
  Completer<String>? download;
  void Function(double)? lastProgress;
  Object? ensureError;
  final List<ReadingPosition> saved = <ReadingPosition>[];
  int opened = 0;

  @override
  Future<Paper?> getPaper(String paperId) async => paper;

  @override
  Future<String> ensureLocalFile(
    String paperId, {
    void Function(double progress)? onProgress,
  }) async {
    final error = ensureError;
    if (error != null) throw error;
    final d = download;
    if (d != null) {
      lastProgress = onProgress;
      return d.future;
    }
    return filePath;
  }

  @override
  Future<void> saveReadingPosition(
    String paperId,
    ReadingPosition position,
  ) async => saved.add(position);

  @override
  Future<void> markOpened(String paperId) async => opened++;

  @override
  Stream<Paper?> watchPaper(String paperId) => Stream<Paper?>.value(paper);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'FakePaperRepository.${invocation.memberName}',
  );
}

/// In-memory [HighlightRepository].
class FakeHighlightRepository implements HighlightRepository {
  final List<Highlight> highlights = <Highlight>[];
  final List<FigureHighlight> figures = <FigureHighlight>[];
  final List<Uint8List> pngs = <Uint8List>[];
  final StreamController<List<Highlight>> _hl =
      StreamController<List<Highlight>>.broadcast();
  bool failCreate = false;

  void _emit() => _hl.add(List<Highlight>.unmodifiable(highlights));

  @override
  Stream<List<Highlight>> watchHighlights(String paperId) async* {
    yield List<Highlight>.unmodifiable(highlights);
    yield* _hl.stream;
  }

  @override
  Future<Highlight> createHighlight(Highlight highlight) async {
    if (failCreate) throw const StorageException('disk full');
    highlights.add(highlight);
    _emit();
    return highlight;
  }

  @override
  Future<void> updateColor(String highlightId, HighlightColor color) async {
    final i = highlights.indexWhere((h) => h.id == highlightId);
    if (i >= 0) highlights[i] = highlights[i].copyWith(color: color);
    _emit();
  }

  @override
  Future<void> deleteHighlight(String highlightId) async {
    highlights.removeWhere((h) => h.id == highlightId);
    _emit();
  }

  @override
  Future<void> restoreHighlight(Highlight highlight) async {
    highlights.add(highlight);
    _emit();
  }

  @override
  Stream<List<FigureHighlight>> watchFigureHighlights(String paperId) =>
      Stream<List<FigureHighlight>>.value(figures);

  @override
  Future<FigureHighlight> createFigureHighlight(
    FigureHighlight figure, {
    required Uint8List pngBytes,
  }) async {
    figures.add(figure);
    pngs.add(pngBytes);
    return figure;
  }

  @override
  Future<void> updateFigureNote(String figureHighlightId, String? note) async {}

  @override
  Future<void> deleteFigureHighlight(String figureHighlightId) async {}
}

/// A timer the test fires by hand.
class ManualTimer implements Timer {
  ManualTimer(this.duration, this.callback);

  final Duration duration;
  final void Function() callback;
  bool _active = true;

  void fire() {
    if (!_active) return;
    _active = false;
    callback();
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
}

class ManualTimers {
  final List<ManualTimer> created = <ManualTimer>[];

  Timer call(Duration d, void Function() cb) {
    final t = ManualTimer(d, cb);
    created.add(t);
    return t;
  }

  List<ManualTimer> get active => created.where((t) => t.isActive).toList();
}

/// Fake viewport: reports the document as loaded with [pageCount] pages.
class FakeViewport extends ConsumerStatefulWidget {
  const FakeViewport({super.key, required this.args, this.pageCount = 10});

  final ReaderViewportArgs args;
  final int pageCount;

  @override
  ConsumerState<FakeViewport> createState() => _FakeViewportState();
}

class _FakeViewportState extends ConsumerState<FakeViewport> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      if (!mounted) return;
      ref
          .read(readerControllerProvider(widget.args.paperId).notifier)
          .documentLoaded(pageCount: widget.pageCount);
    });
  }

  @override
  Widget build(BuildContext context) =>
      const SizedBox.expand(key: ValueKey<String>('fake-viewport'));
}

/// Provider overrides for reader tests.
List<Override> readerTestOverrides({
  required FakePaperRepository papers,
  FakeHighlightRepository? highlights,
  ManualTimers? timers,
  bool fakeViewport = true,
}) => <Override>[
  paperRepositoryProvider.overrideWithValue(papers),
  highlightRepositoryProvider.overrideWithValue(
    highlights ?? FakeHighlightRepository(),
  ),
  if (timers != null) readerTimerFactoryProvider.overrideWithValue(timers.call),
  readerClockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 20, 12)),
  readerIdFactoryProvider.overrideWithValue(_ids()),
  if (fakeViewport)
    readerViewportBuilderProvider.overrideWithValue(
      (context, args) => FakeViewport(args: args),
    ),
];

String Function() _ids() {
  var n = 0;
  return () => 'id-${++n}';
}
