import 'dart:async';
import 'dart:convert';

import '../core/paper_api_client.dart';
import '../data/db/app_database.dart';
import '../domain/domain.dart';
import '../domain/models/json.dart';
import 'glossary_remote.dart';

/// A visual aid answered as a Paper Scene (`sceneJson`, rendered client
/// side by the web app) instead of an image / MP4.
class SceneVisualAid extends VisualAid {
  const SceneVisualAid({required super.term, required this.sceneJson});

  final Map<String, Object?> sceneJson;
}

/// RPR's `normalizeTerm` (src/lib/glossary/dedup.ts) minus NFKC, which
/// Dart core lacks (only matters for ligatures / full-width forms).
String normalizeTerm(String term) => term
    .replaceAll(RegExp(r'\s+', unicode: true), ' ')
    .replaceAll(RegExp(r'^[\s\p{P}\p{S}]+', unicode: true), '')
    .replaceAll(RegExp(r'[\s\p{P}\p{S}]+$', unicode: true), '')
    .toLowerCase();

/// [AiService] over RPR's Next.js AI routes, authenticated with the
/// `@supabase/ssr` session cookie (`PaperApiClient`); RPR accepts no bearer
/// token, and needs no change for this.
///
/// | Call       | Route                                   | Success body |
/// | ---------- | --------------------------------------- | ------------ |
/// | explain    | `POST /api/explain` {term, contextBefore?, contextAfter?, paperTitle?} | 200 `{explanation}` (not streamed) |
/// | reexplain  | `POST /api/glossary/reexplain` {glossaryTermId} | 200 `{glossaryTerm}` |
/// | rate       | `PATCH /api/glossary/<id>` {rating: 1..5 \| null} | 200 `{glossaryTerm}` |
/// | visual     | `POST /api/explain/visual` {term, explanation, ...} | 200 `{status:"ready", videoUrl \| sceneJson}`; `GET ?jobId=` polls 202 `{status:"pending", jobId}` |
/// | glossary   | `glossary_terms` via Supabase (RLS)     | rows |
///
/// Mapping: 401/403 -> [AiUnavailable] `rejected` (visual's 403 = not a
/// beta account); no session -> `signedOut`; network error -> `offline`;
/// 429/5xx/timeouts -> retryable [AiFailure]; other 4xx / 503
/// "unconfigured" -> non-retryable [AiFailure].
///
/// Successful explanations are filed in the paper's glossary (like the web
/// sidebar) and cached in SQLite for [cachedExplanation] offline.
class HttpAiService implements AiService {
  HttpAiService({
    required this._api,
    required GlossaryRemote glossaryRemote,
    required this._db,
    required this._connectivity,
    required AuthState Function() currentAuth,
    required this._authStates,
    DateTime Function()? clock,
    this.visualPollInterval = const Duration(seconds: 3),
    this.visualPollTimeout = const Duration(minutes: 3),
  }) : _glossary = glossaryRemote,
       _auth = currentAuth,
       _now = clock ?? DateTime.now;

  final PaperApiClient _api;
  final GlossaryRemote _glossary;
  final AppDatabase _db;
  final ConnectivityService _connectivity;
  final AuthState Function() _auth;
  final Stream<AuthState> _authStates;
  final DateTime Function() _now;
  final Duration visualPollInterval;
  final Duration visualPollTimeout;

  bool _rejected = false;
  final _rejections = StreamController<void>.broadcast();

  // ------------------------------------------------------------------
  // Availability

  @override
  AiAvailability get availability => _availability(
    online: _connectivity.isOnline,
    signedIn: _auth().isSignedIn,
  );

  AiAvailability _availability({required bool online, required bool signedIn}) {
    if (!online) return AiAvailability.offline;
    if (!signedIn || _rejected) return AiAvailability.unavailable;
    return AiAvailability.available;
  }

  @override
  Stream<AiAvailability> watchAvailability() {
    late StreamController<AiAvailability> controller;
    final subs = <StreamSubscription<Object?>>[];
    var last = availability;
    void emit() {
      final next = availability;
      if (next == last) return;
      last = next;
      controller.add(next);
    }

    controller = StreamController<AiAvailability>(
      onListen: () {
        controller.add(last);
        subs
          ..add(_connectivity.watchOnline().listen((_) => emit()))
          ..add(
            _authStates.listen((s) {
              if (s.isSignedIn) _rejected = false;
              emit();
            }),
          )
          ..add(_rejections.stream.listen((_) => emit()));
      },
      onCancel: () async {
        for (final s in subs) {
          await s.cancel();
        }
      },
    );
    return controller.stream;
  }

  // ------------------------------------------------------------------
  // Calls

  @override
  Future<AiResult<Explanation>> explain(ExplanationRequest request) =>
      _call<Explanation>(() async {
        final res = await _api.post('/api/explain', request.toApiJson());
        if (!res.isSuccess) return _failure<Explanation>(res);
        final text = res.jsonMap['explanation'];
        if (text is! String || text.trim().isEmpty) {
          return const AiFailure<Explanation>('Empty explanation');
        }
        var explanation = Explanation(
          term: request.term,
          explanation: text,
          createdAt: _now().toUtc(),
          paperId: request.paperId,
          highlightId: request.highlightId,
        );
        final paperId = request.paperId;
        final userId = _auth().user?.id;
        if (paperId != null && userId != null) {
          explanation = await _fileInGlossary(explanation, paperId, userId);
        }
        await _cacheExplanation(explanation);
        return AiSuccess(explanation);
      });

  Future<Explanation> _fileInGlossary(
    Explanation e,
    String paperId,
    String userId,
  ) async {
    final normalized = normalizeTerm(e.term);
    if (normalized.isEmpty) return e;
    try {
      final row = await _glossary.insertOrGet({
        'user_id': userId,
        'paper_id': paperId,
        'highlight_id': e.highlightId,
        'term': e.term,
        'normalized_term': normalized,
        'explanation': e.explanation,
      });
      final term = GlossaryTerm.fromJson(row);
      await _upsertCachedGlossary(term);
      return Explanation.fromJson({...e.toJson(), 'glossary_term_id': term.id});
    } on PaperException {
      // Filing is best effort; the explanation itself succeeded.
      return e;
    }
  }

  @override
  Future<AiResult<Explanation>> reexplain(String glossaryTermId) =>
      _call<Explanation>(() async {
        final res = await _api.post('/api/glossary/reexplain', {
          'glossaryTermId': glossaryTermId,
        });
        if (!res.isSuccess) return _failure<Explanation>(res);
        final term = _termFrom(res);
        if (term == null) return const AiFailure<Explanation>('Bad response');
        await _upsertCachedGlossary(term);
        final explanation = Explanation(
          term: term.term,
          explanation: term.explanation,
          createdAt: _now().toUtc(),
          paperId: term.paperId,
          highlightId: term.highlightId,
          glossaryTermId: term.id,
        );
        await _cacheExplanation(explanation);
        return AiSuccess(explanation);
      });

  @override
  Future<AiResult<List<GlossaryTerm>>> glossary(String paperId) async {
    final cached = await _cachedGlossary(paperId);
    final result = await _call<List<GlossaryTerm>>(() async {
      final rows = await _glossary.fetchForPaper(paperId);
      final terms = rows.map(GlossaryTerm.fromJson).toList(growable: false);
      await _db.writeKv(
        _glossaryKey(paperId),
        jsonEncode([for (final t in terms) t.toJson()]),
      );
      return AiSuccess(terms);
    });
    if (result is AiSuccess<List<GlossaryTerm>>) return result;
    if (cached != null) return AiSuccess(cached);
    return result;
  }

  @override
  Future<AiResult<GlossaryTerm>> rateGlossaryTerm(
    String glossaryTermId,
    int? rating,
  ) => _call<GlossaryTerm>(() async {
    if (rating != null && (rating < 1 || rating > 5)) {
      return const AiFailure<GlossaryTerm>(
        'rating must be 1..5',
        retryable: false,
      );
    }
    final res = await _api.patch('/api/glossary/$glossaryTermId', {
      'rating': rating,
    });
    if (!res.isSuccess) return _failure<GlossaryTerm>(res);
    final term = _termFrom(res);
    if (term == null) return const AiFailure<GlossaryTerm>('Bad response');
    await _upsertCachedGlossary(term);
    return AiSuccess(term);
  });

  @override
  Future<AiResult<VisualAid>> visual(ExplanationRequest request) async {
    var explanation = (await cachedExplanation(request.term))?.explanation;
    if (explanation == null) {
      final explained = await explain(request);
      switch (explained) {
        case AiSuccess(:final value):
          explanation = value.explanation;
        case AiUnavailable(:final reason):
          return AiUnavailable<VisualAid>(reason);
        case AiFailure(:final message, :final retryable, :final statusCode):
          return AiFailure<VisualAid>(
            message,
            retryable: retryable,
            statusCode: statusCode,
          );
      }
    }
    final body = <String, Object?>{
      ...request.toApiJson(),
      'explanation': explanation,
    };
    return _call<VisualAid>(() async {
      var res = await _api.post('/api/explain/visual', body);
      final deadline = _now().add(visualPollTimeout);
      while (res.statusCode == 202 &&
          res.jsonMap['status'] == 'pending' &&
          _now().isBefore(deadline)) {
        final jobId = res.jsonMap['jobId'];
        if (jobId is! String) break;
        await Future<void>.delayed(visualPollInterval);
        res = await _api.get('/api/explain/visual', query: {'jobId': jobId});
      }
      if (res.statusCode == 202) {
        return const AiFailure<VisualAid>('Visual still rendering');
      }
      if (!res.isSuccess) return _failure<VisualAid>(res);
      final json = res.jsonMap;
      final video = json['videoUrl'];
      if (video is String) {
        return AiSuccess(VisualAid(term: request.term, videoUrl: video));
      }
      final image = json['imageUrl'];
      if (image is String) {
        return AiSuccess(VisualAid(term: request.term, imageUrl: image));
      }
      final scene = json['sceneJson'];
      if (scene is Map) {
        return AiSuccess<VisualAid>(
          SceneVisualAid(
            term: request.term,
            sceneJson: scene.cast<String, Object?>(),
          ),
        );
      }
      return const AiFailure<VisualAid>('Bad response', retryable: false);
    });
  }

  @override
  Future<Explanation?> cachedExplanation(String term) async {
    final raw = await _db.readKv(_explainKey(term));
    if (raw == null) return null;
    return Explanation.fromJson({
      ...asJsonMap(jsonDecode(raw)),
      'from_cache': true,
    });
  }

  // ------------------------------------------------------------------
  // Plumbing

  Future<AiResult<T>> _call<T>(Future<AiResult<T>> Function() body) async {
    if (!_auth().isSignedIn) {
      return AiUnavailable<T>(AiUnavailableReason.signedOut);
    }
    if (!_connectivity.isOnline) {
      return AiUnavailable<T>(AiUnavailableReason.offline);
    }
    try {
      final result = await body();
      if (result is AiSuccess<T> && _rejected) {
        _rejected = false;
        _rejections.add(null);
      }
      return result;
    } on OfflineException {
      unawaited(_connectivity.check());
      return AiUnavailable<T>(AiUnavailableReason.offline);
    } on AuthExpiredException {
      return AiUnavailable<T>(AiUnavailableReason.signedOut);
    } on ServerException catch (e) {
      return AiFailure<T>(
        e.message ?? 'Server error',
        statusCode: e.statusCode,
      );
    } on PaperException catch (e) {
      return AiFailure<T>(e.toString());
    }
  }

  AiResult<T> _failure<T>(ApiResponse res) {
    final status = res.statusCode;
    final message = res.error ?? 'HTTP $status';
    if (status == 401 || status == 403) {
      _rejected = true;
      _rejections.add(null);
      return AiUnavailable<T>(AiUnavailableReason.rejected);
    }
    final retryable =
        status == 408 || status == 429 || (status >= 500 && status != 503);
    return AiFailure<T>(message, retryable: retryable, statusCode: status);
  }

  static GlossaryTerm? _termFrom(ApiResponse res) {
    final t = res.jsonMap['glossaryTerm'];
    return t is Map ? GlossaryTerm.fromJson(t.cast<String, Object?>()) : null;
  }

  static String _explainKey(String term) => 'ai:explain:${normalizeTerm(term)}';

  static String _glossaryKey(String paperId) => 'ai:glossary:$paperId';

  Future<void> _cacheExplanation(Explanation e) =>
      _db.writeKv(_explainKey(e.term), jsonEncode(e.toJson()));

  Future<List<GlossaryTerm>?> _cachedGlossary(String paperId) async {
    final raw = await _db.readKv(_glossaryKey(paperId));
    if (raw == null) return null;
    return (jsonDecode(raw) as List<Object?>)
        .map((r) => GlossaryTerm.fromJson(asJsonMap(r)))
        .toList(growable: false);
  }

  Future<void> _upsertCachedGlossary(GlossaryTerm term) async {
    final current = await _cachedGlossary(term.paperId) ?? const [];
    final next = [term, ...current.where((t) => t.id != term.id)];
    await _db.writeKv(
      _glossaryKey(term.paperId),
      jsonEncode([for (final t in next) t.toJson()]),
    );
  }

  Future<void> dispose() => _rejections.close();
}
