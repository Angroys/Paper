import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper/core/core_providers.dart';
import 'package:paper/data/data_providers.dart';
import 'package:paper/data/local_paper_repository.dart' show maxPdfBytes;
import 'package:paper/domain/domain.dart';
import 'package:paper/features/library/library_controller.dart';
import 'package:paper/features/library/library_screen.dart';
import 'package:paper/features/library/library_widgets.dart';
import 'package:paper/sync/sync_providers.dart';
import 'package:paper/ui/ui.dart';

import '../data/fakes.dart';
import '../helpers.dart';
import 'feature_fakes.dart';

void main() {
  late FakeLibraryRepository repo;
  late FakeConnectivity connectivity;
  late List<PickedPdf> picked;

  setUp(() {
    repo = FakeLibraryRepository(<Paper>[
      libraryPaper('a', 'Attention Is All You Need'),
      libraryPaper('b', 'Diffusion Models Beat GANs'),
      libraryPaper(
        'c',
        'Deep Residual Learning',
        download: DownloadState.notDownloaded,
      ),
    ]);
    connectivity = FakeConnectivity();
    picked = const <PickedPdf>[PickedPdf(path: '/tmp/x.pdf', name: 'x.pdf')];
  });

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(1000, 900),
  }) async {
    setWindowSize(tester, size);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          paperRepositoryProvider.overrideWithValue(repo),
          connectivityServiceProvider.overrideWithValue(connectivity),
          syncServiceProvider.overrideWithValue(FakeSyncService()),
          pdfPickerProvider.overrideWithValue(() async => picked),
        ],
        child: testApp(const LibraryScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Finder title(String t) => find.text(t);

  Future<void> openMenu(WidgetTester tester, String id) async {
    final menu = find.byKey(ValueKey<String>('paper-menu-$id'));
    await tester.ensureVisible(menu);
    await tester.pumpAndSettle();
    await tester.tap(menu);
    await tester.pumpAndSettle();
  }

  Future<void> openAddPanel(WidgetTester tester) async {
    await tester.tap(find.byKey(LibraryScreen.importButtonKey));
    await tester.pumpAndSettle();
  }

  /// Lets a toast time out so no timer outlives the test.
  Future<void> settleToast(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 9));
    await tester.pumpAndSettle();
  }

  testWidgets('search filters the list after the debounce', (tester) async {
    await pump(tester);
    expect(title('Attention Is All You Need'), findsOneWidget);
    expect(title('Diffusion Models Beat GANs'), findsOneWidget);

    await tester.enterText(find.byKey(LibraryScreen.searchFieldKey), 'diffus');
    await tester.pump(const Duration(milliseconds: 50));
    // Still debouncing: nothing filtered yet.
    expect(title('Attention Is All You Need'), findsOneWidget);
    await tester.pump(kLibrarySearchDebounce);
    await tester.pump();
    await tester.pump();
    expect(title('Attention Is All You Need'), findsNothing);
    expect(title('Diffusion Models Beat GANs'), findsOneWidget);
    expect(find.text('1 paper found'), findsOneWidget);

    await tester.enterText(find.byKey(LibraryScreen.searchFieldKey), 'zzz');
    await tester.pump(kLibrarySearchDebounce);
    await tester.pumpAndSettle();
    expect(find.text('No papers match “zzz”'), findsOneWidget);
    await tester.tap(find.text('Clear search').last);
    await tester.pumpAndSettle();
    expect(title('Attention Is All You Need'), findsOneWidget);
  });

  testWidgets('table: header labels, row geometry, read badge, no grid', (
    tester,
  ) async {
    repo.papers[0] = repo.papers[0].copyWith(readAt: DateTime.utc(2026, 10));
    await pump(tester);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Your papers'), findsOneWidget);
    for (final h in <String>[
      'PHOTO',
      'NAME',
      'RATE',
      'STATUS',
      'OPENED',
      'ACTION',
    ]) {
      expect(find.text(h), findsOneWidget, reason: h);
    }
    expect(find.byKey(LibraryScreen.tableKey), findsOneWidget);
    expect(find.text('Read'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byType(GridView), findsNothing);
    expect(find.byType(ReadMeter), findsNWidgets(3));
    expect(find.byType(PaperThumbnail), findsNWidgets(3));
    expect(
      tester.getSize(find.byType(PaperThumbnail).first),
      const Size(48, 64),
    );
    // 88 + 1px divider; the last row has no divider.
    expect(
      tester.getSize(find.byKey(const ValueKey<String>('paper-a'))).height,
      89,
    );
    final search = tester.getSize(find.byKey(LibraryScreen.searchFieldKey));
    expect(search, const Size(320, 38));
  });

  testWidgets('inline rename: empty error, Escape cancels, Enter saves', (
    tester,
  ) async {
    await pump(tester);
    final field = find.byKey(const ValueKey<String>('rename-field'));
    await openMenu(tester, 'a');
    await tester.tap(find.byKey(const ValueKey<String>('paper-rename-a')));
    await tester.pumpAndSettle();
    expect(field, findsOneWidget);
    expect(find.text('Rename paper'), findsNothing); // no dialog at ≥ 640

    await tester.enterText(field, '');
    await tester.pump();
    expect(find.text('Give the paper a title.'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(field, findsNothing);
    expect(repo.calls.where((c) => c.startsWith('rename')), isEmpty);

    await openMenu(tester, 'a');
    await tester.tap(find.byKey(const ValueKey<String>('paper-rename-a')));
    await tester.pumpAndSettle();
    await tester.enterText(field, 'Transformers');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(repo.calls, contains('rename a Transformers'));
    expect(title('Transformers'), findsOneWidget);
    expect(field, findsNothing);
  });

  testWidgets('narrow windows rename through the dialog', (tester) async {
    await pump(tester, size: const Size(420, 900));
    await openMenu(tester, 'a');
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('paper-rename-a')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('paper-rename-a')));
    await tester.pumpAndSettle();
    expect(find.text('Rename paper'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey<String>('rename-field')),
      '',
    );
    await tester.pump();
    expect(find.text('Give the paper a title.'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey<String>('rename-field')),
      'Transformers',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('rename-save')));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('rename a Transformers'));
  });

  testWidgets('delete shows an undo toast; undo restores', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey<String>('paper-delete-a')));
    await tester.pumpAndSettle();
    expect(title('Attention Is All You Need'), findsNothing);
    expect(find.text('Deleted “Attention Is All You Need”.'), findsOneWidget);
    expect(find.byType(PaperToast), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(repo.calls, containsAllInOrder(<String>['delete a', 'undo a']));
    expect(title('Attention Is All You Need'), findsOneWidget);
    expect(find.byType(PaperToast), findsNothing);
  });

  testWidgets('the delete toast stays for the 8 s undo window', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey<String>('paper-delete-b')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 7));
    expect(find.byType(PaperToast), findsOneWidget);
    await settleToast(tester);
    expect(find.byType(PaperToast), findsNothing);
  });

  testWidgets('add-paper disclosure: two equal cards, Close label, toggles', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byKey(LibraryScreen.addPanelKey), findsNothing);
    expect(find.text('Add paper'), findsOneWidget);
    await openAddPanel(tester);
    expect(find.byKey(LibraryScreen.addPanelKey), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    expect(find.text('No file chosen'), findsOneWidget);
    Rect card(String text) => tester.getRect(
      find.ancestor(of: find.text(text), matching: find.byType(PaperCard)),
    );
    final file = card('From a file');
    final link = card('Add a paper from a link');
    // Side by side at ≥ 768, gap 16, equal height.
    expect(file.top, link.top);
    expect(file.height, link.height);
    expect(link.left - file.right, 16);
    await openAddPanel(tester);
    expect(find.byKey(LibraryScreen.addPanelKey), findsNothing);
    expect(find.text('Add paper'), findsOneWidget);
  });

  Future<void> importFileExpecting(
    WidgetTester tester,
    Object error,
    String message,
  ) async {
    repo.importError = error;
    await pump(tester);
    await openAddPanel(tester);
    await tester.tap(find.byKey(LibraryScreen.chooseFileKey));
    await tester.pumpAndSettle();
    expect(find.text(message), findsOneWidget, reason: '$error');
    expect(find.text('Try again'), findsOneWidget);
  }

  testWidgets('import: file too large', (tester) async {
    await importFileExpecting(
      tester,
      const FileTooLargeException(maxPdfBytes),
      'That file is over 20 MB. Try a smaller PDF.',
    );
  });

  testWidgets('import: invalid PDF', (tester) async {
    await importFileExpecting(
      tester,
      const InvalidPdfException(),
      'That file isn’t a PDF Paper can open. Choose another file.',
    );
  });

  testWidgets('import: auth expired', (tester) async {
    await importFileExpecting(
      tester,
      const AuthExpiredException(),
      'Your session expired. Sign in again to continue.',
    );
  });

  testWidgets('import from link: invalid link, offline error, offline card', (
    tester,
  ) async {
    repo.importError = const OfflineException();
    await pump(tester);
    await openAddPanel(tester);
    final field = find.byKey(const ValueKey<String>('import-url-field'));
    final submit = find.byKey(const ValueKey<String>('import-url-submit'));
    await tester.enterText(field, 'not a link');
    await tester.tap(submit);
    await tester.pump();
    expect(find.textContaining('doesn’t look like a link'), findsOneWidget);

    await tester.enterText(field, 'https://arxiv.org/pdf/1706.03762');
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('Adding from a link needs a connection.'), findsOneWidget);

    // Now actually offline: the link card is disabled with its reason.
    await tester.tap(find.text('Dismiss'));
    connectivity.set(false);
    await tester.pumpAndSettle();
    expect(tester.widget<PaperButton>(submit).onPressed, isNull);
    expect(tester.widget<TextField>(field).enabled, isFalse);
    expect(find.text('Adding from a link needs a connection.'), findsOneWidget);
  });

  testWidgets('import success adds the paper', (tester) async {
    repo.importResult = libraryPaper('d', 'Fresh Import');
    await pump(tester);
    await openAddPanel(tester);
    await tester.tap(find.byKey(LibraryScreen.chooseFileKey));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('file x.pdf'));
    expect(title('Fresh Import'), findsOneWidget);
    expect(find.text('Added to your library.'), findsOneWidget);
    expect(find.text('x.pdf'), findsOneWidget);
  });

  testWidgets('import from link success', (tester) async {
    repo.importResult = libraryPaper('d', 'Linked Import');
    await pump(tester);
    await openAddPanel(tester);
    await tester.enterText(
      find.byKey(const ValueKey<String>('import-url-field')),
      'https://arxiv.org/pdf/1706.03762',
    );
    await tester.tap(find.byKey(const ValueKey<String>('import-url-submit')));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('url https://arxiv.org/pdf/1706.03762'));
    expect(find.text('Added to your library.'), findsOneWidget);
  });

  testWidgets('cloud-only paper offline: dimmed, chip, open blocked', (
    tester,
  ) async {
    connectivity.online = false;
    await pump(tester);
    final badges = tester.widgetList<DownloadStateBadge>(
      find.byType(DownloadStateBadge),
    );
    expect(
      badges.map((b) => b.state),
      contains(PaperDownloadBadge.unavailableOffline),
    );
    // The chip says "Not downloaded"; the reason is its tooltip.
    expect(find.text('Not downloaded'), findsOneWidget);
    expect(
      tester
          .widgetList<PaperThumbnail>(find.byType(PaperThumbnail))
          .where((t) => t.dimmed),
      hasLength(1),
    );
    await tester.tap(title('Deep Residual Learning'));
    await tester.pump();
    expect(
      find.text('This paper isn’t downloaded. Connect to open it.'),
      findsOneWidget,
    );
    await settleToast(tester);
  });

  testWidgets('empty library state', (tester) async {
    repo.papers.clear();
    await pump(tester);
    expect(find.text('No papers yet'), findsOneWidget);
    expect(find.text('Your papers'), findsNothing);
    expect(find.byKey(LibraryScreen.searchFieldKey), findsNothing);
    await openAddPanel(tester);
    expect(find.text('From a file'), findsOneWidget);
  });

  testWidgets('sort menu and filter segments', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey<String>('library-sort')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Title A–Z').last);
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(
      tester.element(find.byType(LibraryScreen)),
    );
    expect(c.read(libraryViewProvider).sort, PaperSort.title);

    await tester.tap(find.byKey(const ValueKey<String>('filter-downloaded')));
    await tester.pumpAndSettle();
    expect(title('Deep Residual Learning'), findsNothing);
    expect(title('Attention Is All You Need'), findsOneWidget);
  });

  testWidgets('narrow windows: the table scrolls sideways in its card', (
    tester,
  ) async {
    await pump(tester, size: const Size(420, 900));
    expect(find.byKey(LibraryScreen.tableKey), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(LibraryScreen.tableKey),
        matching: find.byType(SingleChildScrollView),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
