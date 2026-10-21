import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:paper/app/app_nav_bar.dart';
import 'package:paper/app/app_shell.dart';
import 'package:paper/auth/auth_providers.dart';
import 'package:paper/core/build_flags.dart';
import 'package:paper/domain/domain.dart';
import 'package:paper/features/sync/sync_badge.dart';

import '../features/feature_fakes.dart';
import '../helpers.dart';

Future<List<int>> _pumpShell(
  WidgetTester tester,
  double width, {
  int selected = 0,
  List<Override> overrides = const <Override>[],
}) async {
  final taps = <int>[];
  setWindowSize(tester, Size(width, 800));
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: testApp(
        AppShell(
          selectedIndex: selected,
          onDestinationSelected: taps.add,
          child: const SizedBox.expand(key: ValueKey<String>('body')),
        ),
      ),
    ),
  );
  await tester.pump();
  return taps;
}

void main() {
  for (final width in <double>[480, 639, 640, 800, 1024, 1280, 2560]) {
    testWidgets('one 48px top bar at width $width (no rail/sidebar/bottom)', (
      tester,
    ) async {
      await _pumpShell(tester, width);
      expect(find.byType(AppNavBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
      // 48 + the 1px bottom hairline, at the top; the body (under the
      // dev-only not-configured strip here) starts below it.
      expect(
        tester.getRect(find.byType(AppNavBar)),
        Rect.fromLTWH(0, 0, width, 49),
      );
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('body'))).dy,
        greaterThanOrEqualTo(49),
      );
      expect(tester.getSize(find.byKey(AppNavBar.libraryKey)).height, 36);
      // Labels hide below Tailwind `sm` (640): 36×36 icon-only items.
      final labels = width >= 640;
      expect(find.text('Library'), labels ? findsOneWidget : findsNothing);
      if (!labels) {
        expect(tester.getSize(find.byKey(AppNavBar.libraryKey)).width, 36);
      }
    });
  }

  testWidgets('destinations and the wordmark call back; selection is in '
      'semantics', (tester) async {
    final taps = await _pumpShell(tester, 1280, selected: 1);
    await tester.tap(find.byKey(AppNavBar.libraryKey));
    await tester.tap(find.byKey(AppNavBar.settingsKey));
    await tester.tap(find.byKey(AppNavBar.wordmarkKey));
    expect(taps, <int>[0, 1, 0]);
    expect(
      tester.getSemantics(find.byKey(AppNavBar.settingsKey)),
      isSemantics(
        label: 'Settings',
        isButton: true,
        isSelected: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
  });

  testWidgets('guest: "Sign in" link, no sync badge', (tester) async {
    await _pumpShell(
      tester,
      1280,
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      ],
    );
    expect(find.byKey(AppNavBar.signInKey), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.byType(SyncBadge), findsNothing);
  });

  testWidgets('signed in: 32px sync badge, no sign-in link', (tester) async {
    await _pumpShell(
      tester,
      1280,
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(const AuthState.signedIn(testUser)),
        ),
      ],
    );
    expect(find.byKey(AppNavBar.signInKey), findsNothing);
    expect(
      tester.getSize(find.byKey(const ValueKey<String>('sync-badge'))),
      const Size(32, 32),
    );
  });

  testWidgets('offline-only builds: neither sync nor sign-in', (tester) async {
    await _pumpShell(
      tester,
      1280,
      overrides: [offlineOnlyProvider.overrideWithValue(true)],
    );
    expect(find.byKey(AppNavBar.signInKey), findsNothing);
    expect(find.byType(SyncBadge), findsNothing);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
