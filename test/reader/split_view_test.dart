import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper/features/panel/panel_layout.dart';
import 'package:paper/features/panel/split_view.dart';
import 'package:paper/theme/paper_tokens.dart';

import '../helpers.dart';

const Key readerKey = ValueKey<String>('reader');
const Key panelKey = ValueKey<String>('panel');

class _Harness extends StatelessWidget {
  const _Harness({required this.open, this.onLayout});

  final ValueNotifier<bool> open;
  final ValueChanged<PanelLayout>? onLayout;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: open,
    builder: (context, isOpen, _) => ReaderSplitView(
      open: isOpen,
      onClose: () => open.value = false,
      onLayoutChanged: onLayout,
      reader: const ColoredBox(key: readerKey, color: Color(0xFFE5E5E5)),
      panel: const ColoredBox(key: panelKey, color: Color(0xFFFFFFFF)),
    ),
  );
}

Future<ValueNotifier<bool>> pumpSplit(
  WidgetTester tester,
  Size size, {
  bool open = false,
  bool reduceMotion = false,
  ValueChanged<PanelLayout>? onLayout,
}) async {
  setWindowSize(tester, size);
  final notifier = ValueNotifier<bool>(open);
  addTearDown(notifier.dispose);
  Widget child = Scaffold(
    body: _Harness(open: notifier, onLayout: onLayout),
  );
  if (reduceMotion) {
    child = Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: Scaffold(
          body: _Harness(open: notifier, onLayout: onLayout),
        ),
      ),
    );
  }
  await tester.pumpWidget(testApp(child));
  await tester.pumpAndSettle();
  return notifier;
}

double readerWidth(WidgetTester tester) =>
    tester.getSize(find.byKey(readerKey)).width;

void main() {
  group('resolvePanelLayout', () {
    test('compact -> bottom sheet, medium -> overlay', () {
      expect(
        resolvePanelLayout(
          width: 400,
          height: 800,
          windowClass: PaperWindowClass.compact,
        ).mode,
        PaperSidePanelMode.bottomSheet,
      );
      final medium = resolvePanelLayout(
        width: 700,
        height: 900,
        windowClass: PaperWindowClass.medium,
      );
      expect(medium.mode, PaperSidePanelMode.overlay);
      expect(medium.defaultWidth, PaperBreakpoints.sidePanelMedium);
      expect(medium.maxWidth, closeTo(595, 1e-9));
    });

    test('expanded+ -> split with class widths and PDF minimum', () {
      final large = resolvePanelLayout(
        width: 1280,
        height: 800,
        windowClass: PaperWindowClass.large,
      );
      expect(large.mode, PaperSidePanelMode.split);
      expect(large.defaultWidth, PaperBreakpoints.sidePanelLarge);
      expect(large.minWidth, 300);
      expect(large.maxWidth, 640);
      final xl = resolvePanelLayout(
        width: 1600,
        height: 1000,
        windowClass: PaperWindowClass.extraLarge,
      );
      expect(xl.defaultWidth, PaperBreakpoints.sidePanelExtraLarge);
      expect(xl.maxWidth, 720, reason: '45% of 1600; PDF keeps >= 720');
      expect(xl.clampWidth(10), 320);
      expect(xl.clampWidth(5000), 720);
    });

    test('short windows and the overlay preference fall back to overlay', () {
      expect(
        resolvePanelLayout(
          width: 1280,
          height: 460,
          windowClass: PaperWindowClass.large,
        ).mode,
        PaperSidePanelMode.overlay,
      );
      expect(
        resolvePanelLayout(
          width: 1280,
          height: 800,
          windowClass: PaperWindowClass.large,
          preferOverlay: true,
        ).mode,
        PaperSidePanelMode.overlay,
      );
    });
  });

  group('ReaderSplitView', () {
    testWidgets('large window: slide, then commit; commit, then slide', (
      tester,
    ) async {
      final open = await pumpSplit(tester, const Size(1280, 800));
      expect(readerWidth(tester), 1280);
      expect(find.byKey(panelKey), findsNothing);

      open.value = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      // Mid-slide the panel overlays the PDF; the viewport has not resized.
      expect(find.byKey(panelKey), findsOneWidget);
      expect(readerWidth(tester), 1280);
      await tester.pumpAndSettle();
      expect(
        readerWidth(tester),
        1280 - PaperBreakpoints.sidePanelLarge - PaperChrome.splitDividerWidth,
      );
      expect(
        tester.getSize(find.byKey(panelKey)).width,
        PaperBreakpoints.sidePanelLarge,
      );

      open.value = false;
      await tester.pump();
      // The viewport widens first, under the still-visible panel.
      expect(readerWidth(tester), 1280);
      expect(find.byKey(panelKey), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byKey(panelKey), findsNothing);
    });

    testWidgets('split drag scales the viewport and commits once on release', (
      tester,
    ) async {
      await pumpSplit(tester, const Size(1280, 800), open: true);
      const committed =
          1280 -
          PaperBreakpoints.sidePanelLarge -
          PaperChrome.splitDividerWidth;
      expect(readerWidth(tester), committed);

      final handle = find.byKey(const ValueKey<String>('split-drag-handle'));
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await gesture.moveBy(const Offset(-60, 0));
      await gesture.moveBy(const Offset(-40, 0));
      await tester.pump();
      await tester.pump();
      // Panel follows the pointer; the PDF keeps its pre-drag layout width
      // and is drawn scaled.
      const dragged = PaperBreakpoints.sidePanelLarge + 100;
      expect(tester.getSize(find.byKey(panelKey)).width, closeTo(dragged, 1));
      expect(readerWidth(tester), committed);
      expect(
        tester.getRect(find.byKey(readerKey)).width,
        closeTo(1280 - dragged - 1, 1),
      );

      await gesture.up();
      await tester.pump();
      expect(readerWidth(tester), closeTo(1280 - dragged - 1, 1));
      await tester.pumpAndSettle(kDoubleTapTimeout);
    });

    testWidgets('dragging below min - 48 snaps the panel closed', (
      tester,
    ) async {
      final open = await pumpSplit(tester, const Size(1280, 800), open: true);
      final handle = find.byKey(const ValueKey<String>('split-drag-handle'));
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await gesture.moveBy(const Offset(200, 0)); // 384 -> 184 < 300 - 48
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(open.value, isFalse);
      expect(find.byKey(panelKey), findsNothing);
      expect(readerWidth(tester), 1280);
    });

    testWidgets('medium window: overlay side sheet, PDF never resizes', (
      tester,
    ) async {
      PanelLayout? layout;
      final open = await pumpSplit(
        tester,
        const Size(700, 900),
        onLayout: (l) => layout = l,
      );
      open.value = true;
      await tester.pumpAndSettle();
      expect(layout?.mode, PaperSidePanelMode.overlay);
      expect(readerWidth(tester), 700);
      expect(
        tester.getSize(find.byKey(panelKey)).width,
        PaperBreakpoints.sidePanelMedium,
      );
      // Scrim tap closes.
      await tester.tapAt(const Offset(50, 450));
      await tester.pumpAndSettle();
      expect(open.value, isFalse);
    });

    testWidgets('compact window: bottom sheet at 40% height', (tester) async {
      final open = await pumpSplit(tester, const Size(400, 800));
      open.value = true;
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('panel-sheet-handle')),
        findsOneWidget,
      );
      expect(readerWidth(tester), 400);
      final panel = tester.getRect(find.byKey(panelKey));
      expect(panel.width, 400);
      expect(panel.bottom, 800);
      expect(panel.height, closeTo(800 * 0.4 - 24, 1));
    });

    testWidgets('reduced motion: one pump reaches the end state (P13)', (
      tester,
    ) async {
      final open = await pumpSplit(
        tester,
        const Size(1280, 800),
        reduceMotion: true,
      );
      open.value = true;
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(
        readerWidth(tester),
        1280 - PaperBreakpoints.sidePanelLarge - PaperChrome.splitDividerWidth,
      );
      expect(
        tester.getRect(find.byKey(panelKey)).left,
        1280 - PaperBreakpoints.sidePanelLarge,
      );
      open.value = false;
      await tester.pump();
      expect(find.byKey(panelKey), findsNothing);
      expect(readerWidth(tester), 1280);
    });

    testWidgets('live window resize commits after the resize settles', (
      tester,
    ) async {
      await pumpSplit(tester, const Size(1280, 800));
      setWindowSize(tester, const Size(1200, 800));
      await tester.pump();
      // Still laid out at the old width, drawn scaled.
      expect(readerWidth(tester), 1280);
      expect(tester.getRect(find.byKey(readerKey)).width, closeTo(1200, 0.5));
      await tester.pump(const Duration(milliseconds: 200));
      expect(readerWidth(tester), 1200);
    });
  });
}
