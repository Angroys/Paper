import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:paper/app/app_settings.dart';
import 'package:paper/auth/auth_providers.dart';
import 'package:paper/core/core_providers.dart';
import 'package:paper/data/data_providers.dart';
import 'package:paper/domain/domain.dart';
import 'package:paper/features/auth/sign_in_prompt.dart';
import 'package:paper/features/auth/sign_in_screen.dart';
import 'package:paper/features/settings/settings_screen.dart';
import 'package:paper/features/settings/sign_out_dialog.dart';
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
    FakeAuthRepository? auth,
    List<Override> extra = const <Override>[],
  }) async {
    setWindowSize(tester, size);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...extra,
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(
            auth ?? FakeAuthRepository(const AuthState.signedIn(testUser)),
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

  testWidgets('no theme selector (dark-only); a legacy theme pref is '
      'ignored and left alone', (tester) async {
    await prefs.setString(PrefKeys.themeMode, 'light');
    await pump(tester);
    expect(find.byKey(const ValueKey<String>('theme-light')), findsNothing);
    expect(find.text('Theme'), findsNothing);
    expect(
      Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
      Brightness.dark,
    );
    expect(prefs.getString(PrefKeys.themeMode), 'light');
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

  testWidgets('sign-out keeps papers by default; local-only notes are '
      'mentioned only when removing them', (tester) async {
    notes.localOnlyCount = 3;
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey<String>('settings-sign-out')));
    await tester.pumpAndSettle();
    expect(find.text('Sign out of Paper?'), findsOneWidget);
    expect(find.textContaining('stay here, so you can keep reading'), findsOne);
    expect(find.textContaining('only on this device'), findsNothing);
    final box = tester.widget<CheckboxListTile>(
      find.byKey(SignOutDialog.removeLocalKey),
    );
    expect(box.value, isFalse);

    await tester.tap(find.byKey(SignOutDialog.removeLocalKey));
    await tester.pumpAndSettle();
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
      find.text(
        '2 changes haven’t synced yet. They sync when you sign in again.',
      ),
      findsOneWidget,
    );
    expect(find.text('Sync and sign out'), findsOneWidget);
    await tester.tap(find.byKey(SignOutDialog.removeLocalKey));
    await tester.pumpAndSettle();
    expect(
      find.text('2 changes haven’t synced and will be lost.'),
      findsOneWidget,
    );
    expect(find.textContaining('only on this device'), findsNothing);
  });

  testWidgets('sign-out passes the keep / remove choice', (tester) async {
    final kept = <bool>[];
    Future<void> fakeSignOut({bool keepLocalData = true}) async =>
        kept.add(keepLocalData);
    await pump(tester, extra: [signOutProvider.overrideWithValue(fakeSignOut)]);
    await tester.tap(find.byKey(const ValueKey<String>('settings-sign-out')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('signOut.confirm')));
    await tester.pumpAndSettle();
    expect(kept, <bool>[true]);

    await tester.tap(find.byKey(const ValueKey<String>('settings-sign-out')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(SignOutDialog.removeLocalKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('signOut.confirm')));
    await tester.pumpAndSettle();
    expect(kept, <bool>[true, false]);
  });

  testWidgets('guests get Sign in under Account and a sync prompt', (
    tester,
  ) async {
    await pump(tester, auth: FakeAuthRepository(const AuthState.signedOut()));
    expect(find.byKey(const ValueKey<String>('settings-guest')), findsOne);
    expect(find.byKey(const ValueKey<String>('settings-sign-in')), findsOne);
    expect(
      find.byKey(const ValueKey<String>('settings-sign-out')),
      findsNothing,
    );
    expect(find.byKey(SignInPrompt.keyFor(GuestFeature.sync)), findsOne);
    expect(find.text('Sync now'), findsNothing);

    // Sign-in opens on top and can be closed again.
    await tester.tap(find.byKey(const ValueKey<String>('settings-sign-in')));
    await tester.pumpAndSettle();
    expect(find.byType(SignInScreen), findsOneWidget);
    await tester.tap(find.byKey(SignInScreen.closeKey));
    await tester.pumpAndSettle();
    expect(find.byType(SignInScreen), findsNothing);
    expect(find.byType(SettingsScreen), findsOneWidget);
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
