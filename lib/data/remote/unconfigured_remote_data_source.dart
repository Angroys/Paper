import 'dart:typed_data';

import '../../domain/errors.dart';
import 'remote_data_source.dart';

/// [RemoteDataSource] for builds without Supabase config: every call
/// throws [NotConfiguredException]; local-first features keep working.
class UnconfiguredRemoteDataSource implements RemoteDataSource {
  const UnconfiguredRemoteDataSource();

  Never _fail() =>
      throw const NotConfiguredException('Supabase not configured');

  @override
  Future<List<Map<String, Object?>>> fetchPapers() async => _fail();
  @override
  Future<Map<String, Object?>> upsertPaper(Map<String, Object?> row) async =>
      _fail();
  @override
  Future<void> updatePaper(String id, Map<String, Object?> fields) async =>
      _fail();
  @override
  Future<void> deletePaper(String id) async => _fail();
  @override
  Future<List<Map<String, Object?>>> fetchHighlights() async => _fail();
  @override
  Future<void> insertHighlight(Map<String, Object?> row) async => _fail();
  @override
  Future<void> deleteHighlight(String id) async => _fail();
  @override
  Future<List<Map<String, Object?>>> fetchFigureHighlights() async => _fail();
  @override
  Future<Map<String, Object?>?> fetchFigureHighlight(String id) async =>
      _fail();
  @override
  Future<Map<String, Object?>> upsertFigureHighlight(
    Map<String, Object?> row,
  ) async => _fail();
  @override
  Future<Map<String, Object?>> updateFigureNote(
    String id,
    String? note,
  ) async => _fail();
  @override
  Future<void> deleteFigureHighlight(String id) async => _fail();
  @override
  Future<void> uploadObject(
    String bucket,
    String path,
    Uint8List bytes, {
    required String contentType,
  }) async => _fail();
  @override
  Future<Uint8List> downloadObject(
    String bucket,
    String path, {
    void Function(double progress)? onProgress,
  }) async => _fail();
  @override
  Future<Map<String, Object?>> importPaperFromUrl(Uri url) async => _fail();
}
