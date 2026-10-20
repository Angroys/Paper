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

/// Minimal themed + localised MaterialApp for widget tests.
Widget testApp(Widget home, {ThemeMode themeMode = ThemeMode.dark}) =>
    MaterialApp(
      theme: PaperTheme.light(),
      darkTheme: PaperTheme.dark(),
      themeMode: themeMode,
      localizationsDelegates: const <LocalizationsDelegate<Object?>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );
