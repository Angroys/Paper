import 'package:flutter/material.dart';
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

    await tester.enterText(find.byKey(LibraryScreen.searchFieldKey), 'zzz');
    await tester.pump(kLibrarySearchDebounce);
    await tester.pumpAndSettle();
    expect(find.text('No papers match “zzz”'), findsOneWidget);
  });

  Future<void> openMenu(WidgetTester tester, String id, String item) async {
    await tester.tap(find.byKey(ValueKey<String>('paper-menu-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(item).last);
    await tester.pumpAndSettle();
  }

  testWidgets('rename through the dialog', (tester) async {
    await pump(tester);
    await openMenu(tester, 'a', 'Rename');
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
    expect(title('Transformers'), findsOneWidget);
  });

  testWidgets('delete shows an undo snackbar; undo restores', (tester) async {
    await pump(tester);
    await openMenu(tester, 'a', 'Delete');
    expect(title('Attention Is All You Need'), findsNothing);
    expect(find.text('Deleted “Attention Is All You Need”.'), findsOneWidget);
    final bar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(bar.duration, const Duration(seconds: 8));

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(repo.calls, containsAllInOrder(<String>['delete a', 'undo a']));
    expect(title('Attention Is All You Need'), findsOneWidget);
  });

  Future<void> importFileExpecting(
    WidgetTester tester,
    Object error,
    String message,
  ) async {
    repo.importError = error;
    await pump(tester);
    await tester.tap(find.byKey(LibraryScreen.importButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('From a file'));
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

  testWidgets('import from link: offline error and offline-disabled item', (
    tester,
  ) async {
    repo.importError = const OfflineException();
    await pump(tester);
    await tester.tap(find.byKey(LibraryScreen.importButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('From a link'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('import-url-field')),
      'not a link',
    );
    await tester.tap(find.byKey(const ValueKey<String>('import-url-submit')));
    await tester.pump();
    expect(find.textContaining('doesn’t look like a link'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey<String>('import-url-field')),
      'https://arxiv.org/pdf/1706.03762',
    );
    await tester.tap(find.byKey(const ValueKey<String>('import-url-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Adding from a link needs a connection.'), findsOneWidget);

    // Now actually offline: the link item is disabled with its reason.
    connectivity.set(false);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(LibraryScreen.importButtonKey));
    await tester.pumpAndSettle();
    final item = tester.widget<MenuItemButton>(
      find.ancestor(
        of: find.text('From a link'),
        matching: find.byType(MenuItemButton),
      ),
    );
    expect(item.onPressed, isNull);
  });

  testWidgets('import success adds the paper', (tester) async {
    repo.importResult = libraryPaper('d', 'Fresh Import');
    await pump(tester);
    await tester.tap(find.byKey(LibraryScreen.importButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('From a file'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('file x.pdf'));
    expect(title('Fresh Import'), findsOneWidget);
    expect(find.text('Added to your library.'), findsOneWidget);
  });

  testWidgets('cloud-only paper offline: dimmed badge, open blocked', (
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
    await tester.tap(title('Deep Residual Learning'));
    await tester.pump();
    expect(
      find.text('This paper isn’t downloaded. Connect to open it.'),
      findsOneWidget,
    );
  });

  testWidgets('empty library state', (tester) async {
    repo.papers.clear();
    await pump(tester);
    expect(find.text('No papers yet'), findsOneWidget);
    expect(find.text('From a file'), findsOneWidget);
  });

  group('adaptive grid / list', () {
    testWidgets('compact: two-column grid', (tester) async {
      await pump(tester, size: const Size(420, 900));
      expect(find.byKey(LibraryScreen.gridKey), findsOneWidget);
      final grid = tester.widget<GridView>(find.byKey(LibraryScreen.gridKey));
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 2);
    });

    testWidgets('medium: three columns', (tester) async {
      await pump(tester, size: const Size(700, 900));
      final grid = tester.widget<GridView>(find.byKey(LibraryScreen.gridKey));
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 3);
    });

    testWidgets('large on touch: grid', (tester) async {
      await pump(tester, size: const Size(1300, 900));
      expect(find.byKey(LibraryScreen.gridKey), findsOneWidget);
      expect(find.byKey(LibraryScreen.listKey), findsNothing);
    });

    testWidgets('large with a pointer: list by default, toggle back to grid', (
      tester,
    ) async {
      await pump(tester, size: const Size(1300, 900));
      expect(find.byKey(LibraryScreen.listKey), findsOneWidget);
      await tester.tap(find.byTooltip('Grid view'));
      await tester.pumpAndSettle();
      expect(find.byKey(LibraryScreen.gridKey), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  });
}
