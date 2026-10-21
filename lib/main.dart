import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import 'app/app.dart';
import 'app/app_settings.dart';
import 'auth/windows_protocol_registration.dart';
import 'core/app_links_deep_link_service.dart';
import 'core/build_flags.dart';
import 'core/core_providers.dart';
import 'core/desktop_window.dart';
import 'core/env.dart';
import 'core/licenses.dart';
import 'core/supabase_bootstrap.dart';
import 'data/data_providers.dart';
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
  // Windows: (re-)register paper:// under HKCU at startup so the OAuth
  // return (paper://auth-callback) opens this exe; a second launch with the
  // link is forwarded to this instance by windows/runner/main.cpp. No-op
  // elsewhere. Offline-only builds have no sign-in, so no handler.
  if (!kOfflineOnly) unawaited(registerWindowsProtocolHandler());
  await initDesktopWindow();

  // Offline-only builds (PAPER_OFFLINE_ONLY) never initialise Supabase;
  // the const branch drops the call from that build entirely.
  final Future<SupabaseClient?> supabaseReady = kOfflineOnly
      ? Future<SupabaseClient?>.value()
      : startSupabase(env);
  final prefs = await _loadPreferences();
  if (!kOfflineOnly) {
    // Session restore is local; wait for it, but never past the splash cap.
    await Future.any(<Future<Object?>>[
      supabaseReady,
      Future<void>.delayed(_splashCap),
    ]);
  }

  runApp(
    ProviderScope(
      overrides: [
        envProvider.overrideWithValue(env),
        supabaseReadyProvider.overrideWith((ref) => supabaseReady),
        deepLinkServiceProvider.overrideWithValue(
          AppLinksDeepLinkService(launchArgs: args),
        ),
        sharedPreferencesProvider.overrideWithValue(prefs),
        // Offline-only builds keep the library on disk too.
        persistentStorageProvider.overrideWithValue(
          env.isConfigured || kOfflineOnly,
        ),
        // Notes / Glossary / Explanation bodies of the reader side panel
        // (Notes only in offline-only builds).
        readerPanelSlotsProvider.overrideWithValue(
          kOfflineOnly ? offlineReaderPanelSlots : appReaderPanelSlots,
        ),
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
