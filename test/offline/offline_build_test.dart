// Offline-only build (PAPER_OFFLINE_ONLY). Runs in the normal suite with
// the flag injected through `offlineOnlyProvider`, and in CI a second time
// compiled with the flag:
//
//   flutter test --tags offline --dart-define=PAPER_OFFLINE_ONLY=true
@Tags(<String>['offline'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:paper/ai/ai_providers.dart';
import 'package:paper/ai/unavailable_ai_service.dart';
import 'package:paper/app/app.dart';
import 'package:paper/app/app_shortcuts.dart';
import 'package:paper/auth/auth_providers.dart';
import 'package:paper/auth/local_auth_repository.dart';
import 'package:paper/core/build_flags.dart';
import 'package:paper/core/core_providers.dart';
import 'package:paper/core/env.dart';
import 'package:paper/core/supabase_bootstrap.dart';
import 'package:paper/data/data_providers.dart';
import 'package:paper/data/remote/unconfigured_remote_data_source.dart';
import 'package:paper/domain/domain.dart';
import 'package:paper/features/auth/sign_in_screen.dart';
import 'package:paper/features/library/library_controller.dart';
import 'package:paper/features/library/library_screen.dart';
import 'package:paper/features/panel/reader_side_panel.dart';
import 'package:paper/features/reader/reader_shortcuts.dart';
import 'package:paper/features/sync/sync_badge.dart';
import 'package:paper/sync/disabled_sync_service.dart';
import 'package:paper/sync/sync_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../helpers.dart';

/// A fully configured env: proves the offline gate wins over config.
const Env _configured = Env(
  supabaseUrl: 'https://offline-test.invalid',
  supabaseAnonKey: 'anon-key',
  paperApiBaseUrl: 'https://offline-test.invalid',
);

/// Turns the flag on; a no-op when the test binary was compiled with it.
List<Override> get _offline => <Override>[
  if (!kOfflineOnly) offlineOnlyProvider.overrideWithValue(true),
];

/// Deep links that deliver one cold-start URI.
class _OneLink implements DeepLinkService {
  _OneLink(this.uri);
  final Uri uri;
  @override
  Future<Uri?> initialLink() async => uri;
  @override
  Stream<Uri> get links => const Stream<Uri>.empty();
}

/// Records `paper://auth-callback` deliveries.
class _SpyAuth extends LocalAuthRepository {
  final List<Uri> callbacks = <Uri>[];
  @override
  Future<bool> handleAuthCallback(Uri uri) async {
    callbacks.add(uri);
    return true;
  }
}

void main() {
  group('compile-time flag', () {
    test(
      'PAPER_OFFLINE_ONLY=true is the provider default',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        expect(kOfflineOnly, isTrue);
        expect(container.read(offlineOnlyProvider), isTrue);
      },
      skip: kOfflineOnly
          ? false
          : 'needs --dart-define=PAPER_OFFLINE_ONLY=true',
    );

    test(
      'the default startSupabase never calls Supabase.initialize',
      () async {
        var calls = 0;
        final client = await startSupabase(
          _configured,
          initializer: (_) async {
            calls++;
            return null;
          },
        );
        expect(client, isNull);
        expect(calls, 0);
      },
      skip: kOfflineOnly
          ? false
          : 'needs --dart-define=PAPER_OFFLINE_ONLY=true',
    );
  });

  group('startSupabase', () {
    test('offline-only: no init even when configured', () async {
      var calls = 0;
      final client = await startSupabase(
        _configured,
        offlineOnly: true,
        initializer: (_) async {
          calls++;
          return null;
        },
      );
      expect(client, isNull);
      expect(calls, 0);
    });

    test('online + configured: init runs once', () async {
      var calls = 0;
      await startSupabase(
        _configured,
        offlineOnly: false,
        initializer: (_) async {
          calls++;
          return null;
        },
      );
      expect(calls, 1);
    });
  });

  test('providers: no network service is constructed', () {
    var supabaseReads = 0;
    var httpClients = 0;
    final container = ProviderContainer(
      overrides: <Override>[
        ..._offline,
        envProvider.overrideWithValue(_configured),
        persistentStorageProvider.overrideWithValue(false),
        supabaseReadyProvider.overrideWith((ref) {
          supabaseReads++;
          return Future<SupabaseClient?>.value();
        }),
        httpClientProvider.overrideWith((ref) {
          httpClients++;
          return http.Client();
        }),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(supabaseClientProvider), isNull);
    final auth = container.read(authRepositoryProvider);
    expect(auth, isA<LocalAuthRepository>());
    expect(auth.currentState.isSignedIn, isTrue);
    expect(container.read(paperApiClientProvider), isNull);
    expect(
      container.read(remoteDataSourceProvider),
      isA<UnconfiguredRemoteDataSource>(),
    );
    expect(container.read(aiServiceProvider), isA<UnavailableAiService>());
    expect(container.read(syncServiceProvider), isA<DisabledSyncService>());
    expect(
      container.read(connectivityServiceProvider),
      isA<AlwaysOnlineConnectivityService>(),
    );
    container.read(paperRepositoryProvider);
    container.read(highlightRepositoryProvider);

    expect(supabaseReads, 0, reason: 'Supabase must never be awaited');
    expect(httpClients, 0, reason: 'no HTTP client may be built');
  });

  test('panel tabs and shortcuts drop the AI and sync entries', () {
    final container = ProviderContainer(overrides: _offline);
    addTearDown(container.dispose);
    final tabs = container.read(readerPanelTabsProvider);
    expect(tabs, <ReaderPanelTab>[
      ReaderPanelTab.notes,
      ReaderPanelTab.highlights,
    ]);

    final reader = readerShortcuts(
      TargetPlatform.windows,
      panelTabs: tabs,
      explain: false,
    );
    expect(reader.values.whereType<ExplainSelectionIntent>(), isEmpty);
    expect(reader.values.whereType<PanelTabIntent>().map((i) => i.tab), tabs);

    final app = appShortcuts(TargetPlatform.windows, offlineOnly: true);
    expect(app.values.whereType<SyncNowIntent>(), isEmpty);
    expect(
      app.values.whereType<ImportPaperIntent>().where((i) => i.fromUrl),
      isEmpty,
    );
  });

  group('app', () {
    late Directory tmp;
    late File pdf;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('paper-offline-test-');
      pdf = File('${tmp.path}/local.pdf')
        ..writeAsStringSync('%PDF-1.4\n%offline test\n');
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    Future<_SpyAuth> boot(WidgetTester tester, {Uri? deepLink}) async {
      setWindowSize(tester, const Size(1280, 800));
      final auth = _SpyAuth();
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            ..._offline,
            envProvider.overrideWithValue(_configured),
            // main() turns this on; tests keep the DB in memory.
            persistentStorageProvider.overrideWithValue(false),
            authRepositoryProvider.overrideWithValue(auth),
            if (deepLink != null)
              deepLinkServiceProvider.overrideWithValue(_OneLink(deepLink)),
            pdfPickerProvider.overrideWithValue(
              () async => <PickedPdf>[
                PickedPdf(path: pdf.path, name: 'local.pdf'),
              ],
            ),
          ],
          child: const PaperApp(),
        ),
      );
      await tester.pumpAndSettle();
      return auth;
    }

    testWidgets('opens on the library: no sign-in, sync or link import', (
      tester,
    ) async {
      await boot(tester);

      expect(find.byType(LibraryScreen), findsOneWidget);
      expect(find.byType(SignInScreen), findsNothing);
      expect(find.byType(SyncBadge), findsNothing);
      expect(find.textContaining('Not configured'), findsNothing);
      expect(find.text('No papers yet'), findsOneWidget);
      expect(
        find.text('Pick a PDF from your device. It opens right away.'),
        findsOneWidget,
      );
      expect(find.text('From a link'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('filter-downloaded')),
        findsNothing,
      );
      await disposeTree(tester);
    });

    testWidgets('imports a local PDF as the local user, no sync wording', (
      tester,
    ) async {
      await boot(tester);

      // The Import button picks a file directly (no menu with a link item).
      await tester.tap(find.byKey(LibraryScreen.importButtonKey));
      // Real file IO (copy into the file store, SQLite insert).
      for (var i = 0; i < 20 && find.text('local').evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(
        find.text('local'),
        findsWidgets,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .join(' | '),
      );
      expect(
        find.byKey(const ValueKey<String>('download-badge')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('paper-sync-chip')),
        findsNothing,
      );
      expect(
        find.textContaining(RegExp('upload', caseSensitive: false)),
        findsNothing,
      );
      await disposeTree(tester);
    });

    testWidgets('settings: no account, sign-out or sync', (tester) async {
      await boot(tester);
      await tester.tap(find.text('Settings').first);
      await tester.pumpAndSettle();

      for (final s in <String>['account', 'sync']) {
        expect(
          find.byKey(ValueKey<String>('settings-nav-$s')),
          findsNothing,
          reason: s,
        );
      }
      for (final s in <String>['appearance', 'reader', 'storage', 'about']) {
        expect(
          find.byKey(ValueKey<String>('settings-nav-$s')),
          findsOneWidget,
          reason: s,
        );
      }
      expect(
        find.byKey(const ValueKey<String>('settings-sign-out')),
        findsNothing,
      );
      // Opens on Appearance (the first section).
      expect(find.text('Theme'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('settings-nav-storage')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('settings-export-notes')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('settings-clear-cache')),
        findsOneWidget,
      );
      await disposeTree(tester);
    });

    testWidgets('paper://auth-callback is inert', (tester) async {
      final auth = await boot(
        tester,
        deepLink: Uri.parse('paper://auth-callback?code=abc'),
      );
      expect(auth.callbacks, isEmpty);
      expect(find.byType(LibraryScreen), findsOneWidget);
      await disposeTree(tester);
    });
  });

  testWidgets('panel tab bar shows only Notes and Highlights', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _offline,
        child: testApp(
          Consumer(
            builder: (context, ref, _) => Scaffold(
              body: PanelTabBar(
                tabs: ref.watch(readerPanelTabsProvider),
                tab: ReaderPanelTab.notes,
                onTabChanged: (_) {},
                onClose: () {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey<String>('panel-tab-notes')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('panel-tab-highlights')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('panel-tab-glossary')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('panel-tab-explanation')),
      findsNothing,
    );
  });
}
