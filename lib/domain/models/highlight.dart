import 'package:meta/meta.dart';

import 'json.dart';
import 'sync_state.dart';

/// The six user highlight hues. Names match `PaperHighlightColor` in
/// lib/theme/paper_tokens.dart (map with `PaperHighlightColor.values.byName`).
/// Highlights from the server or web carry no colour and render [yellow].
enum HighlightColor {
  yellow,
  green,
  blue,
  pink,
  purple,
  orange;

  static const HighlightColor defaultColor = HighlightColor.yellow;

  static HighlightColor fromName(String? name) => HighlightColor.values
      .firstWhere((c) => c.name == name, orElse: () => defaultColor);
}

/// One rectangle of a text highlight, in PDF page coordinates as written by
/// the RPR web reader.
@immutable
class HighlightRect {
  const HighlightRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory HighlightRect.fromJson(Map<String, Object?> json) => HighlightRect(
    x: toDouble(json['x']),
    y: toDouble(json['y']),
    width: toDouble(json['width']),
    height: toDouble(json['height']),
  );

  final double x;
  final double y;
  final double width;
  final double height;

  Map<String, Object?> toJson() => <String, Object?>{
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };

  @override
  bool operator ==(Object other) =>
      other is HighlightRect &&
      other.x == x &&
      other.y == y &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(x, y, width, height);
}

/// `highlights.position` jsonb (RPR `HighlightPosition`, camelCase keys).
@immutable
class HighlightPosition {
  const HighlightPosition({
    required this.pageNumber,
    required this.rects,
    this.textLayerScale,
  });

  factory HighlightPosition.fromJson(Map<String, Object?> json) =>
      HighlightPosition(
        pageNumber: (json['pageNumber']! as num).toInt(),
        rects: (json['rects']! as List<Object?>)
            .map((r) => HighlightRect.fromJson(asJsonMap(r)))
            .toList(growable: false),
        textLayerScale: toDoubleOrNull(json['textLayerScale']),
      );

  final int pageNumber;
  final List<HighlightRect> rects;
  final double? textLayerScale;

  Map<String, Object?> toJson() => <String, Object?>{
    'pageNumber': pageNumber,
    'rects': rects.map((r) => r.toJson()).toList(growable: false),
    if (textLayerScale != null) 'textLayerScale': textLayerScale,
  };

  @override
  bool operator ==(Object other) =>
      other is HighlightPosition &&
      other.pageNumber == pageNumber &&
      other.textLayerScale == textLayerScale &&
      listEquals(other.rects, rects);

  @override
  int get hashCode =>
      Object.hash(pageNumber, textLayerScale, Object.hashAll(rects));
}

/// A text highlight.
///
/// Server columns mirror RPR `public.highlights` (create/delete only; the
/// server has no colour/note/updated_at). Device-only: [color],
/// [localUpdatedAt], [syncState]. Notes on highlights live in `Note`.
@immutable
class Highlight {
  const Highlight({
    required this.id,
    required this.userId,
    required this.paperId,
    required this.selectedText,
    required this.createdAt,
    this.contextBefore,
    this.contextAfter,
    this.pageNumber,
    this.position,
    this.color = HighlightColor.defaultColor,
    this.localUpdatedAt,
    this.syncState = SyncState.synced,
  });

  factory Highlight.fromJson(Map<String, Object?> json) => Highlight(
    id: json['id']! as String,
    userId: json['user_id']! as String,
    paperId: json['paper_id']! as String,
    selectedText: json['selected_text']! as String,
    contextBefore: json['context_before'] as String?,
    contextAfter: json['context_after'] as String?,
    pageNumber: toIntOrNull(json['page_number']),
    position: json['position'] == null
        ? null
        : HighlightPosition.fromJson(asJsonMap(json['position'])),
    createdAt: parseDate(json['created_at']),
    color: HighlightColor.fromName(json['color'] as String?),
    localUpdatedAt: parseDateOrNull(json['local_updated_at']),
    syncState: SyncState.fromName(json['sync_state'] as String?),
  );

  final String id;
  final String userId;
  final String paperId;
  final String selectedText;
  final String? contextBefore;
  final String? contextAfter;

  /// 1-based page number.
  final int? pageNumber;
  final HighlightPosition? position;
  final DateTime createdAt;

  // Device-only.
  final HighlightColor color;
  final DateTime? localUpdatedAt;
  final SyncState syncState;

  Map<String, Object?> toSupabaseRow() => <String, Object?>{
    'id': id,
    'user_id': userId,
    'paper_id': paperId,
    'selected_text': selectedText,
    'context_before': contextBefore,
    'context_after': contextAfter,
    'page_number': pageNumber,
    'position': position?.toJson(),
    'created_at': dateToJson(createdAt),
  };

  Map<String, Object?> toJson() => <String, Object?>{
    ...toSupabaseRow(),
    'color': color.name,
    'local_updated_at': dateToJson(localUpdatedAt),
    'sync_state': syncState.name,
  };

  Highlight copyWith({
    HighlightColor? color,
    Object? localUpdatedAt = unset,
    SyncState? syncState,
  }) => Highlight(
    id: id,
    userId: userId,
    paperId: paperId,
    selectedText: selectedText,
    contextBefore: contextBefore,
    contextAfter: contextAfter,
    pageNumber: pageNumber,
    position: position,
    createdAt: createdAt,
    color: color ?? this.color,
    localUpdatedAt: identical(localUpdatedAt, unset)
        ? this.localUpdatedAt
        : localUpdatedAt as DateTime?,
    syncState: syncState ?? this.syncState,
  );

  @override
  bool operator ==(Object other) =>
      other is Highlight &&
      other.id == id &&
      other.userId == userId &&
      other.paperId == paperId &&
      other.selectedText == selectedText &&
      other.contextBefore == contextBefore &&
      other.contextAfter == contextAfter &&
      other.pageNumber == pageNumber &&
      other.position == position &&
      other.createdAt == createdAt &&
      other.color == color &&
      other.localUpdatedAt == localUpdatedAt &&
      other.syncState == syncState;

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    paperId,
    selectedText,
    contextBefore,
    contextAfter,
    pageNumber,
    position,
    createdAt,
    color,
    localUpdatedAt,
    syncState,
  );
}
