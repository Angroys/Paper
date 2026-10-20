import 'dart:async';

import 'package:paper/domain/domain.dart';

/// Controllable [AuthRepository].
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository([AuthState initial = const AuthState.signedOut()])
    : _state = initial;

  AuthState _state;
  final _states = StreamController<AuthState>.broadcast();
  final List<String> calls = <String>[];
  final List<Uri> callbacks = <Uri>[];
  Object? failWith;
  bool callbackResult = true;
  bool signUpNeedsConfirmation = true;

  void emit(AuthState state) {
    _state = state;
    _states.add(state);
  }

  Future<void> _gate(String call) async {
    calls.add(call);
    final f = failWith;
    if (f != null) {
      failWith = null;
      throw f;
    }
  }

  @override
  AuthState get currentState => _state;

  @override
  Stream<AuthState> watchAuthState() async* {
    yield _state;
    yield* _states.stream;
  }

  @override
  Future<AuthState> restoreSession() async => _state;

  @override
  Future<void> signInWithGoogle() => _gate('google');

  @override
  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  }) => _gate('email $email');

  @override
  Future<bool> signUpWithEmailPassword({
    required String email,
    required String password,
  }) async {
    await _gate('signUp $email');
    return signUpNeedsConfirmation;
  }

  @override
  Future<void> sendMagicLink(String email) => _gate('magic $email');

  @override
  Future<void> sendPasswordReset(String email) => _gate('reset $email');

  @override
  Future<bool> handleAuthCallback(Uri uri) async {
    callbacks.add(uri);
    return callbackResult;
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    emit(const AuthState.signedOut());
  }

  @override
  Future<String?> accessToken() async => null;
}

const AppUser testUser = AppUser(id: 'u1', email: 'ana@example.com');

/// [AiService] whose answers the test sets.
class FakeAiService implements AiService {
  AiResult<Explanation> Function(ExplanationRequest request)? onExplain;
  AiResult<List<GlossaryTerm>> glossaryResult =
      const AiSuccess<List<GlossaryTerm>>(<GlossaryTerm>[]);
  AiResult<VisualAid> visualResult = const AiFailure<VisualAid>('none');
  Explanation? cached;
  final List<ExplanationRequest> explained = <ExplanationRequest>[];
  final List<(String, int?)> ratings = <(String, int?)>[];

  @override
  AiAvailability get availability => AiAvailability.available;

  @override
  Stream<AiAvailability> watchAvailability() =>
      Stream<AiAvailability>.value(availability);

  @override
  Future<AiResult<Explanation>> explain(ExplanationRequest request) async {
    explained.add(request);
    final f = onExplain;
    if (f != null) return f(request);
    return AiSuccess<Explanation>(
      Explanation(
        term: request.term,
        explanation: 'Plain words for ${request.term}.',
        createdAt: DateTime.utc(2026, 10, 20),
        glossaryTermId: 'g-${request.term}',
      ),
    );
  }

  @override
  Future<AiResult<Explanation>> reexplain(String glossaryTermId) async =>
      AiSuccess<Explanation>(
        Explanation(
          term: glossaryTermId,
          explanation: 'Re-explained.',
          createdAt: DateTime.utc(2026, 10, 20),
          glossaryTermId: glossaryTermId,
        ),
      );

  @override
  Future<AiResult<List<GlossaryTerm>>> glossary(String paperId) async =>
      glossaryResult;

  @override
  Future<AiResult<GlossaryTerm>> rateGlossaryTerm(
    String glossaryTermId,
    int? rating,
  ) async {
    ratings.add((glossaryTermId, rating));
    return const AiFailure<GlossaryTerm>('not stored');
  }

  @override
  Future<AiResult<VisualAid>> visual(ExplanationRequest request) async =>
      visualResult;

  @override
  Future<Explanation?> cachedExplanation(String term) async => cached;
}

/// In-memory [NoteRepository].
class FakeNoteRepository implements NoteRepository {
  final List<Note> notes = <Note>[];
  final _changes = StreamController<void>.broadcast();
  int localOnlyCount = 0;
  String exported = '';

  List<Note> _for(String paperId) =>
      notes.where((n) => n.paperId == paperId).toList();

  @override
  Stream<List<Note>> watchNotes(String paperId) async* {
    yield _for(paperId);
    yield* _changes.stream.map((_) => _for(paperId));
  }

  @override
  Stream<List<Note>> watchNotesForHighlight(String highlightId) async* {
    yield notes.where((n) => n.highlightId == highlightId).toList();
  }

  @override
  Future<Note> upsertNote(Note note) async {
    notes
      ..removeWhere((n) => n.id == note.id)
      ..add(note);
    _changes.add(null);
    return note;
  }

  @override
  Future<void> deleteNote(String noteId) async {
    notes.removeWhere((n) => n.id == noteId);
    _changes.add(null);
  }

  @override
  Future<void> restoreNote(Note note) => upsertNote(note);

  @override
  Future<int> countLocalOnlyNotes() async => localOnlyCount;

  @override
  Future<String> exportAllAsText() async => exported;
}

/// Library-side [PaperRepository]: search, rename, delete/undo, imports.
class FakeLibraryRepository implements PaperRepository {
  FakeLibraryRepository(Iterable<Paper> papers) : papers = papers.toList();

  final List<Paper> papers;
  final _changes = StreamController<void>.broadcast();
  final List<String> calls = <String>[];
  final Set<String> deleted = <String>{};
  Object? importError;
  Paper? importResult;

  void _changed() => _changes.add(null);

  List<Paper> _query(String query) {
    final q = query.toLowerCase();
    return papers
        .where((p) => !deleted.contains(p.id))
        .where((p) => q.isEmpty || p.title.toLowerCase().contains(q))
        .toList();
  }

  @override
  Stream<List<Paper>> watchPapers({
    String query = '',
    PaperSort sort = PaperSort.recentlyOpened,
  }) async* {
    yield _query(query);
    yield* _changes.stream.map((_) => _query(query));
  }

  @override
  Stream<Paper?> watchPaper(String paperId) =>
      Stream<Paper?>.value(papers.where((p) => p.id == paperId).firstOrNull);

  @override
  Future<Paper?> getPaper(String paperId) async =>
      papers.where((p) => p.id == paperId).firstOrNull;

  @override
  Future<void> refresh() async {}

  Future<Paper> _import(String what) async {
    calls.add(what);
    final e = importError;
    if (e != null) throw e;
    final p = importResult!;
    papers.add(p);
    _changed();
    return p;
  }

  @override
  Future<Paper> importFromUrl(Uri url) => _import('url $url');

  @override
  Future<Paper> importFile(String filePath, {String? fileName}) =>
      _import('file $fileName');

  @override
  Future<void> rename(String paperId, String title) async {
    calls.add('rename $paperId $title');
    final i = papers.indexWhere((p) => p.id == paperId);
    papers[i] = papers[i].copyWith(title: title);
    _changed();
  }

  @override
  Future<void> delete(String paperId) async {
    calls.add('delete $paperId');
    deleted.add(paperId);
    _changed();
  }

  @override
  Future<void> undoDelete(String paperId) async {
    calls.add('undo $paperId');
    deleted.remove(paperId);
    _changed();
  }

  @override
  Future<void> setRead(String paperId, {required bool read}) async {}

  @override
  Future<void> dismissMatchNotice(String paperId) async {}

  @override
  Future<String> ensureLocalFile(
    String paperId, {
    void Function(double progress)? onProgress,
  }) async {
    calls.add('download $paperId');
    return '/tmp/$paperId.pdf';
  }

  @override
  Future<void> removeDownload(String paperId) async {
    calls.add('removeDownload $paperId');
  }

  @override
  Future<void> saveReadingPosition(
    String paperId,
    ReadingPosition position,
  ) async {}

  @override
  Future<void> markOpened(String paperId) async {}
}

Paper libraryPaper(
  String id,
  String title, {
  DownloadState download = DownloadState.downloaded,
  SyncState sync = SyncState.synced,
}) => Paper(
  id: id,
  userId: 'u1',
  title: title,
  uploadedAt: DateTime.utc(2026, 10, 1),
  storagePath: 'u1/$id.pdf',
  downloadState: download,
  syncState: sync,
);

/// Controllable [SyncService].
class FakeSyncService implements SyncService {
  FakeSyncService([this._status = SyncStatus.idle]);

  SyncStatus _status;
  final _statuses = StreamController<SyncStatus>.broadcast();
  List<SyncOp> ops = <SyncOp>[];
  List<ReplacedVersion> replaced = <ReplacedVersion>[];
  final List<String> calls = <String>[];

  void emit(SyncStatus status) {
    _status = status;
    _statuses.add(status);
  }

  @override
  SyncStatus get status => _status;

  @override
  Stream<SyncStatus> watchStatus() async* {
    yield _status;
    yield* _statuses.stream;
  }

  @override
  Future<void> start() async => calls.add('start');

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> syncNow() async => calls.add('syncNow');

  @override
  Stream<List<SyncOp>> watchPendingOps() => Stream<List<SyncOp>>.value(ops);

  @override
  Future<void> retryOp(String opId) async => calls.add('retry $opId');

  @override
  Future<void> discardOp(String opId) async => calls.add('discard $opId');

  @override
  Stream<List<ReplacedVersion>> watchReplacedVersions() =>
      Stream<List<ReplacedVersion>>.value(replaced);

  @override
  Future<void> restoreReplaced(String replacedVersionId) async =>
      calls.add('restore $replacedVersionId');

  @override
  Future<void> dismissReplaced(String replacedVersionId) async =>
      calls.add('dismiss $replacedVersionId');
}
