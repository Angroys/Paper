import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:paper/ai/glossary_remote.dart';
import 'package:paper/ai/http_ai_service.dart';
import 'package:paper/core/paper_api_client.dart';
import 'package:paper/core/ssr_auth_cookie.dart';
import 'package:paper/data/db/app_database.dart';
import 'package:paper/domain/domain.dart';

import '../data/fakes.dart';

const _supabaseUrl = 'https://abcdefghijklmnop.supabase.co';

class FakeGlossary implements GlossaryRemote {
  final rows = <Map<String, Object?>>[];
  bool offline = false;

  @override
  Future<List<Map<String, Object?>>> fetchForPaper(String paperId) async {
    if (offline) throw const OfflineException();
    return rows.where((r) => r['paper_id'] == paperId).toList();
  }

  @override
  Future<Map<String, Object?>> insertOrGet(Map<String, Object?> row) async {
    final existing = rows.where(
      (r) =>
          r['paper_id'] == row['paper_id'] &&
          r['normalized_term'] == row['normalized_term'],
    );
    if (existing.isNotEmpty) return existing.first;
    final stored = {
      ...row,
      'id': 'g${rows.length + 1}',
      'tags': <String>[],
      'created_at': '2026-10-20T12:00:00Z',
    };
    rows.add(stored);
    return stored;
  }
}

Map<String, Object?> termRow(String id, {String explanation = 'E'}) => {
  'id': id,
  'user_id': userId,
  'paper_id': 'p1',
  'highlight_id': null,
  'term': 'Softmax',
  'normalized_term': 'softmax',
  'explanation': explanation,
  'tags': ['ml'],
  'rating': 4,
  'created_at': '2026-10-20T12:00:00Z',
};

void main() {
  late AppDatabase db;
  late FakeConnectivity net;
  late FakeGlossary glossary;
  late List<http.Request> requests;
  late FutureOr<http.Response> Function(http.Request) handler;
  late AuthState auth;
  late HttpAiService ai;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    net = FakeConnectivity();
    glossary = FakeGlossary();
    requests = [];
    auth = signedIn;
    handler = (_) => http.Response('{}', 200);
    final client = MockClient((req) async {
      requests.add(req);
      return handler(req);
    });
    ai = HttpAiService(
      api: PaperApiClient(
        httpClient: client,
        baseUri: Uri.parse('https://paper.college'),
        supabaseUrl: _supabaseUrl,
        session: () async => auth.isSignedIn
            ? {
                'access_token': 'jwt',
                'refresh_token': 'secret-refresh',
                'expires_at': 4102444800,
                'user': {'id': userId},
              }
            : null,
      ),
      glossaryRemote: glossary,
      db: db,
      connectivity: net,
      currentAuth: () => auth,
      authStates: const Stream.empty(),
      visualPollInterval: Duration.zero,
    );
  });
  tearDown(() async {
    await ai.dispose();
    await db.close();
  });

  http.Response json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  const request = ExplanationRequest(
    term: 'Softmax',
    contextBefore: 'apply a',
    paperTitle: 'Attention',
    paperId: 'p1',
    highlightId: 'h1',
  );

  test('explain sends the ssr cookie and maps the answer', () async {
    handler = (_) => json({'explanation': 'Turns scores into odds.'});
    final r = await ai.explain(request);
    final e = (r as AiSuccess<Explanation>).value;
    expect(e.explanation, 'Turns scores into odds.');
    expect(e.glossaryTermId, 'g1');

    final req = requests.single;
    expect(req.url.toString(), 'https://paper.college/api/explain');
    expect(req.method, 'POST');
    expect(jsonDecode(req.body), {
      'term': 'Softmax',
      'contextBefore': 'apply a',
      'paperTitle': 'Attention',
    });
    final cookie = req.headers['Cookie']!;
    expect(cookie, startsWith('sb-abcdefghijklmnop-auth-token=base64-'));
    final session =
        jsonDecode(SsrAuthCookie.decodeValue(cookie.split('=')[1])) as Map;
    expect(session['access_token'], 'jwt');
    expect(session['refresh_token'], '', reason: 'never sent');
    expect(req.headers['Authorization'], isNull);

    expect(glossary.rows.single['normalized_term'], 'softmax');
    expect(glossary.rows.single['highlight_id'], 'h1');
    final cached = await ai.cachedExplanation('  softmax!');
    expect(cached!.fromCache, isTrue);
    expect(cached.explanation, 'Turns scores into odds.');
  });

  test(
    '401/403 -> AiUnavailable(rejected), availability unavailable',
    () async {
      handler = (_) => json({'error': 'Unauthorized.'}, 401);
      expect(
        await ai.explain(request),
        const AiUnavailable<Explanation>(AiUnavailableReason.rejected),
      );
      expect(ai.availability, AiAvailability.unavailable);
      handler = (_) => json({'error': 'beta only'}, 403);
      expect(
        await ai.visual(request),
        const AiUnavailable<VisualAid>(AiUnavailableReason.rejected),
      );
    },
  );

  test('offline, signed out and network errors', () async {
    net.online = false;
    expect(
      await ai.explain(request),
      const AiUnavailable<Explanation>(AiUnavailableReason.offline),
    );
    expect(ai.availability, AiAvailability.offline);
    expect(requests, isEmpty);

    net.online = true;
    handler = (_) => throw http.ClientException('connection reset');
    expect(
      await ai.explain(request),
      const AiUnavailable<Explanation>(AiUnavailableReason.offline),
    );

    auth = const AuthState.signedOut();
    expect(
      await ai.explain(request),
      const AiUnavailable<Explanation>(AiUnavailableReason.signedOut),
    );
  });

  test('server errors are AiFailure (retryable unless 4xx/503)', () async {
    handler = (_) => json({'error': 'boom'}, 502);
    final r = await ai.explain(request) as AiFailure<Explanation>;
    expect(r.retryable, isTrue);
    expect(r.statusCode, 502);
    expect(r.message, 'boom');
    handler = (_) => json({'error': 'bad'}, 400);
    expect((await ai.explain(request) as AiFailure).retryable, isFalse);
    handler = (_) => json({'status': 'unconfigured'}, 503);
    expect((await ai.visual(request) as AiFailure).retryable, isFalse);
  });

  test('visual polls a pending job until ready', () async {
    var polls = 0;
    handler = (req) {
      if (req.url.path == '/api/explain') return json({'explanation': 'E'});
      if (req.method == 'POST') {
        expect(jsonDecode(req.body)['explanation'], 'E');
        return json({'status': 'pending', 'jobId': 'job-1'}, 202);
      }
      expect(req.url.queryParameters['jobId'], 'job-1');
      polls++;
      return polls < 2
          ? json({'status': 'pending', 'jobId': 'job-1'}, 202)
          : json({'status': 'ready', 'videoUrl': 'https://v/1.mp4'});
    };
    final r = await ai.visual(request) as AiSuccess<VisualAid>;
    expect(r.value.videoUrl, 'https://v/1.mp4');
    expect(polls, 2);

    handler = (_) => json({
      'status': 'ready',
      'sceneJson': {'nodes': <Object?>[]},
    });
    final scene = await ai.visual(request) as AiSuccess<VisualAid>;
    expect(scene.value, isA<SceneVisualAid>());
  });

  test('reexplain, rating and glossary with offline cache', () async {
    handler = (req) {
      if (req.url.path == '/api/glossary/reexplain') {
        expect(jsonDecode(req.body), {'glossaryTermId': 'g9'});
        return json({'glossaryTerm': termRow('g9', explanation: 'New')});
      }
      expect(req.method, 'PATCH');
      expect(req.url.path, '/api/glossary/g9');
      expect(jsonDecode(req.body), {'rating': null});
      return json({
        'glossaryTerm': {...termRow('g9'), 'rating': null},
      });
    };
    final re = await ai.reexplain('g9') as AiSuccess<Explanation>;
    expect(re.value.explanation, 'New');
    expect(re.value.glossaryTermId, 'g9');
    final rated = await ai.rateGlossaryTerm('g9', null) as AiSuccess;
    expect((rated.value as GlossaryTerm).rating, isNull);
    expect(
      (await ai.rateGlossaryTerm('g9', 7) as AiFailure).retryable,
      isFalse,
    );

    glossary.rows.add(termRow('g1'));
    final online = await ai.glossary('p1') as AiSuccess<List<GlossaryTerm>>;
    expect(online.value.single.id, 'g1');
    glossary.offline = true;
    final cached = await ai.glossary('p1') as AiSuccess<List<GlossaryTerm>>;
    expect(cached.value.single.id, 'g1');
    expect(
      await ai.glossary('p2'),
      const AiUnavailable<List<GlossaryTerm>>(AiUnavailableReason.offline),
    );
  });

  test('normalizeTerm matches RPR for common input', () {
    expect(
      normalizeTerm('  "Self-Attention",\n layer. '),
      'self-attention", layer',
    );
    expect(normalizeTerm('...'), '');
  });
}
