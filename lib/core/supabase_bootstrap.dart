import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'build_flags.dart';
import 'env.dart';

/// Initialises Supabase for [env] and returns its client.
typedef SupabaseInitializer = Future<SupabaseClient?> Function(Env env);

/// Starts Supabase for the app, or not at all.
///
/// Returns null without calling [initializer] when [offlineOnly] (the
/// `PAPER_OFFLINE_ONLY` build: no network client is ever constructed) or
/// when [env] is not configured. Never throws.
Future<SupabaseClient?> startSupabase(
  Env env, {
  bool offlineOnly = kOfflineOnly,
  SupabaseInitializer initializer = initializeSupabase,
}) async {
  if (offlineOnly) {
    debugPrint('Paper: offline-only build; Supabase is not initialised.');
    return null;
  }
  if (!env.isConfigured) {
    debugPrint(
      'Paper: SUPABASE_URL / SUPABASE_ANON_KEY not set; '
      'running in not-configured mode.',
    );
    return null;
  }
  try {
    return await initializer(env);
  } on Object catch (e, st) {
    debugPrint('Paper: Supabase init failed: $e\n$st');
    return null;
  }
}

/// The real `Supabase.initialize` (PKCE, deep links handled by the app).
Future<SupabaseClient?> initializeSupabase(Env env) async {
  await Supabase.initialize(
    url: env.supabaseUrl,
    // The anon key is Supabase's publishable key.
    publishableKey: env.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      // DeepLinkListener owns paper://auth-callback (cold and warm);
      // supabase_flutter's own app_links observer would race it and
      // exchange the PKCE code twice.
      detectSessionInUri: false,
    ),
  );
  return Supabase.instance.client;
}
