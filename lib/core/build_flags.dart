import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Offline-only build: `--dart-define=PAPER_OFFLINE_ONLY=true`.
///
/// The v0.x test releases are built with it. Such a build has no sign-in,
/// no Supabase client, no sync and no AI: it opens straight into the
/// library as a local user, and every network service is replaced at the
/// provider level, so none is ever constructed. The online code stays in
/// the repo and in normal builds.
///
/// `main()` branches on this constant (so the Supabase init is compiled
/// out); everything else reads [offlineOnlyProvider], which tests override.
const bool kOfflineOnly = bool.fromEnvironment('PAPER_OFFLINE_ONLY');

/// Whether this build is offline-only. Defaults to [kOfflineOnly]; tests
/// override it to exercise either variant without recompiling.
final offlineOnlyProvider = Provider<bool>((ref) => kOfflineOnly);
