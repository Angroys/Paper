import 'dart:convert';

/// Encodes a Supabase session as the auth cookie that `@supabase/ssr`
/// (0.12, used by RPR's Next.js route handlers) reads.
///
/// Why: RPR's API routes (`/api/explain`, `/api/glossary/*`,
/// `/api/papers/import`, ...) authenticate ONLY through
/// `createServerClient(...).auth.getUser()`, which reads the session from
/// cookies; there is no `Authorization: Bearer` support. A native client
/// can still call them unchanged by sending the cookie a browser would.
///
/// Format (verified against
/// `node_modules/@supabase/ssr/dist/main/cookies.js` + `utils/chunker.js`
/// + supabase-js `defaultStorageKey`, see test/ai/ssr_auth_cookie_test.dart
/// which round-trips through ssr's own decoder):
///
/// * name: `sb-<project-ref>-auth-token`, where project-ref is the first
///   hostname label of SUPABASE_URL (`https://abcd.supabase.co` -> `abcd`);
/// * value: `base64-` + base64url, unpadded, of the UTF-8 bytes of
///   `JSON.stringify(session)` (supabase-js session shape: access_token,
///   token_type, expires_in, expires_at, refresh_token, user);
/// * when `encodeURIComponent(value).length > 3180` (`MAX_CHUNK_SIZE`) the
///   value is split into `<name>.0`, `<name>.1`, ... Every character of a
///   `base64-...` value is URI-safe, so chunks are plain 3180-char slices.
///
/// Server-side refresh: if the access token is within 90 s of expiry
/// (auth-js `EXPIRY_MARGIN_MS`) the server would try to refresh it and
/// rotate the refresh token behind the app's back. Callers must refresh
/// first (see `PaperApiClient`), and [encodeSessionCookies] blanks the
/// refresh token by default so the app's refresh token never leaves the
/// device and can never be rotated by the server. Any `Set-Cookie` the
/// server answers with is ignored.
class SsrAuthCookie {
  const SsrAuthCookie._();

  /// `MAX_CHUNK_SIZE` in @supabase/ssr `utils/chunker.js`.
  static const int maxChunkSize = 3180;

  static const String base64Prefix = 'base64-';

  /// `sb-<ref>-auth-token` for [supabaseUrl].
  static String storageKey(String supabaseUrl) {
    final host = Uri.parse(supabaseUrl).host;
    return 'sb-${host.split('.').first}-auth-token';
  }

  /// `base64-<base64url(utf8(json))>` without padding.
  static String encodeValue(String sessionJson) =>
      base64Prefix +
      base64Url.encode(utf8.encode(sessionJson)).replaceAll('=', '');

  /// Inverse of [encodeValue] (tests / debugging).
  static String decodeValue(String value) {
    var b64 = value.startsWith(base64Prefix)
        ? value.substring(base64Prefix.length)
        : value;
    b64 = b64.padRight((b64.length + 3) ~/ 4 * 4, '=');
    return utf8.decode(base64Url.decode(b64));
  }

  /// Cookie name -> value pairs, chunked like ssr's `createChunks`.
  static List<MapEntry<String, String>> encodeSessionCookies({
    required String supabaseUrl,
    required Map<String, Object?> session,
    bool stripRefreshToken = true,
  }) {
    final payload = <String, Object?>{
      ...session,
      if (stripRefreshToken) 'refresh_token': '',
    };
    return chunk(storageKey(supabaseUrl), encodeValue(jsonEncode(payload)));
  }

  /// ssr `createChunks` for a URI-safe value.
  static List<MapEntry<String, String>> chunk(String key, String value) {
    final encoded = Uri.encodeComponent(value);
    if (encoded.length <= maxChunkSize) {
      return [MapEntry(key, value)];
    }
    // base64url + `base64-` is URI-safe, so encoded == value here and plain
    // slicing matches ssr's escape-aware slicing.
    assert(encoded == value, 'chunk() expects a URI-safe value');
    final chunks = <MapEntry<String, String>>[];
    for (var i = 0, n = 0; i < value.length; i += maxChunkSize, n++) {
      final end = i + maxChunkSize > value.length
          ? value.length
          : i + maxChunkSize;
      chunks.add(MapEntry('$key.$n', value.substring(i, end)));
    }
    return chunks;
  }

  /// `Cookie:` header value.
  static String header(List<MapEntry<String, String>> cookies) =>
      cookies.map((c) => '${c.key}=${c.value}').join('; ');
}
