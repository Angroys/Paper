import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../domain/errors.dart';
import 'ssr_auth_cookie.dart';

/// Returns the current Supabase session as supabase-js JSON
/// (`Session.toJson()`), refreshed so it is valid for a few more minutes;
/// null when signed out. Throws `OfflineException` if a needed refresh
/// could not reach the server, `AuthExpiredException` if it was refused.
typedef FreshSessionJson = Future<Map<String, Object?>?> Function();

/// Status + decoded JSON body of a paper.college API call.
class ApiResponse {
  const ApiResponse(this.statusCode, this.body);

  final int statusCode;

  /// Decoded JSON, or null when the body was empty / not JSON.
  final Object? body;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  Map<String, Object?> get jsonMap {
    final b = body;
    return b is Map ? b.cast<String, Object?>() : const <String, Object?>{};
  }

  String? get error => jsonMap['error'] as String?;
}

/// HTTP client for the paper.college Next.js API (RPR), authenticated with
/// the `@supabase/ssr` session cookie ([SsrAuthCookie]); RPR routes accept
/// no bearer token.
class PaperApiClient {
  PaperApiClient({
    required http.Client httpClient,
    required this._baseUri,
    required this._supabaseUrl,
    required this._session,
    this.timeout = const Duration(seconds: 45),
  }) : _http = httpClient;

  final http.Client _http;
  final Uri _baseUri;
  final String _supabaseUrl;
  final FreshSessionJson _session;
  final Duration timeout;

  Future<ApiResponse> post(String path, Map<String, Object?> body) =>
      _send('POST', path, body: body);

  Future<ApiResponse> patch(String path, Map<String, Object?> body) =>
      _send('PATCH', path, body: body);

  Future<ApiResponse> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  Future<ApiResponse> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
    Map<String, String>? query,
  }) async {
    final session = await _session();
    if (session == null) {
      throw const AuthExpiredException('Not signed in');
    }
    final cookies = SsrAuthCookie.encodeSessionCookies(
      supabaseUrl: _supabaseUrl,
      session: session,
    );
    final uri = _baseUri.replace(
      path: _joinPath(_baseUri.path, path),
      queryParameters: query,
    );
    final request = http.Request(method, uri)
      ..headers['Cookie'] = SsrAuthCookie.header(cookies)
      ..headers['Accept'] = 'application/json';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    try {
      final streamed = await _http.send(request).timeout(timeout);
      final response = await http.Response.fromStream(streamed);
      // Set-Cookie (refreshed session) is deliberately ignored: the app owns
      // its session through supabase_flutter.
      return ApiResponse(response.statusCode, _decode(response.body));
    } on TimeoutException {
      throw const ServerException(504, 'Request timed out');
    } on SocketException catch (e) {
      throw OfflineException(e.message);
    } on http.ClientException catch (e) {
      throw OfflineException(e.message);
    } on HandshakeException catch (e) {
      throw OfflineException(e.message);
    }
  }

  static String _joinPath(String base, String path) {
    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final p = path.startsWith('/') ? path : '/$path';
    return '$b$p';
  }

  static Object? _decode(String body) {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }
}
