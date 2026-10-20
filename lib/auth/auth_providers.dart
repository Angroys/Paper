import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/core_providers.dart';
import '../domain/domain.dart';
import 'unconfigured_auth_repository.dart';

/// Auth. Placeholder: when the build is not configured this is always
/// [UnconfiguredAuthRepository]. The data-layer agent adds the Supabase
/// implementation here, e.g.:
///
/// ```dart
/// final client = ref.watch(supabaseClientProvider);
/// if (client == null) return const UnconfiguredAuthRepository();
/// return SupabaseAuthRepository(client, ref.watch(envProvider));
/// ```
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return const UnconfiguredAuthRepository();
  // TODO(data-layer): return SupabaseAuthRepository(client, env).
  return const UnconfiguredAuthRepository();
});

/// Current auth state for widgets and the router.
final authStateProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(authRepositoryProvider).watchAuthState(),
);
