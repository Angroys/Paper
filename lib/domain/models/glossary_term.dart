import 'package:meta/meta.dart';

import 'json.dart';

/// A glossary entry for a paper. Mirrors RPR `public.glossary_terms`.
@immutable
class GlossaryTerm {
  const GlossaryTerm({
    required this.id,
    required this.userId,
    required this.paperId,
    required this.term,
    required this.normalizedTerm,
    required this.explanation,
    required this.createdAt,
    this.highlightId,
    this.tags = const <String>[],
    this.rating,
  });

  factory GlossaryTerm.fromJson(Map<String, Object?> json) => GlossaryTerm(
    id: json['id']! as String,
    userId: json['user_id']! as String,
    paperId: json['paper_id']! as String,
    highlightId: json['highlight_id'] as String?,
    term: json['term']! as String,
    normalizedTerm: json['normalized_term']! as String,
    explanation: json['explanation']! as String,
    tags: ((json['tags'] as List<Object?>?) ?? const <Object?>[])
        .cast<String>()
        .toList(growable: false),
    rating: toIntOrNull(json['rating']),
    createdAt: parseDate(json['created_at']),
  );

  final String id;
  final String userId;
  final String paperId;
  final String? highlightId;
  final String term;

  /// Dedup key (lower-cased, trimmed; same rule as RPR).
  final String normalizedTerm;
  final String explanation;
  final List<String> tags;

  /// 1..5, or null for unrated (null is NOT a low score).
  final int? rating;
  final DateTime createdAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'user_id': userId,
    'paper_id': paperId,
    'highlight_id': highlightId,
    'term': term,
    'normalized_term': normalizedTerm,
    'explanation': explanation,
    'tags': tags,
    'rating': rating,
    'created_at': dateToJson(createdAt),
  };

  @override
  bool operator ==(Object other) =>
      other is GlossaryTerm &&
      other.id == id &&
      other.userId == userId &&
      other.paperId == paperId &&
      other.highlightId == highlightId &&
      other.term == term &&
      other.normalizedTerm == normalizedTerm &&
      other.explanation == explanation &&
      listEquals(other.tags, tags) &&
      other.rating == rating &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    paperId,
    highlightId,
    term,
    normalizedTerm,
    explanation,
    Object.hashAll(tags),
    rating,
    createdAt,
  );
}
