// Web-parity screenshot harness (design/web-parity/app/).
//
// Renders every app screen that has a paper.college reference shot in
// design/web-parity/reference/ at 1280×800 and 800×1280 (DPR 1, like the
// references), with the real Geist / Geist Mono fonts, the real SVG icons,
// fake repositories and fixture data (no network, no AI). Each PNG is named
// after its reference so the two pair up by basename.
//
// It only writes files when asked to, so normal runs stay deterministic:
//
//   flutter test --tags screenshots --dart-define=PAPER_SCREENSHOTS=true \
//     test/screenshots
//
// pdfium does not run under `flutter test`, so the reader uses a placeholder
// viewport: the web pane geometry (24 padding, 16 between pages, white pages
// with a 1px white/10 hairline) with a crop of the reference's first page
// (fixtures/pdf_page_placeholder.png) as every page's image.
@Tags(<String>['screenshots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:paper/ai/ai_providers.dart';
import 'package:paper/app/app_settings.dart';
import 'package:paper/app/app_shell.dart';
import 'package:paper/auth/auth_providers.dart';
import 'package:paper/core/core_providers.dart';
import 'package:paper/core/env.dart';
import 'package:paper/data/data_providers.dart';
import 'package:paper/domain/domain.dart';
import 'package:paper/features/auth/sign_in_screen.dart';
import 'package:paper/features/library/library_controller.dart';
import 'package:paper/features/library/library_screen.dart';
import 'package:paper/features/panel/glossary_tab.dart';
import 'package:paper/features/panel/notes_tab.dart';
import 'package:paper/features/panel/panel_session.dart';
import 'package:paper/features/panel/panel_slots.dart';
import 'package:paper/features/panel/reader_side_panel.dart';
import 'package:paper/features/reader/reader_controller.dart';
import 'package:paper/features/reader/reader_route.dart';
import 'package:paper/features/reader/reader_viewport.dart';
import 'package:paper/features/settings/settings_screen.dart';
import 'package:paper/sync/sync_providers.dart';
import 'package:paper/theme/paper_tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/fakes.dart';
import '../features/feature_fakes.dart';
import '../helpers.dart';
import '../reader/reader_fakes.dart';

const bool _enabled = bool.fromEnvironment('PAPER_SCREENSHOTS');
const String _outDir = 'design/web-parity/app';
const List<Size> _sizes = <Size>[Size(1280, 800), Size(800, 1280)];

String _suffix(Size s) => '${s.width.toInt()}x${s.height.toInt()}';

const AppUser _ada = AppUser(
  id: 'u1',
  email: 'reader@example.com',
  displayName: 'Ada Reader',
);

Future<void> _loadFonts() async {
  Future<ByteData> font(String f) async =>
      ByteData.sublistView(await File('assets/fonts/$f').readAsBytes());
  final sans = FontLoader(PaperTypography.sans);
  for (final w in <String>['Regular', 'Medium', 'SemiBold', 'Bold']) {
    sans.addFont(font('Geist-$w.ttf'));
  }
  await sans.load();
  final mono = FontLoader(PaperTypography.mono);
  for (final w in <String>['Regular', 'Medium', 'SemiBold']) {
    mono.addFont(font('GeistMono-$w.ttf'));
  }
  await mono.load();
}

GlobalKey _boundary = GlobalKey(debugLabel: 'screenshot');

Widget _frame(List<Override> overrides, Widget home) => RepaintBoundary(
  key: _boundary = GlobalKey(debugLabel: 'screenshot'),
  child: ProviderScope(overrides: overrides, child: testApp(home)),
);

/// Pumps frames while letting real async work (SVG / image decoding) run.
Future<void> _settle(WidgetTester tester, {int rounds = 4}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _shoot(WidgetTester tester, String name, Size size) async {
  await _settle(tester);
  final file = File('$_outDir/$name.${_suffix(size)}.png');
  await tester.runAsync(() async {
    final boundary =
        _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

// ---------------------------------------------------------------------------
// Fixture data
// ---------------------------------------------------------------------------

List<Paper> _papers() => <Paper>[
  Paper(
    id: 'p1',
    userId: 'u1',
    title:
        'Lightning-Fast Image Inversion and Editing for Text-to-Image '
        'Diffusion Models',
    uploadedAt: DateTime.utc(2026, 10, 14),
    lastOpenedAt: DateTime.utc(2026, 10, 19, 9),
    readAt: DateTime.utc(2026, 10, 18),
    downloadState: DownloadState.downloaded,
  ),
  Paper(
    id: 'p2',
    userId: 'u1',
    title: 'Classifier-Free Diffusion Guidance',
    uploadedAt: DateTime.utc(2026, 10, 11),
    lastOpenedAt: DateTime.utc(2026, 10, 17, 9),
    downloadState: DownloadState.downloaded,
  ),
  Paper(
    id: 'p3',
    userId: 'u1',
    title: 'Prompt-to-Prompt Image Editing with Cross Attention Control',
    uploadedAt: DateTime.utc(2026, 10, 8),
  ),
];

const String _nrTerm = 'Newton-Raphson';
const String _diTerm = 'Diffusion inversion';
const String _nlTerm = 'Noise latent';

const Map<String, String> _explanations = <String, String>{
  _nrTerm:
      'A classic way to solve an equation by repeatedly guessing, measuring '
      'how wrong the guess is, and jumping along the slope towards the '
      'answer.',
  _diTerm:
      'Running a diffusion model backwards: given a finished image (and its '
      'prompt), find the starting noise that would generate that exact '
      'image again.',
  _nlTerm:
      'The random starting point a diffusion model turns into an image; '
      'changing it changes the picture.',
};

const Map<String, int> _ageDays = <String, int>{
  _nrTerm: 1,
  _diTerm: 1,
  _nlTerm: 2,
};

List<GlossaryTerm> _glossary() => <GlossaryTerm>[
  for (final (term, tags, rating) in <(String, List<String>, int?)>[
    (_nrTerm, <String>['method'], 4),
    (_diTerm, <String>['method', 'computer vision'], 5),
    (_nlTerm, <String>['concept'], null),
    ('Classifier-free guidance', <String>['method'], 3),
    ('DDIM scheduler', <String>['method', 'diffusion'], null),
  ])
    GlossaryTerm(
      id: 'g-$term',
      userId: 'u1',
      paperId: 'p1',
      term: term,
      normalizedTerm: term.toLowerCase(),
      explanation:
          _explanations[term] ??
          'A plain-words explanation of $term, written for this paper.',
      tags: tags,
      rating: rating,
      createdAt: DateTime.utc(2026, 10, 20 - (_ageDays[term] ?? 3)),
    ),
];

Highlight _highlight(String id, String text, int page, HighlightColor color) =>
    Highlight(
      id: id,
      userId: 'u1',
      paperId: 'p1',
      selectedText: text,
      pageNumber: page,
      color: color,
      createdAt: DateTime.utc(2026, 10, 19, 10),
      position: HighlightPosition(
        pageNumber: page,
        rects: const <HighlightRect>[
          HighlightRect(x: 0.2, y: 0.4, width: 0.4, height: 0.02),
        ],
      ),
    );

/// Answers explain requests with the fixture text; ratings succeed.
class _ScreenshotAi extends FakeAiService {
  @override
  Future<AiResult<Explanation>> explain(ExplanationRequest request) async =>
      AiSuccess<Explanation>(
        Explanation(
          term: request.term,
          explanation: _explanations[request.term] ?? 'Plain words.',
          createdAt: DateTime.utc(2026, 10, 20 - (_ageDays[request.term] ?? 1)),
          glossaryTermId: 'g-${request.term}',
        ),
      );

  @override
  Future<AiResult<List<GlossaryTerm>>> glossary(String paperId) async =>
      AiSuccess<List<GlossaryTerm>>(_glossary());
}

/// pdfium-free viewport: the web pane geometry with placeholder pages.
class _PlaceholderViewport extends ConsumerStatefulWidget {
  const _PlaceholderViewport({required this.args});

  final ReaderViewportArgs args;

  @override
  ConsumerState<_PlaceholderViewport> createState() =>
      _PlaceholderViewportState();
}

class _PlaceholderViewportState extends ConsumerState<_PlaceholderViewport> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      if (!mounted) return;
      ref
          .read(readerControllerProvider(widget.args.paperId).notifier)
          .documentLoaded(pageCount: 12);
    });
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: PaperWeb.gray950,
    child: LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth - kPagePadding * 2;
        final h = w * 11 / 8.5;
        Widget page() => DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            border: Border.all(color: PaperWeb.white10),
          ),
          child: SizedBox(
            width: w,
            height: h,
            child: ColoredBox(
              color: const Color(0xFFFFFFFF),
              child: Align(
                alignment: Alignment.topCenter,
                child: Image.file(
                  File('test/screenshots/fixtures/pdf_page_placeholder.png'),
                  width: w,
                  fit: BoxFit.fitWidth,
                ),
              ),
            ),
          ),
        );
        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.topCenter,
            maxHeight: double.infinity,
            child: Padding(
              padding: const EdgeInsets.all(kPagePadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  page(),
                  const SizedBox(height: kPageGap),
                  page(),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

// ---------------------------------------------------------------------------
// Screens
// ---------------------------------------------------------------------------

class _Env {
  _Env(this.prefs);

  final SharedPreferences prefs;
  final FakeLibraryRepository library = FakeLibraryRepository(_papers());
  final FakeHighlightRepository highlights = FakeHighlightRepository();
  final FakeNoteRepository notes = FakeNoteRepository();
  final _ScreenshotAi ai = _ScreenshotAi();
  late final FakePaperRepository readerPapers = FakePaperRepository(
    paper: _papers().first,
  );

  List<Override> shell({
    AuthState auth = const AuthState.signedIn(_ada),
    bool papers = true,
  }) => <Override>[
    envProvider.overrideWithValue(
      const Env(
        supabaseUrl: 'https://example.invalid',
        supabaseAnonKey: 'screenshot',
        paperApiBaseUrl: Env.defaultPaperApiBaseUrl,
      ),
    ),
    sharedPreferencesProvider.overrideWithValue(prefs),
    authRepositoryProvider.overrideWithValue(FakeAuthRepository(auth)),
    if (papers) paperRepositoryProvider.overrideWithValue(library),
    noteRepositoryProvider.overrideWithValue(notes),
    connectivityServiceProvider.overrideWithValue(FakeConnectivity()),
    syncServiceProvider.overrideWithValue(FakeSyncService()),
    aiServiceProvider.overrideWithValue(ai),
    pdfPickerProvider.overrideWithValue(() async => const <PickedPdf>[]),
  ];

  List<Override> reader() => <Override>[
    ...shell(papers: false),
    ...readerTestOverrides(
      papers: readerPapers,
      highlights: highlights,
      fakeViewport: false,
    ),
    readerViewportBuilderProvider.overrideWithValue(
      (context, args) => _PlaceholderViewport(args: args),
    ),
    readerPanelSlotsProvider.overrideWithValue(appReaderPanelSlots),
    noteIdFactoryProvider.overrideWithValue(() => 'n-new'),
  ];
}

Widget _shell(int index, Widget child) =>
    AppShell(selectedIndex: index, onDestinationSelected: (_) {}, child: child);

void main() {
  late _Env env;

  setUpAll(() async {
    if (_enabled) await _loadFonts();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    env = _Env(await SharedPreferences.getInstance());
    env.highlights.highlights.addAll(<Highlight>[
      _highlight('h1', 'Newton-Raphson', 2, HighlightColor.yellow),
      _highlight('h2', 'deterministic schedulers', 2, HighlightColor.purple),
      _highlight('h3', 'guidance term', 3, HighlightColor.green),
    ]);
    env.notes.notes.add(
      Note(
        id: 'n1',
        paperId: 'p1',
        highlightId: 'h1',
        pageNumber: 2,
        quotedExcerpt: 'Newton-Raphson',
        body:
            'The NR step only needs a couple of iterations per timestep. '
            'Compare with the fixed-point methods in §2.',
        createdAt: DateTime.utc(2026, 10, 19, 11),
        updatedAt: DateTime.utc(2026, 10, 19, 11),
      ),
    );
  });

  /// Real shadows (flutter_test flattens them by default).
  void shadows(WidgetTester tester) {
    debugDisableShadows = false;
  }

  Future<void> disposeAll(WidgetTester tester) async {
    await disposeTree(tester);
    await tester.pump(const Duration(seconds: 10));
    debugDisableShadows = true;
  }

  for (final size in _sizes) {
    final s = _suffix(size);

    testWidgets('library $s', skip: !_enabled, (tester) async {
      shadows(tester);
      setWindowSize(tester, size);
      await tester.pumpWidget(
        _frame(env.shell(), _shell(0, const LibraryScreen())),
      );
      await _shoot(tester, 'library', size);
      await tester.tap(find.byKey(LibraryScreen.importButtonKey));
      await _shoot(tester, 'library.add-paper-open', size);
      await disposeAll(tester);
    });

    testWidgets('settings $s', skip: !_enabled, (tester) async {
      shadows(tester);
      setWindowSize(tester, size);
      await tester.pumpWidget(
        _frame(env.shell(), _shell(1, const SettingsScreen())),
      );
      await _shoot(tester, 'settings', size);
      await disposeAll(tester);
    });

    testWidgets('sign-in $s', skip: !_enabled, (tester) async {
      shadows(tester);
      setWindowSize(tester, size);
      await tester.pumpWidget(
        _frame(
          env.shell(auth: const AuthState.signedOut()),
          const SignInScreen(),
        ),
      );
      await _shoot(tester, 'sign-in', size);
      await tester.tap(find.byKey(SignInScreen.emailFieldKey));
      await _shoot(tester, 'sign-in.focus-email', size);
      await disposeAll(tester);
    });

    testWidgets('reader $s', skip: !_enabled, (tester) async {
      shadows(tester);
      setWindowSize(tester, size);
      await tester.pumpWidget(
        _frame(env.reader(), const ReaderRouteHost(paperId: 'p1')),
      );
      await _settle(tester);
      final c = ProviderScope.containerOf(
        tester.element(find.byType(ReaderRouteHost)),
      );
      final reader = c.read(readerControllerProvider('p1').notifier);
      final stack = c.read(explanationStackProvider('p1').notifier);

      // Docked (≥ 1024) / overlay (800) panel with the explanation stack,
      // oldest explained first so Newton-Raphson ends on top.
      reader.openPanel(ReaderPanelTab.explanation);
      for (final t in <String>[_nlTerm, _diTerm, _nrTerm]) {
        await stack.explain(ExplanationRequest(term: t, paperId: 'p1'));
      }
      final ids = <String, String>{
        for (final e in c.read(explanationStackProvider('p1')).entries)
          e.term: e.id,
      };
      await stack.rate(ids[_nrTerm]!, 4);
      await stack.rate(ids[_diTerm]!, 5);
      await _shoot(tester, 'reader', size);

      // App-only panel tabs (no web counterpart; paired with reader.*).
      reader.setPanelTab(ReaderPanelTab.highlights);
      await _shoot(tester, 'reader.panel-highlights', size);
      reader.setPanelTab(ReaderPanelTab.notes);
      await _shoot(tester, 'reader.panel-notes', size);

      // Glossary (panel tab; the web shows it on the project page).
      reader.setPanelTab(ReaderPanelTab.glossary);
      await _shoot(tester, 'glossary', size);
      await tester.tap(find.text(_nrTerm).last);
      await _shoot(tester, 'glossary.entry-expanded', size);
      await tester.tap(find.text(_nrTerm).last);
      await tester.enterText(
        find.descendant(
          of: find.byType(GlossaryTab),
          matching: find.byType(EditableText),
        ),
        'diff',
      );
      await _shoot(tester, 'glossary.search', size);
      await tester.enterText(
        find.descendant(
          of: find.byType(GlossaryTab),
          matching: find.byType(EditableText),
        ),
        '',
      );
      FocusManager.instance.primaryFocus?.unfocus();

      // Selection popover, anchored over a line of the first page. The
      // docked panel stays open (like the web); the 800 overlay would cover
      // the selection, so it is closed there.
      reader.setPanelTab(ReaderPanelTab.explanation);
      if (size.width < 1024) reader.closePanel();
      final w = tester.getSize(find.byType(_PlaceholderViewport)).width;
      final anchor = Rect.fromLTWH(w * 0.30, 330, w * 0.22, 18);
      reader.setSelection(
        ReaderTextSelection(
          pageNumber: 1,
          text: 'Image Inversion',
          rects: const <HighlightRect>[],
          anchor: ReaderAnchor(
            pageNumber: 1,
            rect: const Rect.fromLTWH(0.3, 0.3, 0.22, 0.02),
            local: anchor,
          ),
        ),
      );
      await _shoot(tester, 'reader.selection-popover', size);
      reader.clearSelection();

      // Panel hidden: full-width pane + the show-panel button.
      reader.closePanel();
      await _shoot(tester, 'reader.panel-hidden', size);

      // Floating explanation popover (panel hidden), anchored to a term:
      // the app's equivalent of reader-android.term-click-focus-lock.
      final h = env.highlights.highlights.first;
      reader.selectHighlight(
        h.id,
        anchor: ReaderAnchor(
          pageNumber: 1,
          rect: const Rect.fromLTWH(0.3, 0.3, 0.2, 0.02),
          local: Rect.fromLTWH(w * 0.35, 300, w * 0.18, 18),
        ),
      );
      reader.explainHighlight(h);
      await _settle(tester);
      await _shoot(tester, 'reader-android.term-click-focus-lock', size);

      await disposeAll(tester);
    });
  }
}
