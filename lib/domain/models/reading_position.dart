import 'package:meta/meta.dart';

import 'json.dart';

/// Last page + zoom for a paper. Device-only in v1 (no server column).
@immutable
class ReadingPosition {
  const ReadingPosition({
    required this.pageNumber,
    required this.updatedAt,
    this.zoom,
    this.scrollOffset,
  });

  factory ReadingPosition.fromJson(Map<String, Object?> json) =>
      ReadingPosition(
        pageNumber: (json['page_number']! as num).toInt(),
        zoom: toDoubleOrNull(json['zoom']),
        scrollOffset: toDoubleOrNull(json['scroll_offset']),
        updatedAt: parseDate(json['updated_at']),
      );

  /// 1-based page number.
  final int pageNumber;

  /// Zoom factor; null = fit width.
  final double? zoom;

  /// Optional offset within the page, 0..1 of the page height.
  final double? scrollOffset;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'page_number': pageNumber,
    'zoom': zoom,
    'scroll_offset': scrollOffset,
    'updated_at': dateToJson(updatedAt),
  };

  @override
  bool operator ==(Object other) =>
      other is ReadingPosition &&
      other.pageNumber == pageNumber &&
      other.zoom == zoom &&
      other.scrollOffset == scrollOffset &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(pageNumber, zoom, scrollOffset, updatedAt);
}
