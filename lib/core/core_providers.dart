import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/domain.dart';
import 'build_flags.dart';
import 'env.dart';
import 'network_connectivity_service.dart';

/// Compile-time config. `main()` overrides this with [Env.fromEnvironment];
/// tests get [Env.unconfigured] by default.
final envProvider = Provider<Env>((ref) => Env.unconfigured);

/// Completes with the Supabase client once `Supabase.initialize` finished,
/// or null when the build is not configured / init failed. `main()`
/// overrides it with the real init future (it may still be running when the
/// first frame shows: the splash is capped at 2 s).
final supabaseReadyProvider = FutureProvider<SupabaseClient?>((ref) => null);

/// The Supabase client, or null while not configured / not initialised.
/// Repository providers watch this and rebuild when it becomes available.
final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  // Offline-only builds never initialise Supabase.
  if (ref.watch(offlineOnlyProvider)) return null;
  return ref.watch(supabaseReadyProvider).value;
});

/// Incoming `paper://` links. `main()` overrides this with
/// `AppLinksDeepLinkService`; the default never emits.
final deepLinkServiceProvider = Provider<DeepLinkService>(
  (ref) => const NoDeepLinkService(),
);

/// Online/offline signal: connectivity_plus + a ping to the Supabase auth
/// health endpoint (any HTTP answer = reachable). Unconfigured builds
/// (tests) are always online.
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final env = ref.watch(envProvider);
  // Offline-only builds have nothing to reach: no ping, no listener.
  if (ref.watch(offlineOnlyProvider) || !env.isConfigured) {
    return const AlwaysOnlineConnectivityService();
  }
  final service = NetworkConnectivityService.create(
    pingUri: Uri.parse(env.supabaseUrl).replace(path: '/auth/v1/health'),
  );
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});

/// Convenience stream of online state for widgets.
final isOnlineProvider = StreamProvider<bool>(
  (ref) => ref.watch(connectivityServiceProvider).watchOnline(),
);

class NoDeepLinkService implements DeepLinkService {
  const NoDeepLinkService();

  @override
  Future<Uri?> initialLink() async => null;

  @override
  Stream<Uri> get links => const Stream<Uri>.empty();
}

class AlwaysOnlineConnectivityService implements ConnectivityService {
  const AlwaysOnlineConnectivityService();

  @override
  bool get isOnline => true;

  @override
  Stream<bool> watchOnline() => Stream<bool>.value(true);

  @override
  Future<bool> check() async => true;
}
