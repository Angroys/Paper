import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../core/build_flags.dart';
import '../core/core_providers.dart';
import '../data/data_providers.dart';
import '../domain/domain.dart';
import 'glossary_remote.dart';
import 'http_ai_service.dart';
import 'unavailable_ai_service.dart';

/// AI over the paper.college API ([HttpAiService], `@supabase/ssr` cookie
/// auth). Unconfigured builds get [UnavailableAiService] (notConfigured).
final aiServiceProvider = Provider<AiService>((ref) {
  // Offline-only builds hide every AI entry point; nothing is built.
  if (ref.watch(offlineOnlyProvider)) {
    return const UnavailableAiService(AiUnavailableReason.notConfigured);
  }
  final env = ref.watch(envProvider);
  final client = ref.watch(supabaseClientProvider);
  final api = ref.watch(paperApiClientProvider);
  if (!env.isConfigured || client == null || api == null) {
    return const UnavailableAiService(AiUnavailableReason.notConfigured);
  }
  final auth = ref.watch(authRepositoryProvider);
  final service = HttpAiService(
    api: api,
    glossaryRemote: SupabaseGlossaryRemote(client),
    db: ref.watch(appDatabaseProvider),
    connectivity: ref.watch(connectivityServiceProvider),
    currentAuth: () => auth.currentState,
    authStates: auth.watchAuthState(),
  );
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});

final aiAvailabilityProvider = StreamProvider<AiAvailability>(
  (ref) => ref.watch(aiServiceProvider).watchAvailability(),
);
