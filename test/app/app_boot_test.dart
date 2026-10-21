import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper/app/app.dart';
import 'package:paper/app/app_nav_bar.dart';
import 'package:paper/app/routes.dart';
import 'package:paper/app/router.dart';
import 'package:paper/features/reader/reader_screen.dart';

import '../helpers.dart';

void main() {
  testWidgets('boots in not-configured mode on the library', (tester) async {
    setWindowSize(tester, const Size(1280, 800));
    await tester.pumpWidget(const ProviderScope(child: PaperApp()));
    await tester.pumpAndSettle();

    expect(find.text('Library'), findsWidgets);
    expect(find.text('No papers yet'), findsOneWidget);
    expect(find.textContaining('Not configured'), findsOneWidget);
    expect(find.byType(AppNavBar), findsOneWidget);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(app.themeAnimationDuration, Duration.zero);
    await disposeTree(tester);
  });

  testWidgets('navigates to settings and to the full-screen reader', (
    tester,
  ) async {
    setWindowSize(tester, const Size(1280, 800));
    await tester.pumpWidget(const ProviderScope(child: PaperApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings').first);
    await tester.pumpAndSettle();
    // One column of section cards (no master–detail).
    expect(
      find.byKey(const ValueKey<String>('settings-section-appearance')),
      findsOneWidget,
    );
    // Dark-only: no theme selector, only Reduce motion.
    expect(find.text('Theme'), findsNothing);
    expect(find.text('Reduce motion'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PaperApp)),
    );
    container.read(routerProvider).go(AppRoutes.reader('abc-123'));
    await tester.pumpAndSettle();
    expect(find.byType(ReaderScreen), findsOneWidget);
    // The reader is outside the shell: no navigation chrome.
    expect(find.byType(AppNavBar), findsNothing);
    await disposeTree(tester);
  });
}
