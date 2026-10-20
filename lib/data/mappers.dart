import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/domain.dart';
import '../domain/models/json.dart';
import 'db/app_database.dart';

// Row <-> domain model mapping for the drift tables.

DateTime? _date(Object? v) => parseDateOrNull(v);

Paper paperFromRow(PaperRow r, {ReadingPositionRow? position}) => Paper(
  id: r.id,
  userId: r.userId,
  title: r.title,
  storagePath: r.storagePath,
  fileName: r.fileName,
  uploadedAt: r.uploadedAt,
  readAt: r.readAt,
  addedFromPaperId: r.addedFromPaperId,
  sourceUrl: r.sourceUrl,
  autoMatched: r.autoMatched,
  matchNoticeDismissedAt: r.matchNoticeDismissedAt,
  localFilePath: r.localFilePath,
  downloadState: DownloadState.values.firstWhere(
    (s) => s.name == r.downloadState,
    orElse: () => DownloadState.notDownloaded,
  ),
  readingPosition: position == null ? null : readingPositionFromRow(position),
  lastOpenedAt: r.lastOpenedAt,
  syncState: SyncState.fromName(r.syncState),
  localUpdatedAt: r.localUpdatedAt,
);

/// Server columns of a Supabase `papers` row as a companion (device-only
/// columns untouched).
PapersCompanion paperServerColumns(Map<String, Object?> row) => PapersCompanion(
  id: Value(row['id']! as String),
  userId: Value(row['user_id']! as String),
  title: Value(row['title']! as String),
  storagePath: Value(row['storage_path'] as String?),
  fileName: Value(row['file_name'] as String?),
  uploadedAt: Value(_date(row['uploaded_at']) ?? DateTime.now().toUtc()),
  readAt: Value(_date(row['read_at'])),
  addedFromPaperId: Value(row['added_from_paper_id'] as String?),
  sourceUrl: Value(row['source_url'] as String?),
  autoMatched: Value((row['auto_matched'] as bool?) ?? false),
  matchNoticeDismissedAt: Value(_date(row['match_notice_dismissed_at'])),
);

/// Server columns of a local paper row (for upserts).
Map<String, Object?> paperRowToSupabase(PaperRow r) =>
    paperFromRow(r).toSupabaseRow();

ReadingPosition readingPositionFromRow(ReadingPositionRow r) => ReadingPosition(
  pageNumber: r.pageNumber,
  zoom: r.zoom,
  scrollOffset: r.scrollOffset,
  updatedAt: r.updatedAt,
);

Highlight highlightFromRow(HighlightRow r) => Highlight(
  id: r.id,
  userId: r.userId,
  paperId: r.paperId,
  selectedText: r.selectedText,
  contextBefore: r.contextBefore,
  contextAfter: r.contextAfter,
  pageNumber: r.pageNumber,
  position: r.position == null
      ? null
      : HighlightPosition.fromJson(asJsonMap(jsonDecode(r.position!))),
  createdAt: r.createdAt,
  color: HighlightColor.fromName(r.color),
  localUpdatedAt: r.localUpdatedAt,
  syncState: SyncState.fromName(r.syncState),
);

HighlightsCompanion highlightToCompanion(Highlight h) => HighlightsCompanion(
  id: Value(h.id),
  userId: Value(h.userId),
  paperId: Value(h.paperId),
  selectedText: Value(h.selectedText),
  contextBefore: Value(h.contextBefore),
  contextAfter: Value(h.contextAfter),
  pageNumber: Value(h.pageNumber),
  position: Value(h.position == null ? null : jsonEncode(h.position!.toJson())),
  createdAt: Value(h.createdAt),
  color: Value(h.color.name),
  localUpdatedAt: Value(h.localUpdatedAt),
  syncState: Value(h.syncState.name),
);

/// A server `highlights` row (no colour: renders yellow).
HighlightsCompanion highlightFromSupabase(Map<String, Object?> row) =>
    highlightToCompanion(
      Highlight.fromJson(<String, Object?>{
        ...row,
        'color': null,
        'sync_state': SyncState.synced.name,
      }),
    );

FigureHighlight figureFromRow(FigureHighlightRow r) => FigureHighlight(
  id: r.id,
  userId: r.userId,
  paperId: r.paperId,
  pageNumber: r.pageNumber,
  bbox: FigureBBox.fromJson(asJsonMap(jsonDecode(r.bbox))),
  label: r.label,
  caption: r.caption,
  note: r.note,
  storagePath: r.storagePath,
  createdAt: r.createdAt,
  updatedAt: r.updatedAt,
  localImagePath: r.localImagePath,
  syncState: SyncState.fromName(r.syncState),
);

FigureHighlightsCompanion figureToCompanion(FigureHighlight f) =>
    FigureHighlightsCompanion(
      id: Value(f.id),
      userId: Value(f.userId),
      paperId: Value(f.paperId),
      pageNumber: Value(f.pageNumber),
      bbox: Value(jsonEncode(f.bbox.toJson())),
      label: Value(f.label),
      caption: Value(f.caption),
      note: Value(f.note),
      storagePath: Value(f.storagePath),
      createdAt: Value(f.createdAt),
      updatedAt: Value(f.updatedAt),
      localImagePath: Value(f.localImagePath),
      syncState: Value(f.syncState.name),
    );

/// Server columns of a `figure_highlights` row (device-only untouched).
FigureHighlightsCompanion figureServerColumns(Map<String, Object?> row) {
  final f = FigureHighlight.fromJson(row);
  return FigureHighlightsCompanion(
    id: Value(f.id),
    userId: Value(f.userId),
    paperId: Value(f.paperId),
    pageNumber: Value(f.pageNumber),
    bbox: Value(jsonEncode(f.bbox.toJson())),
    label: Value(f.label),
    caption: Value(f.caption),
    note: Value(f.note),
    storagePath: Value(f.storagePath),
    createdAt: Value(f.createdAt),
    updatedAt: Value(f.updatedAt),
  );
}

Note noteFromRow(NoteRow r) => Note(
  id: r.id,
  paperId: r.paperId,
  highlightId: r.highlightId,
  pageNumber: r.pageNumber,
  body: r.body,
  quotedExcerpt: r.quotedExcerpt,
  createdAt: r.createdAt,
  updatedAt: r.updatedAt,
  syncState: SyncState.localOnly,
);

NotesCompanion noteToCompanion(Note n) => NotesCompanion(
  id: Value(n.id),
  paperId: Value(n.paperId),
  highlightId: Value(n.highlightId),
  pageNumber: Value(n.pageNumber),
  body: Value(n.body),
  quotedExcerpt: Value(n.quotedExcerpt),
  createdAt: Value(n.createdAt),
  updatedAt: Value(n.updatedAt),
  deletedAt: const Value(null),
);

SyncOp syncOpFromRow(SyncOpRow r) => SyncOp(
  id: r.id,
  entity: SyncEntity.values.byName(r.entity),
  entityId: r.entityId,
  kind: SyncOpKind.values.byName(r.kind),
  payload: asJsonMap(jsonDecode(r.payload)),
  createdAt: r.createdAt,
  localUpdatedAt: r.localUpdatedAt,
  deviceId: r.deviceId,
  attempts: r.attempts,
  lastError: r.lastError,
  failed: r.failed,
);

ReplacedVersion replacedFromRow(ReplacedVersionRow r) => ReplacedVersion(
  id: r.id,
  entity: SyncEntity.values.byName(r.entity),
  entityId: r.entityId,
  mine: asJsonMap(jsonDecode(r.mine)),
  mineUpdatedAt: r.mineUpdatedAt,
  theirsUpdatedAt: r.theirsUpdatedAt,
  replacedAt: r.replacedAt,
);
