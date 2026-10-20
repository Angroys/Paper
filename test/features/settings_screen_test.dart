import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper/app/app_settings.dart';
import 'package:paper/auth/auth_providers.dart';
import 'package:paper/core/core_providers.dart';
import 'package:paper/data/data_providers.dart';
import 'package:paper/domain/domain.dart';
import 'package:paper/features/settings/settings_screen.dart';
import 'package:paper/sync/sync_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/fakes.dart';
import '../helpers.dart';
import 'feature_fakes.dart';

void main() {
  late SharedPreferences prefs;
  late FakeNoteRepository notes;
  late FakeSyncService sync;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    notes = FakeNoteRepository();
    sync = FakeSyncService();
  });

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(420, 2400),
  }) async {
    setWindowSize(tester, size);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(const AuthState.signedIn(testUser)),
          ),
          noteRepositoryProvider.overrideWithValue(notes),
          syncServiceProvider.overrideWithValue(sync),
          paperRepositoryProvider.overrideWithValue(
            FakeLibraryRepository(<Paper>[libraryPaper('a', 'Attention')]),
          ),
          connectivityServiceProvider.overrideWithValue(FakeConnectivity()),
        ],
        child: testApp(const Scaffold(body: SettingsScreen())),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('theme choice persists across launches', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey<String>('theme-light')));
    await tester.pump();
    expect(prefs.getString(PrefKeys.themeMode), 'light');

    final next = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(next.dispose);
    expect(next.read(themeModeProvider), ThemeMode.light);
  });

  testWidgets('reader prefs and reduce motion persist', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey<String>('settings-single-key')));
    await tester.tap(find.text('Overlay'));
    await tester.tap(find.text('On'));
    await tester.pump();
    expect(prefs.getBool(PrefKeys.singleKeyShortcuts), isFalse);
    expect(prefs.getString(PrefKeys.panelStyle), 'overlay');
    expect(prefs.getBool(PrefKeys.reduceMotion), isTrue);

    final next = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(next.dispose);
    expect(
      next.read(readerPrefsProvider),
      const ReaderPrefs(
        singleKeyShortcuts: false,
        panelStyle: PanelStyle.overlay,
      ),
    );
    expect(next.read(reduceMotionProvider), isTrue);
  });

  testWidgets('sign-out dialog shows the local-only note count', (
    tester,
  ) async {
    notes.localOnlyCount = 3;
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey<String>('settings-sign-out')));
    await tester.pumpAndSettle();
    expect(find.text('Sign out of Paper?'), findsOneWidget);
    expect(
      find.text('3 notes are only on this device and will be removed.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out of Paper?'), findsNothing);
  });

  testWidgets('pending changes switch to the unsynced variant', (tester) async {
    sync.emit(const SyncStatus(phase: SyncPhase.pending, pendingCount: 2));
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey<String>('settings-sign-out')));
    await tester.pumpAndSettle();
    expect(find.text('Sign out with unsynced changes?'), findsOneWidget);
    expect(
      find.text('2 changes haven’t synced and will be lost.'),
      findsOneWidget,
    );
    expect(find.text('Sync and sign out'), findsOneWidget);
    expect(find.textContaining('only on this device'), findsNothing);
  });

  testWidgets('copy all notes exports through the repository', (tester) async {
    notes.exported = '# Attention\n- p. 1: note';
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pump(tester);
    await tester.tap(
      find.byKey(const ValueKey<String>('settings-export-notes')),
    );
    await tester.pumpAndSettle();
    expect(copied, '# Attention\n- p. 1: note');
    expect(find.text('Notes copied.'), findsOneWidget);
  });

  testWidgets('expanded+ is master–detail', (tester) async {
    await pump(tester, size: const Size(1280, 900));
    expect(
      find.byKey(const ValueKey<String>('settings-nav-storage')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('settings-nav-storage')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Downloaded papers (1)'), findsOneWidget);
    expect(find.text('Clear cache'), findsOneWidget);
  });
}
