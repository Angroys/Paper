import 'package:meta/meta.dart';

import 'json.dart';
import 'sync_state.dart';

/// Normalised page coordinates (0..1) of a figure crop (RPR `FigureBBox`).
@immutable
class FigureBBox {
  const FigureBBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory FigureBBox.fromJson(Map<String, Object?> json) => FigureBBox(
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
      other is FigureBBox &&
      other.x == x &&
      other.y == y &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(x, y, width, height);
}

/// A figure highlight (cropped region of a page).
///
/// Mirrors RPR `public.figure_highlights`, which has `note` and `updated_at`,
/// so figure notes sync with last-write-wins on [updatedAt]. Device-only:
/// [localImagePath], [syncState].
@immutable
class FigureHighlight {
  const FigureHighlight({
    required this.id,
    required this.userId,
    required this.paperId,
    required this.pageNumber,
    required this.bbox,
    required this.storagePath,
    required this.createdAt,
    required this.updatedAt,
    this.label,
    this.caption,
    this.note,
    this.localImagePath,
    this.syncState = SyncState.synced,
  });

  factory FigureHighlight.fromJson(Map<String, Object?> json) =>
      FigureHighlight(
        id: json['id']! as String,
        userId: json['user_id']! as String,
        paperId: json['paper_id']! as String,
        pageNumber: (json['page_number']! as num).toInt(),
        bbox: FigureBBox.fromJson(asJsonMap(json['bbox'])),
        label: json['label'] as String?,
        caption: json['caption'] as String?,
        note: json['note'] as String?,
        storagePath: json['storage_path']! as String,
        createdAt: parseDate(json['created_at']),
        updatedAt: parseDate(json['updated_at']),
        localImagePath: json['local_image_path'] as String?,
        syncState: SyncState.fromName(json['sync_state'] as String?),
      );

  final String id;
  final String userId;
  final String paperId;
  final int pageNumber;
  final FigureBBox bbox;
  final String? label;
  final String? caption;
  final String? note;

  /// Path of the cropped image in the figures storage bucket.
  final String storagePath;
  final DateTime createdAt;

  /// LWW clock (server timestamp once accepted).
  final DateTime updatedAt;

  // Device-only.
  final String? localImagePath;
  final SyncState syncState;

  Map<String, Object?> toSupabaseRow() => <String, Object?>{
    'id': id,
    'user_id': userId,
    'paper_id': paperId,
    'page_number': pageNumber,
    'bbox': bbox.toJson(),
    'label': label,
    'caption': caption,
    'note': note,
    'storage_path': storagePath,
    'created_at': dateToJson(createdAt),
    'updated_at': dateToJson(updatedAt),
  };

  Map<String, Object?> toJson() => <String, Object?>{
    ...toSupabaseRow(),
    'local_image_path': localImagePath,
    'sync_state': syncState.name,
  };

  FigureHighlight copyWith({
    Object? label = unset,
    Object? caption = unset,
    Object? note = unset,
    DateTime? updatedAt,
    Object? localImagePath = unset,
    SyncState? syncState,
  }) => FigureHighlight(
    id: id,
    userId: userId,
    paperId: paperId,
    pageNumber: pageNumber,
    bbox: bbox,
    label: identical(label, unset) ? this.label : label as String?,
    caption: identical(caption, unset) ? this.caption : caption as String?,
    note: identical(note, unset) ? this.note : note as String?,
    storagePath: storagePath,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    localImagePath: identical(localImagePath, unset)
        ? this.localImagePath
        : localImagePath as String?,
    syncState: syncState ?? this.syncState,
  );

  @override
  bool operator ==(Object other) =>
      other is FigureHighlight &&
      other.id == id &&
      other.userId == userId &&
      other.paperId == paperId &&
      other.pageNumber == pageNumber &&
      other.bbox == bbox &&
      other.label == label &&
      other.caption == caption &&
      other.note == note &&
      other.storagePath == storagePath &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.localImagePath == localImagePath &&
      other.syncState == syncState;

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    paperId,
    pageNumber,
    bbox,
    label,
    caption,
    note,
    storagePath,
    createdAt,
    updatedAt,
    localImagePath,
    syncState,
  );
}
