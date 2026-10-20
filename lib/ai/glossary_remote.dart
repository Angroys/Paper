import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../data/remote/supabase_remote_data_source.dart' show mapPostgrestError;
import '../domain/errors.dart';

/// Direct (RLS-scoped) access to `public.glossary_terms`. RPR's
/// `POST /api/glossary` would also insert a duplicate `highlights` row, so
/// the app files explanations itself, exactly like that route does after
/// generating (`glossary_terms` insert, unique on
/// (user_id, paper_id, normalized_term)).
abstract interface class GlossaryRemote {
  Future<List<Map<String, Object?>>> fetchForPaper(String paperId);

  /// Inserts a term; on a unique-key clash returns the existing row.
  Future<Map<String, Object?>> insertOrGet(Map<String, Object?> row);
}

class SupabaseGlossaryRemote implements GlossaryRemote {
  SupabaseGlossaryRemote(this._client);

  final sb.SupabaseClient _client;

  @override
  Future<List<Map<String, Object?>>> fetchForPaper(String paperId) =>
      _guard(() async {
        final rows = await _client
            .from('glossary_terms')
            .select()
            .eq('paper_id', paperId)
            .order('created_at', ascending: false);
        return [for (final r in rows) r.cast<String, Object?>()];
      });

  @override
  Future<Map<String, Object?>> insertOrGet(Map<String, Object?> row) =>
      _guard(() async {
        try {
          final res = await _client
              .from('glossary_terms')
              .insert(row)
              .select()
              .single();
          return res.cast<String, Object?>();
        } on sb.PostgrestException catch (e) {
          if (e.code == '23503' && row['highlight_id'] != null) {
            // The highlight has not reached the server yet: file it unlinked.
            return insertOrGet({...row, 'highlight_id': null});
          }
          if (e.code != '23505') rethrow;
          final existing = await _client
              .from('glossary_terms')
              .select()
              .eq('paper_id', row['paper_id']! as String)
              .eq('normalized_term', row['normalized_term']! as String)
              .single();
          return existing.cast<String, Object?>();
        }
      });

  static Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on sb.PostgrestException catch (e) {
      throw mapPostgrestError(e.code, e.message);
    } on SocketException catch (e) {
      throw OfflineException(e.message);
    } on http.ClientException catch (e) {
      throw OfflineException(e.message);
    } on TimeoutException {
      throw const OfflineException('timeout');
    }
  }
}
