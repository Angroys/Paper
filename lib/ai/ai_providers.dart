import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/core_providers.dart';
import '../domain/domain.dart';
import 'unavailable_ai_service.dart';

/// AI. Placeholder: [UnavailableAiService] (notConfigured). The data-layer
/// agent returns the HTTP implementation (paper.college API with the
/// Supabase JWT as bearer) when [envProvider] is configured.
final aiServiceProvider = Provider<AiService>((ref) {
  final env = ref.watch(envProvider);
  if (!env.isConfigured) {
    return const UnavailableAiService(AiUnavailableReason.notConfigured);
  }
  // TODO(data-layer): return HttpAiService(...).
  return const UnavailableAiService(AiUnavailableReason.notConfigured);
});

final aiAvailabilityProvider = StreamProvider<AiAvailability>(
  (ref) => ref.watch(aiServiceProvider).watchAvailability(),
);
