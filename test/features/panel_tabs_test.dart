import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:paper/ai/ai_providers.dart';
import 'package:paper/core/core_providers.dart';
import 'package:paper/data/data_providers.dart';
import 'package:paper/domain/domain.dart';
import 'package:paper/features/panel/ai_states.dart';
import 'package:paper/features/panel/panel_session.dart';
import 'package:paper/features/panel/notes_tab.dart';
import 'package:paper/features/panel/panel_slots.dart';
import 'package:paper/features/panel/reader_side_panel.dart';
import 'package:paper/features/reader/reader_controller.dart';
import 'package:paper/features/reader/reader_route.dart';
import 'package:paper/features/reader/reader_screen.dart';
import 'package:paper/ui/ui.dart';
import 'package:paper/sync/sync_providers.dart';

import '../data/fakes.dart';
import '../helpers.dart';
import '../reader/reader_fakes.dart';
import 'feature_fakes.dart';

void main() {
  late FakePaperRepository papers;
  late FakeHighlightRepository highlights;
  late FakeAiService ai;
  late FakeNoteRepository notes;
  late FakeConnectivity connectivity;

  final highlight = Highlight(
    id: 'h1',
    userId: 'u1',
    paperId: 'p1',
    selectedText: 'self-attention',
    contextBefore: 'we use ',
    contextAfter: ' layers',
    pageNumber: 3,
    createdAt: DateTime.utc(2026, 10, 20),
  );

  setUp(() {
    papers = FakePaperRepository(paper: testPaper());
    highlights = FakeHighlightRepository()..highlights.add(highlight);
    ai = FakeAiService();
    notes = FakeNoteRepository();
    connectivity = FakeConnectivity();
  });

  Future<ProviderContainer> pumpReader(
    WidgetTester tester, {
    Size size = const Size(1280, 800),
  }) async {
    setWindowSize(tester, size);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          ...readerTestOverrides(papers: papers, highlights: highlights),
          readerPanelSlotsProvider.overrideWithValue(appReaderPanelSlots),
          aiServiceProvider.overrideWithValue(ai),
          noteRepositoryProvider.overrideWithValue(notes),
          connectivityServiceProvider.overrideWithValue(connectivity),
          syncServiceProvider.overrideWithValue(FakeSyncService()),
          noteIdFactoryProvider.overrideWithValue(() => 'n1'),
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

  ReaderController ctrl(ProviderContainer c) =>
      c.read(readerControllerProvider('p1').notifier);

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('an explain event shows the explanation', (tester) async {
    final c = await pumpReader(tester);
    ctrl(c).explainHighlight(highlight);
    await settle(tester);

    expect(ai.explained.single.term, 'self-attention');
    expect(ai.explained.single.contextBefore, 'we use ');
    expect(ai.explained.single.paperId, 'p1');
    expect(
      c.read(readerControllerProvider('p1')).panelTab,
      ReaderPanelTab.explanation,
    );
    expect(find.text('Plain words for self-attention.'), findsOneWidget);
    expect(find.text('Re-explain for this paper'), findsOneWidget);
    expect(find.byKey(AiUnavailableState.blockKey), findsNothing);
    expect(find.byKey(AiOfflineStrip.stripKey), findsNothing);

    // Same term again: dedup, no second request.
    ctrl(c).explainHighlight(highlight);
    await settle(tester);
    expect(ai.explained, hasLength(1));
  });

  testWidgets('AiUnavailable(rejected) shows aiUnavailable, not offline', (
    tester,
  ) async {
    ai.onExplain = (_) =>
        const AiUnavailable<Explanation>(AiUnavailableReason.rejected);
    final c = await pumpReader(tester);
    ctrl(c).explainHighlight(highlight);
    await settle(tester);

    expect(find.byKey(AiUnavailableState.blockKey), findsOneWidget);
    expect(find.text('Explanations aren’t available'), findsOneWidget);
    expect(find.byKey(AiOfflineStrip.stripKey), findsNothing);
    expect(find.textContaining('offline'), findsNothing);

    // Retry runs the request again.
    ai.onExplain = null;
    await tester.tap(find.text('Try again'));
    await settle(tester);
    expect(find.byKey(AiUnavailableState.blockKey), findsNothing);
    expect(find.text('Plain words for self-attention.'), findsOneWidget);
  });

  testWidgets('offline shows the offline state and a queued card', (
    tester,
  ) async {
    connectivity.online = false;
    final c = await pumpReader(tester);
    ctrl(c).explainHighlight(highlight);
    await settle(tester);

    expect(ai.explained, isEmpty);
    expect(find.byKey(AiOfflineStrip.stripKey), findsOneWidget);
    expect(find.text('Waiting for a connection'), findsOneWidget);
    expect(find.byKey(AiUnavailableState.blockKey), findsNothing);

    // Back online: the queued card runs by itself.
    connectivity.set(true);
    await settle(tester);
    expect(ai.explained, hasLength(1));
    expect(find.byKey(AiOfflineStrip.stripKey), findsNothing);
    expect(find.text('Plain words for self-attention.'), findsOneWidget);
  });

  testWidgets('offline with a cached explanation shows it with the caption', (
    tester,
  ) async {
    connectivity.online = false;
    ai.cached = Explanation(
      term: 'self-attention',
      explanation: 'Cached words.',
      createdAt: DateTime.utc(2026, 10, 1),
      fromCache: true,
    );
    final c = await pumpReader(tester);
    ctrl(c).explainHighlight(highlight);
    await settle(tester);
    expect(find.text('Cached words.'), findsOneWidget);
    expect(find.text('Saved earlier. Connect to re-explain.'), findsOneWidget);
  });

  testWidgets('retryable failures offer Try again', (tester) async {
    ai.onExplain = (_) => const AiFailure<Explanation>('500');
    final c = await pumpReader(tester);
    ctrl(c).explainHighlight(highlight);
    await settle(tester);
    expect(find.text('Couldn’t explain this. Try again.'), findsOneWidget);
    ai.onExplain = null;
    await tester.tap(find.text('Try again'));
    await settle(tester);
    expect(find.text('Plain words for self-attention.'), findsOneWidget);
  });

  testWidgets('a note request opens a draft that autosaves as device-only', (
    tester,
  ) async {
    final c = await pumpReader(tester);
    ctrl(c).noteForHighlight(highlight);
    await settle(tester);

    expect(
      c.read(readerControllerProvider('p1')).panelTab,
      ReaderPanelTab.notes,
    );
    final field = find.byKey(const ValueKey<String>('note-body-n1'));
    expect(field, findsOneWidget);
    expect(find.text('self-attention'), findsWidgets); // quote

    await tester.enterText(field, 'Key idea');
    await tester.pump(kNoteAutosaveDebounce);
    await settle(tester);
    expect(notes.notes.single.body, 'Key idea');
    expect(notes.notes.single.highlightId, 'h1');
    expect(notes.notes.single.syncState, SyncState.localOnly);
    expect(find.textContaining('On this device only'), findsOneWidget);
  });

  testWidgets('notes: page note composer and delete with undo', (tester) async {
    final c = await pumpReader(tester);
    ctrl(c).openPanel(ReaderPanelTab.notes);
    await settle(tester);
    expect(find.text('No notes yet'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey<String>('notes-composer')),
      'Remember this page',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(notes.notes.single.body, 'Remember this page');
    expect(notes.notes.single.pageNumber, 1);

    await tester.tap(find.byTooltip('More').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete note'));
    await settle(tester);
    expect(notes.notes, isEmpty);
    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(notes.notes.single.body, 'Remember this page');
  });

  testWidgets('glossary lists and filters terms', (tester) async {
    GlossaryTerm term(String id, String t) => GlossaryTerm(
      id: id,
      userId: 'u1',
      paperId: 'p1',
      term: t,
      normalizedTerm: t.toLowerCase(),
      explanation: 'About $t.',
      createdAt: DateTime.utc(2026, 10, 1),
    );
    ai.glossaryResult = AiSuccess<List<GlossaryTerm>>(<GlossaryTerm>[
      term('g1', 'softmax'),
      term('g2', 'positional encoding'),
    ]);
    final c = await pumpReader(tester);
    ctrl(c).openPanel(ReaderPanelTab.glossary);
    await settle(tester);
    expect(find.text('softmax'), findsOneWidget);
    expect(find.text('positional encoding'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey<String>('glossary-filter')),
      'soft',
    );
    await settle(tester);
    expect(find.text('softmax'), findsOneWidget);
    expect(find.text('positional encoding'), findsNothing);
  });

  testWidgets('glossary: AiUnavailable(signedOut) is not shown as offline', (
    tester,
  ) async {
    ai.glossaryResult = const AiUnavailable<List<GlossaryTerm>>(
      AiUnavailableReason.signedOut,
    );
    final c = await pumpReader(tester);
    ctrl(c).openPanel(ReaderPanelTab.glossary);
    await settle(tester);
    expect(find.byKey(AiUnavailableState.blockKey), findsOneWidget);
    expect(find.byKey(AiOfflineStrip.stripKey), findsNothing);
  });

  testWidgets('docked (>= 1024) opens the panel; overlay (800) stays closed', (
    tester,
  ) async {
    final c = await pumpReader(tester);
    expect(c.read(readerControllerProvider('p1')).panelOpen, isTrue);
    // Panel header: 40 + 1px border; hide button closes it.
    await tester.tap(find.byKey(const ValueKey<String>('panel-hide')));
    await tester.pumpAndSettle();
    expect(c.read(readerControllerProvider('p1')).panelOpen, isFalse);
    expect(
      find.byKey(const ValueKey<String>('reader-show-panel')),
      findsOneWidget,
    );

    final c2 = await pumpReader(tester, size: const Size(800, 1280));
    expect(c2.read(readerControllerProvider('p1')).panelOpen, isFalse);
  });

  testWidgets('panel closed: Explain shows the floating explanation popover', (
    tester,
  ) async {
    final c = await pumpReader(tester, size: const Size(800, 1280));
    final reader = ctrl(c);
    reader.selectHighlight(
      'h1',
      anchor: const ReaderAnchor(
        pageNumber: 3,
        rect: Rect.fromLTWH(0.1, 0.3, 0.2, 0.02),
        local: Rect.fromLTWH(300, 400, 120, 16),
      ),
    );
    await tester.pump();
    reader.explainHighlight(highlight);
    await settle(tester);

    final state = c.read(readerControllerProvider('p1'));
    expect(state.panelOpen, isFalse);
    expect(state.panelTab, ReaderPanelTab.explanation);
    expect(state.explainAnchor, isNotNull);
    final shell = find.byKey(FloatingExplanationPopover.shellKey);
    expect(shell, findsOneWidget);
    expect(tester.getSize(shell).width, 320);
    // 8 below the explained word.
    expect(tester.getRect(shell).top - 53, closeTo(400 + 16 + 8, 0.5));
    expect(find.text('Plain words for self-attention.'), findsOneWidget);

    // × closes the popover; the card stays in the Explanation tab.
    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    expect(shell, findsNothing);
    expect(c.read(explanationStackProvider('p1')).entries, hasLength(1));
  });

  testWidgets('glossary: card, chevron, date, rating and no-match copy', (
    tester,
  ) async {
    ai.glossaryResult = AiSuccess<List<GlossaryTerm>>(<GlossaryTerm>[
      GlossaryTerm(
        id: 'g1',
        userId: 'u1',
        paperId: 'p1',
        term: 'softmax',
        normalizedTerm: 'softmax',
        explanation: 'About softmax.',
        createdAt: DateTime.utc(2026, 10, 20, 12),
        rating: 4,
      ),
    ]);
    final c = await pumpReader(tester);
    ctrl(c).openPanel(ReaderPanelTab.glossary);
    await settle(tester);
    expect(find.text('Oct 20, 2026'), findsOneWidget);
    expect(find.text('About softmax.'), findsNothing);

    await tester.tap(find.text('softmax'));
    await settle(tester);
    expect(find.text('About softmax.'), findsOneWidget);
    expect(find.text('4/5'), findsOneWidget);
    expect(find.byKey(PaperRating.keyFor(4)), findsOneWidget);
    expect(find.text('Explain again'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey<String>('glossary-filter')),
      'zzz',
    );
    await settle(tester);
    expect(
      find.text(
        'No terms match your search. Try another word or clear the filters.',
      ),
      findsOneWidget,
    );
  });

  test('motion.md §1.7: no banned widgets in the side panel', () {
    final banned = RegExp(
      r'\b(Opacity|AnimatedOpacity|BackdropFilter|AnimatedSize|Hero|'
      r'SizeTransition|ExpansionTile)\(',
    );
    for (final f in Directory('lib/features/panel').listSync()) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      expect(banned.hasMatch(f.readAsStringSync()), isFalse, reason: f.path);
    }
  });
}
