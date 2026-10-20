import '../domain/domain.dart';

/// [AiService] that can never run: every call returns [AiUnavailable] with
/// [reason]. Used for unconfigured builds, and as the stub if the RPR AI
/// routes turn out not to accept a bearer token (UI shows `aiUnavailable*`).
class UnavailableAiService implements AiService {
  const UnavailableAiService(this.reason);

  final AiUnavailableReason reason;

  @override
  AiAvailability get availability => reason == AiUnavailableReason.offline
      ? AiAvailability.offline
      : AiAvailability.unavailable;

  @override
  Stream<AiAvailability> watchAvailability() =>
      Stream<AiAvailability>.value(availability);

  @override
  Future<AiResult<Explanation>> explain(ExplanationRequest request) async =>
      AiUnavailable<Explanation>(reason);

  @override
  Future<AiResult<Explanation>> reexplain(String glossaryTermId) async =>
      AiUnavailable<Explanation>(reason);

  @override
  Future<AiResult<List<GlossaryTerm>>> glossary(String paperId) async =>
      AiUnavailable<List<GlossaryTerm>>(reason);

  @override
  Future<AiResult<GlossaryTerm>> rateGlossaryTerm(
    String glossaryTermId,
    int? rating,
  ) async => AiUnavailable<GlossaryTerm>(reason);

  @override
  Future<AiResult<VisualAid>> visual(ExplanationRequest request) async =>
      AiUnavailable<VisualAid>(reason);

  @override
  Future<Explanation?> cachedExplanation(String term) async => null;
}
