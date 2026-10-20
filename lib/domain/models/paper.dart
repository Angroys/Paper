import 'package:meta/meta.dart';

import 'json.dart';
import 'reading_position.dart';
import 'sync_state.dart';

/// Download state of a paper's PDF on this device.
enum DownloadState { notDownloaded, downloading, downloaded, failed }

/// A paper in the library.
///
/// Server columns mirror RPR `public.papers`
/// (research-paper-helper/src/lib/types/database.ts). Device-only fields:
/// [localFilePath], [downloadState], [readingPosition], [lastOpenedAt],
/// [syncState], [localUpdatedAt].
@immutable
class Paper {
  const Paper({
    required this.id,
    required this.userId,
    required this.title,
    required this.uploadedAt,
    this.storagePath,
    this.fileName,
    this.readAt,
    this.addedFromPaperId,
    this.sourceUrl,
    this.autoMatched = false,
    this.matchNoticeDismissedAt,
    this.localFilePath,
    this.downloadState = DownloadState.notDownloaded,
    this.readingPosition,
    this.lastOpenedAt,
    this.syncState = SyncState.synced,
    this.localUpdatedAt,
  });

  /// Reads a Supabase `papers` row (snake_case) or a [toJson] map.
  factory Paper.fromJson(Map<String, Object?> json) => Paper(
    id: json['id']! as String,
    userId: json['user_id']! as String,
    title: json['title']! as String,
    storagePath: json['storage_path'] as String?,
    fileName: json['file_name'] as String?,
    uploadedAt: parseDate(json['uploaded_at']),
    readAt: parseDateOrNull(json['read_at']),
    addedFromPaperId: json['added_from_paper_id'] as String?,
    sourceUrl: json['source_url'] as String?,
    autoMatched: (json['auto_matched'] as bool?) ?? false,
    matchNoticeDismissedAt: parseDateOrNull(json['match_notice_dismissed_at']),
    localFilePath: json['local_file_path'] as String?,
    downloadState: DownloadState.values.firstWhere(
      (s) => s.name == json['download_state'],
      orElse: () => DownloadState.notDownloaded,
    ),
    readingPosition: json['reading_position'] == null
        ? null
        : ReadingPosition.fromJson(asJsonMap(json['reading_position'])),
    lastOpenedAt: parseDateOrNull(json['last_opened_at']),
    syncState: SyncState.fromName(json['sync_state'] as String?),
    localUpdatedAt: parseDateOrNull(json['local_updated_at']),
  );

  final String id;
  final String userId;
  final String title;

  /// Path in the `papers` storage bucket; null for a linkless paper.
  final String? storagePath;
  final String? fileName;
  final DateTime uploadedAt;

  /// When the user marked it read; null = unread.
  final DateTime? readAt;
  final String? addedFromPaperId;
  final String? sourceUrl;
  final bool autoMatched;
  final DateTime? matchNoticeDismissedAt;

  // Device-only.
  final String? localFilePath;
  final DownloadState downloadState;
  final ReadingPosition? readingPosition;
  final DateTime? lastOpenedAt;
  final SyncState syncState;
  final DateTime? localUpdatedAt;

  /// Metadata-only paper with no PDF (`storage_path` null).
  bool get isLinkless => storagePath == null;

  bool get isRead => readAt != null;

  bool get showMatchNotice => autoMatched && matchNoticeDismissedAt == null;

  /// Server columns only, for Supabase insert/update.
  Map<String, Object?> toSupabaseRow() => <String, Object?>{
    'id': id,
    'user_id': userId,
    'title': title,
    'storage_path': storagePath,
    'file_name': fileName,
    'uploaded_at': dateToJson(uploadedAt),
    'read_at': dateToJson(readAt),
    'added_from_paper_id': addedFromPaperId,
    'source_url': sourceUrl,
    'auto_matched': autoMatched,
    'match_notice_dismissed_at': dateToJson(matchNoticeDismissedAt),
  };

  /// Server columns plus device-only fields.
  Map<String, Object?> toJson() => <String, Object?>{
    ...toSupabaseRow(),
    'local_file_path': localFilePath,
    'download_state': downloadState.name,
    'reading_position': readingPosition?.toJson(),
    'last_opened_at': dateToJson(lastOpenedAt),
    'sync_state': syncState.name,
    'local_updated_at': dateToJson(localUpdatedAt),
  };

  Paper copyWith({
    String? title,
    Object? storagePath = unset,
    Object? fileName = unset,
    Object? readAt = unset,
    Object? sourceUrl = unset,
    bool? autoMatched,
    Object? matchNoticeDismissedAt = unset,
    Object? localFilePath = unset,
    DownloadState? downloadState,
    Object? readingPosition = unset,
    Object? lastOpenedAt = unset,
    SyncState? syncState,
    Object? localUpdatedAt = unset,
  }) => Paper(
    id: id,
    userId: userId,
    title: title ?? this.title,
    storagePath: identical(storagePath, unset)
        ? this.storagePath
        : storagePath as String?,
    fileName: identical(fileName, unset) ? this.fileName : fileName as String?,
    uploadedAt: uploadedAt,
    readAt: identical(readAt, unset) ? this.readAt : readAt as DateTime?,
    addedFromPaperId: addedFromPaperId,
    sourceUrl: identical(sourceUrl, unset)
        ? this.sourceUrl
        : sourceUrl as String?,
    autoMatched: autoMatched ?? this.autoMatched,
    matchNoticeDismissedAt: identical(matchNoticeDismissedAt, unset)
        ? this.matchNoticeDismissedAt
        : matchNoticeDismissedAt as DateTime?,
    localFilePath: identical(localFilePath, unset)
        ? this.localFilePath
        : localFilePath as String?,
    downloadState: downloadState ?? this.downloadState,
    readingPosition: identical(readingPosition, unset)
        ? this.readingPosition
        : readingPosition as ReadingPosition?,
    lastOpenedAt: identical(lastOpenedAt, unset)
        ? this.lastOpenedAt
        : lastOpenedAt as DateTime?,
    syncState: syncState ?? this.syncState,
    localUpdatedAt: identical(localUpdatedAt, unset)
        ? this.localUpdatedAt
        : localUpdatedAt as DateTime?,
  );

  @override
  bool operator ==(Object other) =>
      other is Paper &&
      other.id == id &&
      other.userId == userId &&
      other.title == title &&
      other.storagePath == storagePath &&
      other.fileName == fileName &&
      other.uploadedAt == uploadedAt &&
      other.readAt == readAt &&
      other.addedFromPaperId == addedFromPaperId &&
      other.sourceUrl == sourceUrl &&
      other.autoMatched == autoMatched &&
      other.matchNoticeDismissedAt == matchNoticeDismissedAt &&
      other.localFilePath == localFilePath &&
      other.downloadState == downloadState &&
      other.readingPosition == readingPosition &&
      other.lastOpenedAt == lastOpenedAt &&
      other.syncState == syncState &&
      other.localUpdatedAt == localUpdatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    title,
    storagePath,
    fileName,
    uploadedAt,
    readAt,
    addedFromPaperId,
    sourceUrl,
    autoMatched,
    matchNoticeDismissedAt,
    localFilePath,
    downloadState,
    readingPosition,
    lastOpenedAt,
    syncState,
    localUpdatedAt,
  );

  @override
  String toString() => 'Paper($id, "$title", $syncState)';
}
