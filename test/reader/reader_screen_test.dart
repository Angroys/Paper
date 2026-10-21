import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:paper/domain/domain.dart';
import 'package:paper/features/panel/reader_side_panel.dart';
import 'package:paper/features/reader/reader_controller.dart';
import 'package:paper/features/reader/reader_screen.dart';
import 'package:paper/features/reader/widgets/highlight_layer.dart';
import 'package:paper/features/reader/widgets/popover.dart';
import 'package:paper/features/reader/widgets/reader_chrome.dart';
import 'package:paper/theme/paper_tokens.dart';

import '../helpers.dart';
import 'reader_fakes.dart';

void main() {
  late FakePaperRepository papers;
  late FakeHighlightRepository highlights;

  setUp(() {
    papers = FakePaperRepository(paper: testPaper());
    highlights = FakeHighlightRepository();
  });

  Future<ProviderContainer> pumpReader(
    WidgetTester tester,
    Size size, {
    List<Override> extra = const <Override>[],
  }) async {
    setWindowSize(tester, size);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          ...readerTestOverrides(papers: papers, highlights: highlights),
          ...extra,
        ],
        child: testApp(const ReaderScreen(paperId: 'p1')),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(ReaderScreen)));
  }

  ReaderController ctrl(ProviderContainer c) =>
      c.read(readerControllerProvider('p1').notifier);

  testWidgets('opens to the (fake) viewport with the expanded toolbar', (
    tester,
  ) async {
    final c = await pumpReader(tester, const Size(1280, 800));
    expect(find.byKey(const ValueKey<String>('fake-viewport')), findsOneWidget);
    expect(find.text('Attention Is All You Need'), findsOneWidget);
    expect(c.read(readerControllerProvider('p1')).isReady, isTrue);
    expect(find.byType(PageNavigator), findsOneWidget);
    expect(find.byType(ZoomControl), findsOneWidget);
    expect(find.text('1 / 10'), findsOneWidget);
    expect(find.byType(ToolDock), findsNothing);
  });

  testWidgets('deleted paper shows the error state', (tester) async {
    papers.paper = null;
    await pumpReader(tester, const Size(1280, 800));
    expect(
      find.byKey(const ValueKey<String>('reader-error-paperDeleted')),
      findsOneWidget,
    );
  });

  testWidgets('compact window uses the ToolDock and the page pill', (
    tester,
  ) async {
    final c = await pumpReader(tester, const Size(420, 800));
    expect(find.byType(ToolDock), findsOneWidget);
    await tester.tap(find.byTooltip('Pen'));
    await tester.pump();
    expect(c.read(readerControllerProvider('p1')).tool, ReaderTool.pen);
  });

  testWidgets('panel opens in split view with the Highlights tab', (
    tester,
  ) async {
    highlights.highlights.add(
      Highlight(
        id: 'h1',
        userId: 'u1',
        paperId: 'p1',
        selectedText: 'scaled dot-product attention',
        createdAt: DateTime.utc(2026),
        pageNumber: 4,
        color: HighlightColor.purple,
        position: const HighlightPosition(
          pageNumber: 4,
          rects: <HighlightRect>[
            HighlightRect(x: 0.1, y: 0.3, width: 0.5, height: 0.02),
          ],
        ),
      ),
    );
    final c = await pumpReader(tester, const Size(1280, 800));
    await tester.tap(find.byTooltip('Show or hide side panel'));
    await tester.pumpAndSettle();
    expect(find.byType(ReaderSidePanel), findsOneWidget);
    final tab = find.byKey(const ValueKey<String>('panel-tab-highlights'));
    await tester.ensureVisible(tab);
    await tester.pumpAndSettle();
    await tester.tap(tab);
    await tester.pumpAndSettle();
    expect(find.text('scaled dot-product attention'), findsOneWidget);
    expect(find.text('p.4'), findsOneWidget);
    await tester.tap(find.text('scaled dot-product attention'));
    await tester.pump();
    final s = c.read(readerControllerProvider('p1'));
    expect(s.navRequest?.pageNumber, 4);
    expect(s.flashHighlightId, 'h1');
    expect(s.returnPage, 1);
    expect(find.text('Back to page 1'), findsOneWidget);
  });

  testWidgets('panel tab slots are injectable for the screens agent', (
    tester,
  ) async {
    final c = await pumpReader(
      tester,
      const Size(1280, 800),
      extra: <Override>[
        readerPanelSlotsProvider.overrideWithValue(
          ReaderPanelSlots(
            notes: (context, panel) =>
                Text('notes for page ${panel.currentPage}'),
          ),
        ),
      ],
    );
    ctrl(c).openPanel(ReaderPanelTab.notes);
    await tester.pumpAndSettle();
    expect(find.text('notes for page 1'), findsOneWidget);
  });

  testWidgets('selection popover: colour tap saves a highlight', (
    tester,
  ) async {
    final c = await pumpReader(tester, const Size(1280, 800));
    ctrl(c).setSelection(
      const ReaderTextSelection(
        pageNumber: 2,
        text: 'multi-head attention',
        rects: <HighlightRect>[
          HighlightRect(x: 0.1, y: 0.3, width: 0.4, height: 0.02),
        ],
        anchor: ReaderAnchor(
          pageNumber: 2,
          rect: Rect.fromLTWH(0.1, 0.3, 0.4, 0.02),
          local: Rect.fromLTWH(300, 400, 200, 16),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Explain'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('swatch-green')));
    await tester.pumpAndSettle();
    expect(highlights.highlights.single.color, HighlightColor.green);
    expect(highlights.highlights.single.selectedText, 'multi-head attention');
    expect(find.text('Highlight added.'), findsOneWidget);
    expect(find.text('Explain'), findsNothing);
  });

  testWidgets('popovers fade only under reduced motion (P13)', (tester) async {
    setWindowSize(tester, const Size(1280, 800));
    await tester.pumpWidget(
      ProviderScope(
        overrides: readerTestOverrides(papers: papers, highlights: highlights),
        child: testApp(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: const ReaderScreen(paperId: 'p1'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(
      tester.element(find.byType(ReaderScreen)),
    );
    ctrl(c).setSelection(
      const ReaderTextSelection(
        pageNumber: 1,
        text: 'x',
        rects: <HighlightRect>[],
        anchor: ReaderAnchor(
          pageNumber: 1,
          rect: Rect.zero,
          local: Rect.fromLTWH(300, 400, 10, 10),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(PaperMotion.fast);
    expect(find.text('Explain'), findsOneWidget);
    final popover = find.byType(AnchoredPopover);
    final fade = tester.widget<FadeTransition>(
      find.descendant(of: popover, matching: find.byType(FadeTransition)).first,
    );
    final slide = tester.widget<SlideTransition>(
      find
          .descendant(of: popover, matching: find.byType(SlideTransition))
          .first,
    );
    expect(fade.opacity.value, 1.0, reason: 'fade capped at fast');
    expect(slide.position.value, Offset.zero, reason: 'no translate');
  });

  testWidgets('wash painter: one multiply layer per hue', (tester) async {
    await tester.pumpWidget(
      testApp(
        Center(
          child: SizedBox(
            width: 300,
            height: 400,
            child: HighlightWashLayer(
              pageSize: const Size(600, 800),
              colors: PaperHighlightColors.whitePaper,
              wash: const PageWash(
                byHue: <HighlightColor, List<Rect>>{
                  HighlightColor.yellow: <Rect>[
                    Rect.fromLTWH(0.1, 0.1, 0.5, 0.02),
                    Rect.fromLTWH(0.1, 0.2, 0.5, 0.02),
                  ],
                  HighlightColor.blue: <Rect>[
                    Rect.fromLTWH(0.1, 0.3, 0.5, 0.02),
                  ],
                },
              ),
            ),
          ),
        ),
      ),
    );
    final paint = find.descendant(
      of: find.byType(HighlightWashLayer),
      matching: find.byType(CustomPaint),
    );
    final calls = <String>[];
    expect(
      paint,
      paints..everything((method, args) {
        if (method == #saveLayer) {
          final p = args[1]! as Paint;
          calls.add(
            'layer ${p.blendMode.name} ${p.color.a.toStringAsFixed(2)}',
          );
        } else if (method == #drawRRect) {
          calls.add(
            'rrect ${(args[1]! as Paint).color.toARGB32().toRadixString(16)}',
          );
        } else if (method == #restore) {
          calls.add('restore');
        }
        return true;
      }),
    );
    final y = PaperHighlightColor.yellow.wash.toARGB32().toRadixString(16);
    final b = PaperHighlightColor.blue.wash.toARGB32().toRadixString(16);
    expect(calls.take(7), <String>[
      'layer multiply 0.10',
      'rrect $y',
      'rrect $y',
      'restore',
      'layer multiply 0.10',
      'rrect $b',
      'restore',
    ]);
    final painter =
        tester.widget<CustomPaint>(paint).painter! as HighlightWashPainter;
    expect(painter.colors.restAlpha, 0.10);
    expect(painter.colors.blendMode, BlendMode.multiply);
  });

  test('P14: no banned widgets under lib/features/reader', () {
    final banned = RegExp(
      r'\b(Opacity\(|BackdropFilter|ImageFilter\.blur|ShaderMask|AnimatedSize|'
      r'SizeTransition|AnimatedCrossFade|Hero\(|Timer\.periodic)',
    );
    final offenders = <String>[];
    for (final f in Directory(
      'lib/features/reader',
    ).listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trimLeft();
        if (line.startsWith('//')) continue;
        if (banned.hasMatch(line)) offenders.add('${f.path}:${i + 1}');
      }
    }
    expect(offenders, isEmpty);
  });
}
