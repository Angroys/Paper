import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper/domain/domain.dart';
import 'package:paper/features/reader/reader_controller.dart';
import 'package:paper/features/reader/reader_shortcuts.dart';

import '../helpers.dart';
import 'reader_fakes.dart';

void main() {
  late FakePaperRepository papers;

  setUp(() => papers = FakePaperRepository(paper: testPaper()));

  Future<ProviderContainer> pumpShortcuts(
    WidgetTester tester, {
    bool singleKey = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: readerTestOverrides(papers: papers),
        child: testApp(
          Scaffold(
            body: ReaderShortcuts(
              paperId: 'p1',
              singleKeyShortcuts: singleKey,
              child: const Column(
                children: <Widget>[
                  TextField(key: ValueKey<String>('field')),
                  Expanded(child: SizedBox.expand()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
  }

  ReaderState state(ProviderContainer c) =>
      c.read(readerControllerProvider('p1'));

  testWidgets('single-key tool shortcuts fire when no text field is focused', (
    tester,
  ) async {
    final c = await pumpShortcuts(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    expect(state(c).tool, ReaderTool.pen);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    expect(state(c).tool, ReaderTool.figure);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    expect(state(c).tool, ReaderTool.highlight, reason: 'H with no selection');
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    expect(state(c).tool, ReaderTool.select);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    expect(state(c).highlightColor, HighlightColor.blue);
  });

  testWidgets('single-key shortcuts are suppressed while a text field has '
      'focus; Esc and Mod chords still work', (tester) async {
    final c = await pumpShortcuts(tester);
    await tester.tap(find.byKey(const ValueKey<String>('field')));
    await tester.pump();
    expect(textInputHasFocus(), isTrue);

    final handledH = await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    expect(handledH, isFalse, reason: 'H falls through to the field');
    expect(state(c).tool, ReaderTool.select);
    expect(state(c).highlightColor, HighlightColor.yellow);
    expect(state(c).navRequest, isNull);

    // Mod+\ toggles the panel even from a text field.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.backslash);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(state(c).panelOpen, isTrue);

    // Esc still works (closes the find bar here).
    c.read(readerControllerProvider('p1').notifier).openSearch();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(state(c).search.open, isFalse);
  });

  testWidgets('the "Single-key shortcuts" setting turns them off', (
    tester,
  ) async {
    final c = await pumpShortcuts(tester, singleKey: false);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    expect(state(c).tool, ReaderTool.select);
    // Chords keep working.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.equal);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(state(c).zoom, 1.25);
  });

  testWidgets('panel tabs, zoom and page shortcuts', (tester) async {
    final c = await pumpShortcuts(tester);
    c
        .read(readerControllerProvider('p1').notifier)
        .documentLoaded(pageCount: 0); // not opening: no-op
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(state(c).panelOpen, isTrue);
    expect(state(c).panelTab, ReaderPanelTab.glossary);
    expect(state(c).zoomRequest?.zoom, 1.0);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    expect(state(c).navRequest?.pageNumber, 2);
  });

  Intent? lookup(
    Map<ShortcutActivator, Intent> map,
    LogicalKeyboardKey key, {
    bool meta = false,
    bool control = false,
    bool alt = false,
    bool shift = false,
  }) {
    for (final e in map.entries) {
      final a = e.key;
      if (a is SingleActivator &&
          a.trigger == key &&
          a.meta == meta &&
          a.control == control &&
          a.alt == alt &&
          a.shift == shift) {
        return e.value;
      }
    }
    return null;
  }

  test('macOS uses Cmd chords, Windows Ctrl', () {
    final mac = readerShortcuts(TargetPlatform.macOS);
    expect(
      lookup(mac, LogicalKeyboardKey.backslash, meta: true),
      isA<TogglePanelIntent>(),
    );
    expect(
      lookup(mac, LogicalKeyboardKey.keyG, meta: true, alt: true),
      isA<GoToPageIntent>(),
    );
    expect(
      lookup(mac, LogicalKeyboardKey.keyG, meta: true),
      isA<FindMatchIntent>(),
    );
    final win = readerShortcuts(TargetPlatform.windows);
    expect(
      lookup(win, LogicalKeyboardKey.keyG, control: true),
      isA<GoToPageIntent>(),
    );
    expect(lookup(win, LogicalKeyboardKey.f3), isA<FindMatchIntent>());
    expect(
      lookup(win, LogicalKeyboardKey.keyH),
      isA<HighlightSelectionIntent>(),
    );
  });
}
