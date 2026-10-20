import 'dart:typed_data';

import '../models/figure_highlight.dart';
import '../models/highlight.dart';

/// Text + figure highlights for a paper. Local-first; text highlights sync
/// create/delete only, colour is device-only; figure notes sync LWW.
abstract interface class HighlightRepository {
  Stream<List<Highlight>> watchHighlights(String paperId);

  /// Writes locally first (never waits on the network) and queues a create.
  Future<Highlight> createHighlight(Highlight highlight);

  /// Device-only colour change.
  Future<void> updateColor(String highlightId, HighlightColor color);

  Future<void> deleteHighlight(String highlightId);

  /// Undo for [deleteHighlight].
  Future<void> restoreHighlight(Highlight highlight);

  Stream<List<FigureHighlight>> watchFigureHighlights(String paperId);

  /// [pngBytes] is the cropped figure; uploaded to storage on sync.
  Future<FigureHighlight> createFigureHighlight(
    FigureHighlight figure, {
    required Uint8List pngBytes,
  });

  /// Synced with last-write-wins on `updated_at`.
  Future<void> updateFigureNote(String figureHighlightId, String? note);

  Future<void> deleteFigureHighlight(String figureHighlightId);
}
