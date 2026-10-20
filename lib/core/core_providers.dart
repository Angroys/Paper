import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/domain.dart';
import 'env.dart';

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
final supabaseClientProvider = Provider<SupabaseClient?>(
  (ref) => ref.watch(supabaseReadyProvider).value,
);

/// Incoming `paper://` links. `main()` overrides this with
/// `AppLinksDeepLinkService`; the default never emits.
final deepLinkServiceProvider = Provider<DeepLinkService>(
  (ref) => const NoDeepLinkService(),
);

/// Online/offline signal.
///
/// Placeholder: always online. The data-layer agent replaces the body with
/// a connectivity_plus + ping implementation.
final connectivityServiceProvider = Provider<ConnectivityService>(
  (ref) => const AlwaysOnlineConnectivityService(),
);

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
