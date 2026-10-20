import 'package:meta/meta.dart';

import 'json.dart';

/// Input to `POST /api/explain` (RPR `ExplainRequestBody`).
@immutable
class ExplanationRequest {
  const ExplanationRequest({
    required this.term,
    this.contextBefore,
    this.contextAfter,
    this.paperTitle,
    this.paperId,
    this.highlightId,
  });

  final String term;
  final String? contextBefore;
  final String? contextAfter;
  final String? paperTitle;

  /// Not sent to /api/explain; used to file the result in the glossary.
  final String? paperId;
  final String? highlightId;

  /// Request body for `POST /api/explain` (camelCase, as RPR expects).
  Map<String, Object?> toApiJson() => <String, Object?>{
    'term': term,
    if (contextBefore != null) 'contextBefore': contextBefore,
    if (contextAfter != null) 'contextAfter': contextAfter,
    if (paperTitle != null) 'paperTitle': paperTitle,
  };

  @override
  bool operator ==(Object other) =>
      other is ExplanationRequest &&
      other.term == term &&
      other.contextBefore == contextBefore &&
      other.contextAfter == contextAfter &&
      other.paperTitle == paperTitle &&
      other.paperId == paperId &&
      other.highlightId == highlightId;

  @override
  int get hashCode => Object.hash(
    term,
    contextBefore,
    contextAfter,
    paperTitle,
    paperId,
    highlightId,
  );
}

/// A plain-language explanation of a term (`200 { explanation }` from
/// `/api/explain`), possibly served from the local cache.
@immutable
class Explanation {
  const Explanation({
    required this.term,
    required this.explanation,
    required this.createdAt,
    this.paperId,
    this.highlightId,
    this.glossaryTermId,
    this.fromCache = false,
  });

  factory Explanation.fromJson(Map<String, Object?> json) => Explanation(
    term: json['term']! as String,
    explanation: json['explanation']! as String,
    createdAt: parseDate(json['created_at']),
    paperId: json['paper_id'] as String?,
    highlightId: json['highlight_id'] as String?,
    glossaryTermId: json['glossary_term_id'] as String?,
    fromCache: (json['from_cache'] as bool?) ?? false,
  );

  final String term;
  final String explanation;
  final DateTime createdAt;
  final String? paperId;
  final String? highlightId;

  /// Set once the explanation is saved to the glossary.
  final String? glossaryTermId;

  /// True when shown from the local cache (UI caption `aiCachedExplanation`).
  final bool fromCache;

  Map<String, Object?> toJson() => <String, Object?>{
    'term': term,
    'explanation': explanation,
    'created_at': dateToJson(createdAt),
    'paper_id': paperId,
    'highlight_id': highlightId,
    'glossary_term_id': glossaryTermId,
    'from_cache': fromCache,
  };

  @override
  bool operator ==(Object other) =>
      other is Explanation &&
      other.term == term &&
      other.explanation == explanation &&
      other.createdAt == createdAt &&
      other.paperId == paperId &&
      other.highlightId == highlightId &&
      other.glossaryTermId == glossaryTermId &&
      other.fromCache == fromCache;

  @override
  int get hashCode => Object.hash(
    term,
    explanation,
    createdAt,
    paperId,
    highlightId,
    glossaryTermId,
    fromCache,
  );
}

/// A generated visual aid (image and/or Manim video) for a term.
@immutable
class VisualAid {
  const VisualAid({required this.term, this.imageUrl, this.videoUrl});

  factory VisualAid.fromJson(Map<String, Object?> json) => VisualAid(
    term: json['term']! as String,
    imageUrl: json['image_url'] as String?,
    videoUrl: json['video_url'] as String?,
  );

  final String term;
  final String? imageUrl;
  final String? videoUrl;

  Map<String, Object?> toJson() => <String, Object?>{
    'term': term,
    'image_url': imageUrl,
    'video_url': videoUrl,
  };

  @override
  bool operator ==(Object other) =>
      other is VisualAid &&
      other.term == term &&
      other.imageUrl == imageUrl &&
      other.videoUrl == videoUrl;

  @override
  int get hashCode => Object.hash(term, imageUrl, videoUrl);
}
