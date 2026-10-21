import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:paper/app/app.dart';
import 'package:paper/app/app_nav_bar.dart';
import 'package:paper/app/routes.dart';
import 'package:paper/app/router.dart';
import 'package:paper/auth/auth_providers.dart';
import 'package:paper/core/core_providers.dart';
import 'package:paper/data/data_providers.dart';
import 'package:paper/domain/domain.dart';
import 'package:paper/features/auth/sign_in_screen.dart';
import 'package:paper/features/library/library_controller.dart';
import 'package:paper/features/library/library_screen.dart';
import 'package:paper/features/reader/reader_controller.dart';
import 'package:paper/features/reader/reader_screen.dart';
import 'package:paper/features/reader/reader_viewport.dart';
import 'package:paper/features/settings/settings_screen.dart';
import 'package:paper/sync/sync_providers.dart';

import '../data/fakes.dart';
import '../features/feature_fakes.dart';
import '../helpers.dart';
import '../reader/reader_fakes.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeLibraryRepository papers;
  late FakeSyncService sync;
  late int picks;

  setUp(() {
    auth = FakeAuthRepository(const AuthState.signedIn(testUser));
    papers = FakeLibraryRepository(<Paper>[libraryPaper('p1', 'Attention')]);
    sync = FakeSyncService();
    picks = 0;
  });

  Future<ProviderContainer> pumpApp(WidgetTester tester) async {
    setWindowSize(tester, const Size(1280, 800));
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authRepositoryProvider.overrideWithValue(auth),
          paperRepositoryProvider.overrideWithValue(papers),
          highlightRepositoryProvider.overrideWithValue(
            FakeHighlightRepository(),
          ),
          noteRepositoryProvider.overrideWithValue(FakeNoteRepository()),
          syncServiceProvider.overrideWithValue(sync),
          connectivityServiceProvider.overrideWithValue(FakeConnectivity()),
          readerViewportBuilderProvider.overrideWithValue(
            (context, args) => FakeViewport(args: args),
          ),
          pdfPickerProvider.overrideWithValue(() async {
            picks++;
            return const <PickedPdf>[];
          }),
        ],
        child: const PaperApp(),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(PaperApp)));
  }

  Future<void> chord(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    bool shift = false,
  }) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(key);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  bool searchFocused(WidgetTester tester) => tester
      .widget<TextField>(find.byKey(LibraryScreen.searchFieldKey))
      .focusNode!
      .hasFocus;

  testWidgets('Ctrl+F focuses the library search', (tester) async {
    await pumpApp(tester);
    expect(find.byType(LibraryScreen), findsOneWidget);
    expect(searchFocused(tester), isFalse);
    await chord(tester, LogicalKeyboardKey.keyF);
    expect(searchFocused(tester), isTrue);
    await disposeTree(tester);
  });

  testWidgets('Ctrl+, opens settings; Ctrl+K returns to the search', (
    tester,
  ) async {
    await pumpApp(tester);
    await chord(tester, LogicalKeyboardKey.comma);
    expect(find.byType(SettingsScreen), findsOneWidget);

    // Ctrl+F is library-only: nothing happens in Settings.
    await chord(tester, LogicalKeyboardKey.keyF);
    expect(find.byType(SettingsScreen), findsOneWidget);

    await chord(tester, LogicalKeyboardKey.keyK);
    expect(find.byType(LibraryScreen), findsOneWidget);
    expect(searchFocused(tester), isTrue);
    await disposeTree(tester);
  });

  testWidgets('Ctrl+O imports a file, Ctrl+Shift+S syncs now', (tester) async {
    await pumpApp(tester);
    await chord(tester, LogicalKeyboardKey.keyO);
    expect(picks, 1);
    await chord(tester, LogicalKeyboardKey.keyS, shift: true);
    expect(sync.calls, contains('syncNow'));
    await disposeTree(tester);
  });

  testWidgets(
    'in the reader: Ctrl+F is find in paper, single keys are ignored while '
    'a text field has focus, Ctrl+W closes',
    (tester) async {
      final c = await pumpApp(tester);
      c.read(routerProvider).go(AppRoutes.reader('p1'));
      await tester.pumpAndSettle();
      expect(find.byType(ReaderScreen), findsOneWidget);
      ReaderState reader() => c.read(readerControllerProvider('p1'));

      // No text focus: P switches to the pen.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.pump();
      expect(reader().tool, ReaderTool.pen);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.pump();
      expect(reader().tool, ReaderTool.select);

      // Reader shortcut wins over the app-level library search.
      await chord(tester, LogicalKeyboardKey.keyF);
      expect(reader().search.open, isTrue);
      expect(find.byType(ReaderScreen), findsOneWidget);

      // Focus the find field: single keys must not fire.
      await tester.tap(find.byKey(const ValueKey<String>('find-field')));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pump();
      expect(reader().tool, ReaderTool.select);

      await chord(tester, LogicalKeyboardKey.keyW);
      expect(find.byType(ReaderScreen), findsNothing);
      expect(find.byType(LibraryScreen), findsOneWidget);
      await disposeTree(tester);
    },
  );

  testWidgets('signed out opens on the library as a guest (no redirect); '
      'sign-in is pushed, can be closed, and pops back once signed in', (
    tester,
  ) async {
    auth = FakeAuthRepository();
    final container = await pumpApp(tester);
    // No auth gate: the library, not /sign-in.
    expect(find.byType(LibraryScreen), findsOneWidget);
    expect(find.byType(SignInScreen), findsNothing);
    expect(sync.calls, isNot(contains('start')));

    // The nav bar's "Sign in" link opens sign-in on top…
    await tester.tap(find.byKey(AppNavBar.signInKey));
    await tester.pumpAndSettle();
    expect(find.byType(SignInScreen), findsOneWidget);
    // …and it can be dismissed back to where the user was.
    await tester.tap(find.byKey(SignInScreen.closeKey));
    await tester.pumpAndSettle();
    expect(find.byType(SignInScreen), findsNothing);
    expect(find.byType(LibraryScreen), findsOneWidget);

    // From the reader: signing in returns to the reader.
    container.read(routerProvider).go(AppRoutes.reader('p1'));
    await tester.pumpAndSettle();
    unawaited(container.read(routerProvider).push<void>(AppRoutes.signIn));
    await tester.pumpAndSettle();
    expect(find.byType(SignInScreen), findsOneWidget);
    auth.emit(const AuthState.signedIn(testUser));
    await tester.pumpAndSettle();
    expect(find.byType(SignInScreen), findsNothing);
    expect(find.byType(ReaderScreen), findsOneWidget);
    expect(sync.calls, contains('start'));

    // Signing out keeps a usable app (no redirect to sign-in).
    auth.emit(const AuthState.signedOut());
    await tester.pumpAndSettle();
    expect(find.byType(SignInScreen), findsNothing);
    expect(find.byType(ReaderScreen), findsOneWidget);
    expect(sync.calls.last, 'stop');
    await disposeTree(tester);
  });
}
