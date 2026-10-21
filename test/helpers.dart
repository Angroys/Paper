import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper/l10n/app_localizations.dart';
import 'package:paper/theme/paper_tokens.dart';

/// Sets the logical window size for a widget test (DPR 1).
void setWindowSize(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}

/// Minimal themed + localised MaterialApp for widget tests (dark-only,
/// like the app).
Widget testApp(Widget home) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: PaperTheme.dark(),
  themeMode: ThemeMode.dark,
  localizationsDelegates: const <LocalizationsDelegate<Object?>>[
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

/// Unmounts the tree (disposing the ProviderScope) inside the test, then
/// lets drift's zero-duration stream-close timers run, so no timer is left
/// pending when the test ends.
Future<void> disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
}
