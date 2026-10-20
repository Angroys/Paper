import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../core/paper_api_client.dart';
import '../../domain/errors.dart';
import 'remote_data_source.dart';

/// [RemoteDataSource] on supabase_flutter (PostgREST + Storage, RLS-scoped
/// to the signed-in user) plus the paper.college API for URL import.
///
/// Mirrors what RPR's routes do, without going through them where RLS
/// already allows it: file uploads go straight to the `papers` bucket at
/// `<user_id>/<uuid>.pdf` and the row is inserted directly (same as RPR's
/// browser upload + `POST /api/papers`), figure crops go to `figures`.
/// URL import calls `POST /api/papers/import` (server-side download with
/// the SSRF guard, 20 MB cap and PDF title detection) via the
/// `@supabase/ssr` cookie, see `PaperApiClient`.
class SupabaseRemoteDataSource implements RemoteDataSource {
  SupabaseRemoteDataSource({
    required this._client,
    required this._api,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final sb.SupabaseClient _client;
  final PaperApiClient _api;
  final http.Client _http;

  @override
  Future<List<Map<String, Object?>>> fetchPapers() =>
      _guard(() async => _rows(await _client.from('papers').select()));

  @override
  Future<Map<String, Object?>> upsertPaper(Map<String, Object?> row) =>
      _guard(() async {
        final res = await _client
            .from('papers')
            .upsert(row, onConflict: 'id')
            .select()
            .single();
        return res.cast<String, Object?>();
      });

  @override
  Future<void> updatePaper(String id, Map<String, Object?> fields) =>
      _guard(() async {
        final res = await _client
            .from('papers')
            .update(fields)
            .eq('id', id)
            .select('id');
        if (res.isEmpty) throw NotFoundException('paper $id');
      });

  @override
  Future<void> deletePaper(String id) => _guard(() async {
    final rows = await _client
        .from('papers')
        .select('id, storage_path')
        .eq('id', id);
    if (rows.isEmpty) return;
    final storagePath = rows.first['storage_path'] as String?;
    if (storagePath != null) {
      await _client.storage.from(papersBucket).remove([storagePath]);
    }
    await _client.from('papers').delete().eq('id', id);
  });

  @override
  Future<List<Map<String, Object?>>> fetchHighlights() =>
      _guard(() async => _rows(await _client.from('highlights').select()));

  @override
  Future<void> insertHighlight(Map<String, Object?> row) => _guard(() async {
    await _client
        .from('highlights')
        .upsert(row, onConflict: 'id', ignoreDuplicates: true);
  });

  @override
  Future<void> deleteHighlight(String id) =>
      _guard(() => _client.from('highlights').delete().eq('id', id));

  @override
  Future<List<Map<String, Object?>>> fetchFigureHighlights() => _guard(
    () async => _rows(await _client.from('figure_highlights').select()),
  );

  @override
  Future<Map<String, Object?>?> fetchFigureHighlight(String id) =>
      _guard(() async {
        final res = await _client
            .from('figure_highlights')
            .select()
            .eq('id', id)
            .maybeSingle();
        return res?.cast<String, Object?>();
      });

  @override
  Future<Map<String, Object?>> upsertFigureHighlight(
    Map<String, Object?> row,
  ) => _guard(() async {
    final res = await _client
        .from('figure_highlights')
        .upsert(row, onConflict: 'id')
        .select()
        .single();
    return res.cast<String, Object?>();
  });

  @override
  Future<Map<String, Object?>> updateFigureNote(String id, String? note) =>
      _guard(() async {
        final res = await _client
            .from('figure_highlights')
            .update({'note': note})
            .eq('id', id)
            .select();
        if (res.isEmpty) throw NotFoundException('figure $id');
        return res.first.cast<String, Object?>();
      });

  @override
  Future<void> deleteFigureHighlight(String id) => _guard(() async {
    final rows = await _client
        .from('figure_highlights')
        .select('id, storage_path')
        .eq('id', id);
    if (rows.isEmpty) return;
    await _client.from('figure_highlights').delete().eq('id', id);
    final path = rows.first['storage_path'] as String?;
    if (path != null) {
      try {
        await _client.storage.from(figuresBucket).remove([path]);
      } on sb.StorageException {
        // Orphaned crop: harmless, same as RPR's best-effort cleanup.
      }
    }
  });

  @override
  Future<void> uploadObject(
    String bucket,
    String path,
    Uint8List bytes, {
    required String contentType,
  }) => _guard(
    () => _client.storage
        .from(bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: sb.FileOptions(contentType: contentType, upsert: true),
        ),
  );

  @override
  Future<Uint8List> downloadObject(
    String bucket,
    String path, {
    void Function(double progress)? onProgress,
  }) => _guard(() async {
    final url = await _client.storage.from(bucket).createSignedUrl(path, 600);
    final response = await _http.send(http.Request('GET', Uri.parse(url)));
    if (response.statusCode == 404 || response.statusCode == 400) {
      throw NotFoundException('$bucket/$path');
    }
    if (response.statusCode != 200) {
      throw ServerException(response.statusCode, 'download failed');
    }
    final total = response.contentLength;
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response.stream) {
      builder.add(chunk);
      if (total != null && total > 0) {
        onProgress?.call((builder.length / total).clamp(0, 1).toDouble());
      }
    }
    return builder.takeBytes();
  });

  @override
  Future<Map<String, Object?>> importPaperFromUrl(Uri url) async {
    final res = await _api.post('/api/papers/import', {'url': url.toString()});
    switch (res.statusCode) {
      case 201 || 200:
        final paper = res.jsonMap['paper'];
        if (paper is! Map) throw const ServerException(500, 'No paper');
        return paper.cast<String, Object?>();
      case 401:
        throw AuthExpiredException(res.error);
      case 413:
        throw FileTooLargeException(20 * 1024 * 1024, res.error);
      case 415:
        throw InvalidPdfException(res.error);
      case 400:
        throw InvalidPdfException(res.error);
      default:
        throw ServerException(res.statusCode, res.error);
    }
  }

  static List<Map<String, Object?>> _rows(List<Map<String, dynamic>> rows) => [
    for (final r in rows) r.cast<String, Object?>(),
  ];

  /// Maps Supabase / network errors to `PaperException`s.
  static Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on PaperException {
      rethrow;
    } on sb.PostgrestException catch (e) {
      throw mapPostgrestError(e.code, e.message);
    } on sb.StorageException catch (e) {
      final status = int.tryParse(e.statusCode ?? '') ?? 500;
      if (status == 401) throw AuthExpiredException(e.message);
      if (status == 404) throw NotFoundException(e.message);
      throw ServerException(status, e.message);
    } on sb.AuthException catch (e) {
      throw AuthExpiredException(e.message);
    } on SocketException catch (e) {
      throw OfflineException(e.message);
    } on http.ClientException catch (e) {
      throw OfflineException(e.message);
    } on TimeoutException {
      throw const OfflineException('timeout');
    }
  }
}

/// PostgREST error code -> `PaperException`.
PaperException mapPostgrestError(String? code, String message) {
  switch (code) {
    // JWT invalid / expired.
    case 'PGRST301' || 'PGRST302' || 'PGRST303' || '401':
      return AuthExpiredException(message);
    // No row for .single().
    case 'PGRST116':
      return NotFoundException(message);
    // RLS / privilege.
    case '42501' || '403':
      return ServerException(403, message);
    // FK violation (parent paper gone), unique violation.
    case '23503':
      return NotFoundException(message);
    case '23505':
      return ServerException(409, message);
  }
  final status = int.tryParse(code ?? '');
  if (status != null && status >= 400) return ServerException(status, message);
  return ServerException(400, message);
}
