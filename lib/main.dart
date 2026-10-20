import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/app_settings.dart';
import 'core/app_links_deep_link_service.dart';
import 'core/core_providers.dart';
import 'core/desktop_window.dart';
import 'core/env.dart';
import 'core/licenses.dart';
import 'features/panel/panel_slots.dart';
import 'features/panel/reader_side_panel.dart';

/// Hard cap on how long the native splash is held (splash.md "Timing").
const Duration _splashCap = Duration(seconds: 2);

/// [args] carries a `paper://` URL on a Windows cold start.
Future<void> main(List<String> args) async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);
  final splashCap = Timer(_splashCap, FlutterNativeSplash.remove);

  registerFontLicenses();
  final env = Env.fromEnvironment();
  await initDesktopWindow();

  final supabaseReady = _initSupabase(env);
  final prefs = await _loadPreferences();
  // Session restore is local; wait for it, but never past the splash cap.
  await Future.any(<Future<Object?>>[
    supabaseReady,
    Future<void>.delayed(_splashCap),
  ]);

  runApp(
    ProviderScope(
      overrides: [
        envProvider.overrideWithValue(env),
        supabaseReadyProvider.overrideWith((ref) => supabaseReady),
        deepLinkServiceProvider.overrideWithValue(
          AppLinksDeepLinkService(launchArgs: args),
        ),
        sharedPreferencesProvider.overrideWithValue(prefs),
        // Notes / Glossary / Explanation bodies of the reader side panel.
        readerPanelSlotsProvider.overrideWithValue(appReaderPanelSlots),
      ],
      child: const PaperApp(),
    ),
  );

  binding.addPostFrameCallback((_) {
    splashCap.cancel();
    FlutterNativeSplash.remove();
  });
}

/// Device-local settings (theme, reduce motion, reader prefs). Null if the
/// platform store is unavailable: settings then live in memory only.
Future<SharedPreferences?> _loadPreferences() async {
  try {
    return await SharedPreferences.getInstance();
  } on Object catch (e) {
    debugPrint('Paper: preferences unavailable: $e');
    return null;
  }
}

/// Initialises Supabase when configured; otherwise the app runs in
/// "not configured" mode. Never throws.
Future<SupabaseClient?> _initSupabase(Env env) async {
  if (!env.isConfigured) {
    debugPrint(
      'Paper: SUPABASE_URL / SUPABASE_ANON_KEY not set; '
      'running in not-configured mode.',
    );
    return null;
  }
  try {
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
  } on Object catch (e, st) {
    debugPrint('Paper: Supabase init failed: $e\n$st');
    return null;
  }
}
