import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper/app/app_shell.dart';

import '../helpers.dart';

Future<void> _pumpShell(WidgetTester tester, double width) async {
  setWindowSize(tester, Size(width, 800));
  await tester.pumpWidget(
    ProviderScope(
      child: testApp(
        AppShell(
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          child: const SizedBox.expand(),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  const cases = <(double, Key)>[
    (480, AppShell.bottomNavKey), // compact (window minimum)
    (599, AppShell.bottomNavKey), // compact
    (600, AppShell.railKey), // medium
    (839, AppShell.railKey), // medium
    (840, AppShell.railKey), // expanded
    (1199, AppShell.railKey), // expanded
    (1200, AppShell.sidebarKey), // large
    (1600, AppShell.sidebarKey), // extraLarge
    (2560, AppShell.sidebarKey), // extraLarge
  ];

  for (final (width, key) in cases) {
    testWidgets('width $width uses $key', (tester) async {
      await _pumpShell(tester, width);
      for (final k in <Key>[
        AppShell.bottomNavKey,
        AppShell.railKey,
        AppShell.sidebarKey,
      ]) {
        expect(find.byKey(k), k == key ? findsOneWidget : findsNothing);
      }
    });
  }

  testWidgets('sidebar is extended at the token width', (tester) async {
    await _pumpShell(tester, 1300);
    final rail = tester.widget<NavigationRail>(find.byKey(AppShell.sidebarKey));
    expect(rail.extended, isTrue);
    expect(rail.minExtendedWidth, 240);

    await _pumpShell(tester, 1700);
    final xl = tester.widget<NavigationRail>(find.byKey(AppShell.sidebarKey));
    expect(xl.minExtendedWidth, 256);
  });

  testWidgets('rail is collapsed with labels', (tester) async {
    await _pumpShell(tester, 700);
    final rail = tester.widget<NavigationRail>(find.byKey(AppShell.railKey));
    expect(rail.extended, isFalse);
    expect(rail.labelType, NavigationRailLabelType.all);
  });

  testWidgets('hysteresis: a few dp past a boundary keeps the old layout', (
    tester,
  ) async {
    await _pumpShell(tester, 590); // compact
    expect(find.byKey(AppShell.bottomNavKey), findsOneWidget);

    await _pumpShell(tester, 603); // only 3dp past 600
    expect(find.byKey(AppShell.bottomNavKey), findsOneWidget);

    await _pumpShell(tester, 610); // >= 8dp past: commit to medium
    expect(find.byKey(AppShell.railKey), findsOneWidget);

    await _pumpShell(tester, 597); // only 3dp below: stay medium
    expect(find.byKey(AppShell.railKey), findsOneWidget);
  });
}
