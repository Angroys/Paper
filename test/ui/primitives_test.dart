import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper/theme/paper_tokens.dart';
import 'package:paper/ui/ui.dart';

import '../helpers.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  setWindowSize(tester, const Size(1280, 800));
  await tester.pumpWidget(testApp(Scaffold(body: Center(child: child))));
  await tester.pump();
}

Size _size(WidgetTester tester, Key key) => tester.getSize(find.byKey(key));

void main() {
  group('WebBreakpoint', () {
    test('Tailwind min widths, inclusive, no hysteresis', () {
      expect(WebBreakpoint.fromWidth(0), WebBreakpoint.base);
      expect(WebBreakpoint.fromWidth(639.9), WebBreakpoint.base);
      expect(WebBreakpoint.fromWidth(640), WebBreakpoint.sm);
      expect(WebBreakpoint.fromWidth(767), WebBreakpoint.sm);
      expect(WebBreakpoint.fromWidth(768), WebBreakpoint.md);
      expect(WebBreakpoint.fromWidth(800), WebBreakpoint.md);
      expect(WebBreakpoint.fromWidth(1024), WebBreakpoint.lg);
      expect(WebBreakpoint.fromWidth(1279), WebBreakpoint.lg);
      expect(WebBreakpoint.fromWidth(1280), WebBreakpoint.xl);
      expect(WebBreakpoint.fromWidth(1536), WebBreakpoint.xxl);
      expect(WebBreakpoint.lg >= WebBreakpoint.md, isTrue);
      expect(WebBreakpoint.sm.isLgUp, isFalse);
    });

    testWidgets('of(context) reads the full window width', (tester) async {
      setWindowSize(tester, const Size(800, 1280));
      late WebBreakpoint b;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            b = WebBreakpoint.of(context);
            return const SizedBox();
          },
        ),
      );
      expect(b, WebBreakpoint.md);
    });
  });

  testWidgets('buttons use web heights (36 / 38 bordered / 32 / 26 / 24)', (
    tester,
  ) async {
    await _pump(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PaperButton.primary(
            key: const Key('p'),
            label: 'Sign in',
            onPressed: () {},
          ),
          PaperButton.secondary(
            key: const Key('s'),
            label: 'Continue with Google',
            onPressed: () {},
          ),
          PaperButton.ghost(
            key: const Key('g'),
            label: 'Open',
            onPressed: null,
          ),
          PaperButton.primary(
            key: const Key('sm'),
            label: 'Undo',
            size: PaperButtonSize.sm,
            onPressed: () {},
          ),
          PaperButton.destructive(
            key: const Key('d'),
            label: 'Delete',
            onPressed: () {},
          ),
          PaperButton.quiet(
            key: const Key('q'),
            label: 'Remove',
            onPressed: () {},
          ),
          const PaperButton(
            key: Key('pop'),
            label: 'Copy',
            variant: PaperButtonVariant.popoverNeutral,
            onPressed: null,
          ),
        ],
      ),
    );
    expect(_size(tester, const Key('p')).height, 36);
    expect(_size(tester, const Key('s')).height, 38);
    expect(_size(tester, const Key('g')).height, 36);
    expect(_size(tester, const Key('sm')).height, 32);
    expect(_size(tester, const Key('d')).height, 26);
    expect(_size(tester, const Key('q')).height, 24);
    expect(_size(tester, const Key('pop')).height, 32);
  });

  testWidgets('primary button: no ink, Enter activates, disabled is inert', (
    tester,
  ) async {
    var taps = 0;
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await _pump(
      tester,
      PaperButton.primary(
        label: 'Go',
        focusNode: focus,
        onPressed: () => taps++,
      ),
    );
    expect(find.byType(InkWell), findsNothing);
    await tester.tap(find.text('Go'));
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(taps, 2);

    await _pump(
      tester,
      const PaperButton.primary(label: 'Go', onPressed: null),
    );
    await tester.tap(find.text('Go'), warnIfMissed: false);
    expect(taps, 2);
  });

  testWidgets('icon buttons: 24 / 32 / 36 boxes with tooltip semantics', (
    tester,
  ) async {
    await _pump(
      tester,
      Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PaperIconButton(
            key: const Key('i24'),
            size: PaperIconButtonSize.s24,
            tooltip: 'Close',
            icon: const PaperCloseGlyph(),
            onPressed: () {},
          ),
          PaperIconButton(
            key: const Key('i32'),
            tooltip: 'Hide explanations',
            icon: const PaperIcon(PaperIcons.panelHide, size: 20),
            onPressed: () {},
          ),
          PaperIconButton(
            key: const Key('i36'),
            size: PaperIconButtonSize.s36Bordered,
            tooltip: 'Show explanations',
            icon: const PaperIcon(PaperIcons.panelShow, size: 20),
            onPressed: () {},
          ),
        ],
      ),
    );
    expect(_size(tester, const Key('i24')), const Size(24, 24));
    expect(_size(tester, const Key('i32')), const Size(32, 32));
    expect(_size(tester, const Key('i36')), const Size(36, 36));
    expect(find.bySemanticsLabel('Hide explanations'), findsOneWidget);
  });

  testWidgets('text fields are 38 (md), 30 (sm), 26 (xs) tall and use '
      'PaperTypography.input', (tester) async {
    await _pump(
      tester,
      const SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            PaperTextField(fieldKey: Key('md'), hintText: 'Search'),
            PaperTextField(
              fieldKey: Key('sm'),
              size: PaperTextFieldSize.sm,
              hintText: 'Rename',
            ),
            PaperTextField(
              fieldKey: Key('xs'),
              size: PaperTextFieldSize.xs,
              hintText: 'Find',
            ),
          ],
        ),
      ),
    );
    expect(_size(tester, const Key('md')).height, 38);
    expect(_size(tester, const Key('sm')).height, 30);
    expect(_size(tester, const Key('xs')).height, 26);
    final field = tester.widget<TextField>(find.byKey(const Key('md')));
    expect(field.style?.fontSize, 14);
    expect(field.style?.height, 20 / 14);

    // Focus keeps the height (2px accent edge drawn inside).
    await tester.tap(find.byKey(const Key('md')));
    await tester.pump();
    expect(_size(tester, const Key('md')).height, 38);
  });

  testWidgets('search field shows a clear button only with text', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await _pump(
      tester,
      SizedBox(
        width: 320,
        child: PaperSearchField(
          controller: controller,
          hintText: 'Search terms',
          clearTooltip: 'Clear search',
        ),
      ),
    );
    expect(find.byTooltip('Clear search'), findsNothing);
    await tester.enterText(find.byType(TextField), 'attention');
    await tester.pump();
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();
    expect(controller.text, isEmpty);
  });

  testWidgets('checkbox: 16 / 20 boxes that toggle', (tester) async {
    bool? value = false;
    await _pump(
      tester,
      StatefulBuilder(
        builder: (context, setState) => Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            PaperCheckbox(
              key: const Key('c16'),
              value: value,
              onChanged: (v) => setState(() => value = v),
            ),
            PaperCheckbox(
              key: const Key('c20'),
              size: 20,
              value: value,
              onChanged: (v) => setState(() => value = v),
            ),
          ],
        ),
      ),
    );
    expect(_size(tester, const Key('c16')), const Size(16, 16));
    expect(_size(tester, const Key('c20')), const Size(20, 20));
    await tester.tap(find.byKey(const Key('c20')));
    await tester.pump();
    expect(value, isTrue);
  });

  testWidgets('segmented (38 / 28) and tabs (24) select by value', (
    tester,
  ) async {
    var picked = 'a';
    var tab = 0;
    await _pump(
      tester,
      StatefulBuilder(
        builder: (context, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            PaperSegmented<String>(
              key: const Key('seg'),
              segments: const <PaperSegment<String>>[
                PaperSegment(value: 'a', label: 'System'),
                PaperSegment(value: 'b', label: 'On'),
              ],
              selected: picked,
              onChanged: (v) => setState(() => picked = v),
            ),
            PaperSegmented<String>(
              key: const Key('segSm'),
              size: PaperSegmentedSize.sm,
              segments: const <PaperSegment<String>>[
                PaperSegment(value: 'a', label: 'Aa'),
              ],
              selected: 'a',
              onChanged: (_) {},
            ),
            PaperTabs(
              key: const Key('tabs'),
              tabs: const <PaperTab>[
                PaperTab(label: 'Notes'),
                PaperTab(label: 'Glossary', showDot: true),
              ],
              selectedIndex: tab,
              onSelected: (i) => setState(() => tab = i),
            ),
          ],
        ),
      ),
    );
    expect(_size(tester, const Key('seg')).height, 38);
    expect(_size(tester, const Key('segSm')).height, 28);
    expect(_size(tester, const Key('tabs')).height, 24);
    await tester.tap(find.text('On'));
    await tester.tap(find.text('Glossary'));
    await tester.pump();
    expect(picked, 'b');
    expect(tab, 1);
  });

  testWidgets('focus ring paints only for keyboard focus', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await _pump(
      tester,
      PaperButton.secondary(
        label: 'Cancel',
        focusNode: focus,
        onPressed: () {},
      ),
    );
    Iterable<PaperFocusRing> rings() =>
        tester.widgetList<PaperFocusRing>(find.byType(PaperFocusRing));

    // Touch: no ring.
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTouch;
    focus.requestFocus();
    await tester.pump();
    expect(rings().single.show, isFalse);

    // Keyboard: ring.
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    await tester.pump();
    expect(rings().single.show, isTrue);
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  testWidgets('toast: one at a time, action + dismiss, auto-dismiss 2 s', (
    tester,
  ) async {
    await _pump(tester, const SizedBox());
    final context = tester.element(find.byType(Scaffold));
    var undone = false;
    showPaperToast(context, message: 'First', dismissTooltip: 'Dismiss');
    showPaperToast(
      context,
      message: 'Paper deleted.',
      dismissTooltip: 'Dismiss',
      actionLabel: 'Undo',
      onAction: () => undone = true,
      duration: const Duration(seconds: 8),
    );
    await tester.pump();
    expect(find.text('First'), findsNothing);
    expect(find.text('Paper deleted.'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pump();
    expect(undone, isTrue);
    expect(find.text('Paper deleted.'), findsNothing);

    showPaperToast(context, message: 'Saved.', dismissTooltip: 'Dismiss');
    await tester.pump();
    expect(find.text('Saved.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Saved.'), findsNothing);
  });

  testWidgets('dialog: 448 max wide card over the web backdrop', (
    tester,
  ) async {
    await _pump(tester, const SizedBox());
    final context = tester.element(find.byType(Scaffold));
    final result = showPaperDialog<bool>(
      context: context,
      builder: (context) => PaperDialog(
        title: 'Delete paper?',
        body: 'This removes it from every device.',
        actions: <Widget>[
          PaperButton.secondary(
            label: 'Cancel',
            onPressed: () => Navigator.pop(context, false),
          ),
          PaperButton.destructive(
            label: 'Delete',
            size: PaperButtonSize.md,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    await tester.pump();
    expect(tester.getSize(find.byType(PaperCard)).width, 448);
    await tester.tap(find.text('Delete'));
    await tester.pump();
    expect(await result, isTrue);
  });

  testWidgets('every PaperIcons asset is bundled and renders', (tester) async {
    await _pump(
      tester,
      Wrap(
        children: <Widget>[
          for (final i in PaperIcons.values)
            PaperIcon(i, color: PaperWeb.accent),
        ],
      ),
    );
    for (final i in PaperIcons.values) {
      final data = await rootBundle.load(i.asset);
      expect(data.lengthInBytes, greaterThan(0), reason: i.asset);
    }
    expect(tester.takeException(), isNull);
  });
}
