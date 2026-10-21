import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:paper/ai/ai_providers.dart';
import 'package:paper/app/app_commands.dart';
import 'package:paper/auth/auth_providers.dart';
import 'package:paper/core/build_flags.dart';
import 'package:paper/core/core_providers.dart';
import 'package:paper/data/data_providers.dart';
import 'package:paper/domain/domain.dart';
import 'package:paper/features/auth/sign_in_prompt.dart';
import 'package:paper/features/auth/sign_in_screen.dart';
import 'package:paper/features/library/library_controller.dart';
import 'package:paper/features/library/library_screen.dart';
import 'package:paper/features/library/library_widgets.dart';
import 'package:paper/features/panel/notes_tab.dart';
import 'package:paper/features/panel/panel_slots.dart';
import 'package:paper/features/panel/reader_side_panel.dart';
import 'package:paper/features/reader/reader_controller.dart';
import 'package:paper/features/reader/reader_route.dart';
import 'package:paper/features/sync/sync_badge.dart';
import 'package:paper/sync/sync_providers.dart';

import '../data/fakes.dart';
import '../helpers.dart';
import '../reader/reader_fakes.dart';
import 'feature_fakes.dart';

/// Optional sign-in: guests use every local feature; online-only ones show
/// a calm "Sign in to use …" prompt that opens (dismissible) sign-in.
void main() {
  group('isGuestProvider', () {
    ProviderContainer container(AuthState state, {bool offline = false}) {
      final c = ProviderContainer(
        overrides: <Override>[
          authRepositoryProvider.overrideWithValue(FakeAuthRepository(state)),
          offlineOnlyProvider.overrideWithValue(offline),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('signed out in an online build is a guest', () {
      expect(
        container(const AuthState.signedOut()).read(isGuestProvider),
        isTrue,
      );
    });

    test('signed in, unconfigured or offline-only builds are not', () {
      expect(
        container(const AuthState.signedIn(testUser)).read(isGuestProvider),
        isFalse,
      );
      expect(
        container(const AuthState.notConfigured()).read(isGuestProvider),
        isFalse,
      );
      expect(
        container(
          const AuthState.signedOut(),
          offline: true,
        ).read(isGuestProvider),
        isFalse,
      );
    });
  });

  group('library', () {
    late FakeLibraryRepository repo;

    setUp(() {
      repo = FakeLibraryRepository(<Paper>[
        libraryPaper('a', 'Attention Is All You Need'),
        Paper(
          id: 'g',
          userId: kGuestUserId,
          title: 'Guest paper',
          uploadedAt: DateTime.utc(2026, 10, 2),
          downloadState: DownloadState.downloaded,
          syncState: SyncState.pendingCreate,
        ),
      ]);
    });

    Future<void> pump(WidgetTester tester) async {
      setWindowSize(tester, const Size(1000, 900));
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
            paperRepositoryProvider.overrideWithValue(repo),
            connectivityServiceProvider.overrideWithValue(FakeConnectivity()),
            syncServiceProvider.overrideWithValue(FakeSyncService()),
            pdfPickerProvider.overrideWithValue(() async => const []),
          ],
          child: testApp(const LibraryScreen()),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    Future<void> importByLink(WidgetTester tester) async {
      await tester.tap(find.byKey(LibraryScreen.importButtonKey));
      await tester.pumpAndSettle();
    }

    testWidgets('kept account papers are labelled; no download states', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('Guest paper'), findsOneWidget);
      // Only the paper kept from an account carries the label.
      expect(find.byKey(PaperKeptChip.chipKey), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('download-badge')),
        findsNothing,
      );
      expect(find.textContaining('Uploads when'), findsNothing);
    });

    testWidgets('the link card asks guests to sign in', (tester) async {
      await pump(tester);
      await importByLink(tester);
      expect(
        find.byKey(SignInPrompt.keyFor(GuestFeature.importLink)),
        findsOneWidget,
      );
      expect(find.text('Sign in to import from a link'), findsOneWidget);
      // No URL field: nothing hard-fails later. File import still works.
      expect(
        find.byKey(const ValueKey<String>('import-url-field')),
        findsNothing,
      );
      expect(find.byKey(LibraryScreen.chooseFileKey), findsOneWidget);
      expect(find.byType(SignInScreen), findsNothing);
      expect(repo.calls.where((c) => c.startsWith('url ')), isEmpty);
    });

    testWidgets('the import-from-link command shows the sign-in dialog; '
        'Not now closes it', (tester) async {
      await pump(tester);
      ProviderScope.containerOf(tester.element(find.byType(LibraryScreen)))
          .read(libraryCommandProvider.notifier)
          .send(LibraryCommandKind.importUrl);
      await tester.pumpAndSettle();
      expect(
        find.byKey(SignInPrompt.keyFor(GuestFeature.importLink)),
        findsOneWidget,
      );
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(SignInPrompt.keyFor(GuestFeature.importLink)),
        findsNothing,
      );
      expect(find.byType(SignInScreen), findsNothing);
    });

    testWidgets('Sign in opens the sign-in screen, which can be closed', (
      tester,
    ) async {
      await pump(tester);
      await importByLink(tester);
      await tester.tap(find.byKey(SignInPrompt.buttonKey));
      await tester.pumpAndSettle();
      expect(find.byType(SignInScreen), findsOneWidget);
      await tester.tap(find.byKey(SignInScreen.closeKey));
      await tester.pumpAndSettle();
      expect(find.byType(SignInScreen), findsNothing);
      expect(find.byType(LibraryScreen), findsOneWidget);
    });
  });

  testWidgets('the sync badge becomes a Sign in affordance', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          syncServiceProvider.overrideWithValue(FakeSyncService()),
        ],
        child: testApp(
          const Scaffold(
            body: Column(
              children: <Widget>[
                SyncBadge(),
                SizedBox(
                  width: 300,
                  child: SyncBadge(form: SyncBadgeForm.long),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(GuestSignInBadge.badgeKey), findsNWidgets(2));
    expect(find.text('Sign in to sync'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('sync-badge')), findsNothing);
    await tester.tap(find.byKey(GuestSignInBadge.badgeKey).first);
    await tester.pumpAndSettle();
    expect(find.byType(SignInScreen), findsOneWidget);
  });

  group('reader side panel', () {
    final highlight = Highlight(
      id: 'h1',
      userId: kGuestUserId,
      paperId: 'p1',
      selectedText: 'self-attention',
      pageNumber: 3,
      createdAt: DateTime.utc(2026, 10, 20),
    );

    Future<ProviderContainer> pumpReader(WidgetTester tester) async {
      setWindowSize(tester, const Size(1280, 800));
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            ...readerTestOverrides(
              papers: FakePaperRepository(paper: testPaper()),
              highlights: FakeHighlightRepository()..highlights.add(highlight),
            ),
            authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
            readerPanelSlotsProvider.overrideWithValue(appReaderPanelSlots),
            aiServiceProvider.overrideWithValue(FakeAiService()),
            noteRepositoryProvider.overrideWithValue(FakeNoteRepository()),
            connectivityServiceProvider.overrideWithValue(FakeConnectivity()),
            syncServiceProvider.overrideWithValue(FakeSyncService()),
          ],
          child: testApp(const ReaderRouteHost(paperId: 'p1')),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();
      return ProviderScope.containerOf(
        tester.element(find.byType(ReaderRouteHost)),
      );
    }

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('AI tabs stay visible and show the sign-in prompt; '
        'notes work', (tester) async {
      final c = await pumpReader(tester);
      final ctrl = c.read(readerControllerProvider('p1').notifier);

      ctrl.explainHighlight(highlight);
      await settle(tester);
      expect(
        c.read(readerControllerProvider('p1')).panelTab,
        ReaderPanelTab.explanation,
      );
      expect(
        find.byKey(SignInPrompt.keyFor(GuestFeature.explanation)),
        findsOneWidget,
      );
      expect(find.text('Sign in to use explanations'), findsOneWidget);

      ctrl.setPanelTab(ReaderPanelTab.glossary);
      await settle(tester);
      expect(
        find.byKey(SignInPrompt.keyFor(GuestFeature.glossary)),
        findsOneWidget,
      );

      ctrl.setPanelTab(ReaderPanelTab.notes);
      await settle(tester);
      expect(find.byType(NotesTab), findsOneWidget);
      expect(find.byType(SignInPrompt), findsNothing);
      // Every tab is still in the tab bar.
      expect(c.read(readerPanelTabsProvider), ReaderPanelTab.values);
    });
  });
}
