import '../models/ai_result.dart';
import '../models/explanation.dart';
import '../models/glossary_term.dart';

/// Online-only AI via the paper.college API (bearer = Supabase JWT).
/// Never throws for expected failures: returns [AiUnavailable] (offline /
/// not configured / rejected) or [AiFailure] (call failed).
abstract interface class AiService {
  AiAvailability get availability;

  Stream<AiAvailability> watchAvailability();

  /// `POST /api/explain`; on success also files the term in the glossary.
  Future<AiResult<Explanation>> explain(ExplanationRequest request);

  /// Re-explain a glossary term in the context of its paper.
  Future<AiResult<Explanation>> reexplain(String glossaryTermId);

  /// Glossary for a paper (server, falling back to the local cache).
  Future<AiResult<List<GlossaryTerm>>> glossary(String paperId);

  /// Rate a glossary explanation 1..5, or null to clear.
  Future<AiResult<GlossaryTerm>> rateGlossaryTerm(
    String glossaryTermId,
    int? rating,
  );

  /// Visual aid (image / Manim video) for a term. Online only.
  Future<AiResult<VisualAid>> visual(ExplanationRequest request);

  /// Latest cached explanation for [term], if any (offline fallback).
  Future<Explanation?> cachedExplanation(String term);
}
