import 'package:meta/meta.dart';

import 'json.dart';
import 'sync_state.dart';

/// A note on a text highlight ([highlightId] set) or a free page note
/// ([highlightId] null).
///
/// RPR has no notes table, so in v1 notes are device-only
/// ([SyncState.localOnly], option A). Figure notes are NOT notes: they live
/// in `FigureHighlight.note` and sync.
@immutable
class Note {
  const Note({
    required this.id,
    required this.paperId,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    this.highlightId,
    this.pageNumber,
    this.quotedExcerpt,
    this.syncState = SyncState.localOnly,
  });

  factory Note.fromJson(Map<String, Object?> json) => Note(
    id: json['id']! as String,
    paperId: json['paper_id']! as String,
    highlightId: json['highlight_id'] as String?,
    pageNumber: toIntOrNull(json['page_number']),
    body: json['body']! as String,
    quotedExcerpt: json['quoted_excerpt'] as String?,
    createdAt: parseDate(json['created_at']),
    updatedAt: parseDate(json['updated_at']),
    syncState: json['sync_state'] == null
        ? SyncState.localOnly
        : SyncState.fromName(json['sync_state'] as String?),
  );

  final String id;
  final String paperId;
  final String? highlightId;
  final int? pageNumber;
  final String body;

  /// Excerpt of the highlight this note was attached to, kept when the
  /// server deleted that highlight (the note becomes a free page note).
  final String? quotedExcerpt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncState syncState;

  bool get isPageNote => highlightId == null;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'paper_id': paperId,
    'highlight_id': highlightId,
    'page_number': pageNumber,
    'body': body,
    'quoted_excerpt': quotedExcerpt,
    'created_at': dateToJson(createdAt),
    'updated_at': dateToJson(updatedAt),
    'sync_state': syncState.name,
  };

  Note copyWith({
    String? body,
    Object? highlightId = unset,
    Object? pageNumber = unset,
    Object? quotedExcerpt = unset,
    DateTime? updatedAt,
    SyncState? syncState,
  }) => Note(
    id: id,
    paperId: paperId,
    highlightId: identical(highlightId, unset)
        ? this.highlightId
        : highlightId as String?,
    pageNumber: identical(pageNumber, unset)
        ? this.pageNumber
        : pageNumber as int?,
    body: body ?? this.body,
    quotedExcerpt: identical(quotedExcerpt, unset)
        ? this.quotedExcerpt
        : quotedExcerpt as String?,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    syncState: syncState ?? this.syncState,
  );

  @override
  bool operator ==(Object other) =>
      other is Note &&
      other.id == id &&
      other.paperId == paperId &&
      other.highlightId == highlightId &&
      other.pageNumber == pageNumber &&
      other.body == body &&
      other.quotedExcerpt == quotedExcerpt &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.syncState == syncState;

  @override
  int get hashCode => Object.hash(
    id,
    paperId,
    highlightId,
    pageNumber,
    body,
    quotedExcerpt,
    createdAt,
    updatedAt,
    syncState,
  );
}
