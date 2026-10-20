import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paper/core/ssr_auth_cookie.dart';

// test/ai/fixtures/ssr_cookies_golden.json was produced by RPR's own
// @supabase/ssr 0.12 (stringToBase64URL + createChunks) from
// ssr_sessions.json, and the same script decoded it back through
// createServerClient().auth.getSession(). The script is reproduced in the
// README of this test (see bottom). Matching the golden byte-for-byte
// proves Dart encode -> ssr decode round-trips.
const _supabaseUrl = 'https://abcdefghijklmnop.supabase.co';

Map<String, Object?> _readJson(String name) =>
    (jsonDecode(File('test/ai/fixtures/$name').readAsStringSync()) as Map)
        .cast<String, Object?>();

void main() {
  final sessions = _readJson('ssr_sessions.json');
  final golden = _readJson('ssr_cookies_golden.json');

  test('storage key is sb-<first host label>-auth-token', () {
    expect(
      SsrAuthCookie.storageKey(_supabaseUrl),
      'sb-abcdefghijklmnop-auth-token',
    );
    expect(
      SsrAuthCookie.storageKey('http://127.0.0.1:54321'),
      'sb-127-auth-token',
    );
  });

  for (final name in ['small', 'large']) {
    test('$name session encodes exactly like @supabase/ssr', () {
      final session = (sessions[name]! as Map).cast<String, Object?>();
      final cookies = SsrAuthCookie.encodeSessionCookies(
        supabaseUrl: _supabaseUrl,
        session: session,
      );
      final expected = (golden[name]! as List)
          .cast<List<Object?>>()
          .map((c) => MapEntry(c[0]! as String, c[1]! as String))
          .toList();
      expect(cookies.map((c) => '${c.key}=${c.value}'), [
        for (final c in expected) '${c.key}=${c.value}',
      ]);
      for (final c in cookies) {
        expect(c.value.length, lessThanOrEqualTo(SsrAuthCookie.maxChunkSize));
      }
      // Decodes back to the same JSON.
      final joined = cookies.map((c) => c.value).join();
      expect(
        jsonDecode(SsrAuthCookie.decodeValue(joined)),
        jsonDecode(jsonEncode(session)),
      );
    });
  }

  test('large session is chunked as <name>.0, <name>.1, ...', () {
    final cookies = SsrAuthCookie.encodeSessionCookies(
      supabaseUrl: _supabaseUrl,
      session: (sessions['large']! as Map).cast<String, Object?>(),
    );
    expect(cookies.length, greaterThan(1));
    expect(cookies.first.key, 'sb-abcdefghijklmnop-auth-token.0');
    expect(cookies.first.value, startsWith('base64-'));
    expect(
      SsrAuthCookie.header(cookies),
      contains('; sb-abcdefghijklmnop-auth-token.1='),
    );
  });

  test('refresh token never leaves the device by default', () {
    final cookies = SsrAuthCookie.encodeSessionCookies(
      supabaseUrl: _supabaseUrl,
      session: const {
        'access_token': 'a',
        'refresh_token': 'SECRET',
        'expires_at': 1,
      },
    );
    final decoded =
        jsonDecode(SsrAuthCookie.decodeValue(cookies.single.value)) as Map;
    expect(decoded['refresh_token'], '');
    expect(decoded.keys.toList(), [
      'access_token',
      'refresh_token',
      'expires_at',
    ]);
  });
}

// Regenerating the golden (read-only use of RPR node_modules, run from a
// scratch dir, never inside RPR):
//
//   const RPR = "<rpr>/node_modules/@supabase/ssr/dist/main";
//   const { stringToBase64URL } = require(RPR + "/utils/base64url.js");
//   const { createChunks } = require(RPR + "/utils/chunker.js");
//   value = "base64-" + stringToBase64URL(JSON.stringify(session));
//   golden[name] = createChunks(key, value).map(c => [c.name, c.value]);
//   // and decode: createServerClient(url, key, { cookies: { getAll, setAll } })
//   //   .auth.getSession() -> same access_token / user.
