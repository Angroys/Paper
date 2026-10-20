import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import '../../ai/ai_providers.dart';
import '../../core/core_providers.dart';
import '../../domain/domain.dart';
import '../reader/reader_controller.dart';

// Per-paper side panel state that must outlive the tab bodies.
//
// The reader opens the panel and emits `ExplainRequestedEvent` /
// `NoteRequestedEvent` in the same turn, before the Explanation / Notes tab
// has ever been built, so these controllers subscribe to
// `ReaderController.events` as soon as the reader route mounts
// (`ReaderRouteHost` keeps them alive) and the tabs render their state.

/// Lifecycle of one `ExplanationCard` (mirrors RPR `SidebarEntry`).
enum ExplanationStatus {
  /// Request in flight.
  pending,

  /// Explanation shown.
  complete,

  /// The call failed; [ExplanationEntry.retryable] drives Retry.
  error,

  /// Offline: waits for a connection (`aiOfflineCardTitle`).
  queued,

  /// Re-explain in flight; the previous text stays visible.
  reexplaining,

  /// AI can't run for a non-offline reason (rejected / not configured /
  /// signed out). The tab shows `AiOfflineState.unavailable`.
  unavailable,
}

/// State of the optional visual aid of a complete card.
enum VisualStatus { none, loading, ready, failed, offline }

@immutable
class ExplanationEntry {
  const ExplanationEntry({
    required this.id,
    required this.request,
    required this.status,
    this.explanation,
    this.highlight,
    this.retryable = true,
    this.reexplainFailed = false,
    this.explainWhenOnline = true,
    this.rating,
    this.visualStatus = VisualStatus.none,
    this.visual,
  });

  final String id;
  final ExplanationRequest request;
  final ExplanationStatus status;
  final Explanation? explanation;
  final Highlight? highlight;
  final bool retryable;

  /// Last re-explain failed; the old text is kept (`aiReexplainFailed`).
  final bool reexplainFailed;

  /// Queued card toggle `aiExplainWhenOnline` (default on).
  final bool explainWhenOnline;
  final int? rating;
  final VisualStatus visualStatus;
  final VisualAid? visual;

  String get term => request.term;

  int? get pageNumber =>
      highlight?.position?.pageNumber ?? highlight?.pageNumber;

  String get normalizedTerm => normalizeExplainTerm(request.term);

  ExplanationEntry copyWith({
    ExplanationStatus? status,
    Explanation? explanation,
    bool? retryable,
    bool? reexplainFailed,
    bool? explainWhenOnline,
    int? rating,
    VisualStatus? visualStatus,
    VisualAid? visual,
  }) => ExplanationEntry(
    id: id,
    request: request,
    status: status ?? this.status,
    explanation: explanation ?? this.explanation,
    highlight: highlight,
    retryable: retryable ?? this.retryable,
    reexplainFailed: reexplainFailed ?? this.reexplainFailed,
    explainWhenOnline: explainWhenOnline ?? this.explainWhenOnline,
    rating: rating ?? this.rating,
    visualStatus: visualStatus ?? this.visualStatus,
    visual: visual ?? this.visual,
  );
}

/// Dedup key for explanation cards (lower-cased, collapsed whitespace).
String normalizeExplainTerm(String term) =>
    term.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

@immutable
class ExplanationStackState {
  const ExplanationStackState({
    this.entries = const <ExplanationEntry>[],
    this.unavailableReason,
  });

  /// Newest first.
  final List<ExplanationEntry> entries;

  /// Set when the API refused for a non-offline reason; the Explanation
  /// tab shows `aiUnavailableTitle` / `aiUnavailableBody` instead of cards.
  final AiUnavailableReason? unavailableReason;

  ExplanationStackState copyWith({
    List<ExplanationEntry>? entries,
    AiUnavailableReason? unavailableReason,
    bool clearUnavailable = false,
  }) => ExplanationStackState(
    entries: entries ?? this.entries,
    unavailableReason: clearUnavailable
        ? null
        : (unavailableReason ?? this.unavailableReason),
  );
}

/// The Explanation tab's newest-first card stack for one paper.
class ExplanationStackController extends Notifier<ExplanationStackState> {
  ExplanationStackController(this.paperId);

  final String paperId;
  int _serial = 0;

  @override
  ExplanationStackState build() {
    final reader = ref.watch(readerControllerProvider(paperId).notifier);
    final sub = reader.events.listen((event) {
      if (event is ExplainRequestedEvent) {
        unawaited(
          explain(
            ExplanationRequest(
              term: event.term,
              contextBefore: event.contextBefore,
              contextAfter: event.contextAfter,
              paperTitle: ref
                  .read(readerControllerProvider(paperId))
                  .paper
                  ?.title,
              paperId: paperId,
              highlightId: event.highlight?.id,
            ),
            highlight: event.highlight,
          ),
        );
      }
    });
    ref.onDispose(sub.cancel);
    ref.listen<AsyncValue<bool>>(isOnlineProvider, (prev, next) {
      if (next.value == true && prev?.value == false) {
        unawaited(runQueued());
      }
    });
    return const ExplanationStackState();
  }

  AiService get _ai => ref.read(aiServiceProvider);

  bool get _online => ref.read(connectivityServiceProvider).isOnline;

  ExplanationEntry? _entry(String id) =>
      state.entries.where((e) => e.id == id).firstOrNull;

  void _replace(String id, ExplanationEntry Function(ExplanationEntry) f) {
    if (!ref.mounted) return;
    state = state.copyWith(
      entries: <ExplanationEntry>[
        for (final e in state.entries) e.id == id ? f(e) : e,
      ],
    );
  }

  /// Explains [request]. A term already in the stack moves to the top
  /// (RPR dedup rule); failed / queued ones run again.
  Future<void> explain(
    ExplanationRequest request, {
    Highlight? highlight,
  }) async {
    final key = normalizeExplainTerm(request.term);
    final existing = state.entries
        .where((e) => e.normalizedTerm == key)
        .firstOrNull;
    if (existing != null) {
      state = state.copyWith(
        entries: <ExplanationEntry>[
          existing,
          ...state.entries.where((e) => e.id != existing.id),
        ],
      );
      if (existing.status == ExplanationStatus.error ||
          existing.status == ExplanationStatus.queued ||
          existing.status == ExplanationStatus.unavailable) {
        await _run(existing.id);
      }
      return;
    }
    final entry = ExplanationEntry(
      id: 'explanation-${++_serial}',
      request: request,
      highlight: highlight,
      status: ExplanationStatus.pending,
    );
    state = state.copyWith(
      entries: <ExplanationEntry>[entry, ...state.entries],
    );
    await _run(entry.id);
  }

  Future<void> retry(String id) => _run(id);

  /// AiOfflineState "unavailable" Retry: clears the block and re-runs every
  /// card that hit it.
  Future<void> retryUnavailable() async {
    state = state.copyWith(clearUnavailable: true);
    final ids = state.entries
        .where((e) => e.status == ExplanationStatus.unavailable)
        .map((e) => e.id)
        .toList();
    for (final id in ids) {
      await _run(id);
    }
  }

  /// Queued cards with "Explain when online" on run on reconnect.
  Future<void> runQueued() async {
    final ids = state.entries
        .where(
          (e) => e.status == ExplanationStatus.queued && e.explainWhenOnline,
        )
        .map((e) => e.id)
        .toList();
    for (final id in ids) {
      await _run(id);
    }
  }

  void setExplainWhenOnline(String id, bool on) =>
      _replace(id, (e) => e.copyWith(explainWhenOnline: on));

  Future<void> _run(String id) async {
    final entry = _entry(id);
    if (entry == null) return;
    if (!_online) {
      await _queueOrCache(id);
      return;
    }
    _replace(id, (e) => e.copyWith(status: ExplanationStatus.pending));
    final result = await _ai.explain(entry.request);
    if (!ref.mounted) return;
    switch (result) {
      case AiSuccess(:final value):
        _replace(
          id,
          (e) => e.copyWith(
            status: ExplanationStatus.complete,
            explanation: value,
            reexplainFailed: false,
          ),
        );
        // The term was filed in the glossary: refresh the Glossary tab.
        ref.invalidate(glossaryProvider(paperId));
      case AiUnavailable(reason: AiUnavailableReason.offline):
        await _queueOrCache(id);
      case AiUnavailable(:final reason):
        _replace(id, (e) => e.copyWith(status: ExplanationStatus.unavailable));
        state = state.copyWith(unavailableReason: reason);
      case AiFailure(:final retryable):
        _replace(
          id,
          (e) =>
              e.copyWith(status: ExplanationStatus.error, retryable: retryable),
        );
    }
  }

  Future<void> _queueOrCache(String id) async {
    final entry = _entry(id);
    if (entry == null) return;
    final cached = await _ai.cachedExplanation(entry.term);
    if (!ref.mounted) return;
    if (cached != null) {
      _replace(
        id,
        (e) =>
            e.copyWith(status: ExplanationStatus.complete, explanation: cached),
      );
    } else {
      _replace(id, (e) => e.copyWith(status: ExplanationStatus.queued));
    }
  }

  /// "Re-explain for this paper". Keeps the old text while running; on
  /// failure the old text returns with `aiReexplainFailed`.
  Future<void> reexplain(String id) async {
    final entry = _entry(id);
    final termId = entry?.explanation?.glossaryTermId;
    if (entry == null || termId == null) return;
    _replace(
      id,
      (e) => e.copyWith(
        status: ExplanationStatus.reexplaining,
        reexplainFailed: false,
      ),
    );
    final result = await _ai.reexplain(termId);
    if (!ref.mounted) return;
    switch (result) {
      case AiSuccess(:final value):
        _replace(
          id,
          (e) => e.copyWith(
            status: ExplanationStatus.complete,
            explanation: value,
          ),
        );
        ref.invalidate(glossaryProvider(paperId));
      case AiUnavailable(reason: AiUnavailableReason.offline):
      case AiFailure():
        _replace(
          id,
          (e) => e.copyWith(
            status: ExplanationStatus.complete,
            reexplainFailed: true,
          ),
        );
      case AiUnavailable(:final reason):
        _replace(id, (e) => e.copyWith(status: ExplanationStatus.complete));
        state = state.copyWith(unavailableReason: reason);
    }
  }

  /// 1–5 stars on the card's glossary term.
  Future<void> rate(String id, int stars) async {
    final termId = _entry(id)?.explanation?.glossaryTermId;
    if (termId == null) return;
    _replace(id, (e) => e.copyWith(rating: stars));
    final result = await _ai.rateGlossaryTerm(termId, stars);
    if (result is AiSuccess<GlossaryTerm>) {
      ref.invalidate(glossaryProvider(paperId));
    }
  }

  /// Visual aid (online only; polling happens in the service).
  Future<void> requestVisual(String id) async {
    final entry = _entry(id);
    if (entry == null) return;
    _replace(id, (e) => e.copyWith(visualStatus: VisualStatus.loading));
    final result = await _ai.visual(entry.request);
    if (!ref.mounted) return;
    switch (result) {
      case AiSuccess(:final value):
        _replace(
          id,
          (e) => e.copyWith(visualStatus: VisualStatus.ready, visual: value),
        );
      case AiUnavailable(reason: AiUnavailableReason.offline):
        _replace(id, (e) => e.copyWith(visualStatus: VisualStatus.offline));
      case AiUnavailable():
      case AiFailure():
        // Falls back to the text explanation only (components.md).
        _replace(id, (e) => e.copyWith(visualStatus: VisualStatus.failed));
    }
  }
}

final explanationStackProvider = NotifierProvider.autoDispose
    .family<ExplanationStackController, ExplanationStackState, String>(
      ExplanationStackController.new,
    );

/// The paper's glossary as an [AiResult] (server, falling back to the
/// local cache inside the service).
class GlossaryController extends AsyncNotifier<AiResult<List<GlossaryTerm>>> {
  GlossaryController(this.paperId);

  final String paperId;

  @override
  Future<AiResult<List<GlossaryTerm>>> build() =>
      ref.watch(aiServiceProvider).glossary(paperId);

  AiService get _ai => ref.read(aiServiceProvider);

  void _updateTerm(GlossaryTerm term) {
    final current = state.value;
    if (current is! AiSuccess<List<GlossaryTerm>>) return;
    state = AsyncData<AiResult<List<GlossaryTerm>>>(
      AiSuccess<List<GlossaryTerm>>(<GlossaryTerm>[
        for (final t in current.value) t.id == term.id ? term : t,
      ]),
    );
  }

  /// Rates [term] 1..5. Returns the result so the tile can react.
  Future<AiResult<GlossaryTerm>> rate(GlossaryTerm term, int stars) async {
    final result = await _ai.rateGlossaryTerm(term.id, stars);
    if (!ref.mounted) return result;
    if (result case AiSuccess(:final value)) _updateTerm(value);
    return result;
  }

  /// Re-explains [term] for this paper and stores the new text.
  Future<AiResult<Explanation>> reexplain(GlossaryTerm term) async {
    final result = await _ai.reexplain(term.id);
    if (!ref.mounted) return result;
    if (result case AiSuccess(:final value)) {
      _updateTerm(
        GlossaryTerm(
          id: term.id,
          userId: term.userId,
          paperId: term.paperId,
          highlightId: term.highlightId,
          term: term.term,
          normalizedTerm: term.normalizedTerm,
          explanation: value.explanation,
          tags: term.tags,
          rating: term.rating,
          createdAt: term.createdAt,
        ),
      );
    }
    return result;
  }
}

final glossaryProvider = AsyncNotifierProvider.autoDispose
    .family<GlossaryController, AiResult<List<GlossaryTerm>>, String>(
      GlossaryController.new,
    );

/// The highlight a `NoteRequestedEvent` asked a note for, until the Notes
/// tab consumes it.
class NoteRequestController extends Notifier<Highlight?> {
  NoteRequestController(this.paperId);

  final String paperId;

  @override
  Highlight? build() {
    final reader = ref.watch(readerControllerProvider(paperId).notifier);
    final sub = reader.events.listen((event) {
      if (event is NoteRequestedEvent && ref.mounted) state = event.highlight;
    });
    ref.onDispose(sub.cancel);
    return null;
  }

  Highlight? take() {
    final h = state;
    if (h != null) state = null;
    return h;
  }
}

final noteRequestProvider = NotifierProvider.autoDispose
    .family<NoteRequestController, Highlight?, String>(
      NoteRequestController.new,
    );
