import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper/auth/auth_providers.dart';
import 'package:paper/core/core_providers.dart';
import 'package:paper/domain/domain.dart';
import 'package:paper/features/auth/sign_in_screen.dart';

import '../data/fakes.dart';
import '../helpers.dart';
import 'feature_fakes.dart';

void main() {
  late FakeAuthRepository auth;
  late StreamController<AuthFailedException> errors;
  late FakeConnectivity connectivity;

  setUp(() {
    auth = FakeAuthRepository();
    errors = StreamController<AuthFailedException>.broadcast();
    connectivity = FakeConnectivity();
  });

  tearDown(() => errors.close());

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(420, 900),
  }) async {
    setWindowSize(tester, size);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          authErrorsProvider.overrideWith((ref) => errors.stream),
          connectivityServiceProvider.overrideWithValue(connectivity),
        ],
        child: testApp(const SignInScreen()),
      ),
    );
    await tester.pump();
  }

  testWidgets('Google tap calls the repository and shows the browser wait', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(SignInScreen.googleButtonKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(auth.calls, <String>['google']);
    expect(find.text('Finish signing in in your browser'), findsWidgets);
    expect(find.text('Reopen browser'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(SignInScreen.googleButtonKey), findsOneWidget);
  });

  testWidgets('desktop paste-link fallback calls handleAuthCallback', (
    tester,
  ) async {
    await pump(tester, size: const Size(1280, 900));
    await tester.tap(find.byKey(SignInScreen.googleButtonKey));
    await tester.pump();
    expect(find.byKey(SignInScreen.pasteLinkFieldKey), findsNothing);

    await tester.pump(kDeepLinkMissingDelay + const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(SignInScreen.pasteLinkFieldKey), findsOneWidget);

    // Not an auth link: inline error, nothing called.
    await tester.enterText(
      find.byKey(SignInScreen.pasteLinkFieldKey),
      'https://example.com',
    );
    await tester.tap(find.byKey(SignInScreen.pasteLinkSubmitKey));
    await tester.pump();
    expect(auth.callbacks, isEmpty);
    expect(find.textContaining('isn’t a Paper sign-in link'), findsOneWidget);

    const link = 'paper://auth-callback?code=abc123';
    await tester.enterText(find.byKey(SignInScreen.pasteLinkFieldKey), link);
    await tester.tap(find.byKey(SignInScreen.pasteLinkSubmitKey));
    await tester.pump();
    expect(auth.callbacks, <Uri>[Uri.parse(link)]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('callback failures show the AuthErrorBanner', (tester) async {
    await pump(tester);
    expect(find.byKey(SignInScreen.bannerKey), findsNothing);
    errors.add(const AuthFailedException(AuthFailureReason.cancelled));
    await tester.pumpAndSettle();
    expect(find.byKey(SignInScreen.bannerKey), findsOneWidget);
    expect(find.text('Google sign-in was cancelled.'), findsOneWidget);
  });

  testWidgets('bad credentials are an inline password error', (tester) async {
    await pump(tester);
    auth.failWith = const AuthFailedException(
      AuthFailureReason.invalidCredentials,
    );
    await tester.enterText(find.byKey(SignInScreen.emailFieldKey), 'a@b.co');
    await tester.enterText(find.byKey(SignInScreen.passwordFieldKey), 'nope');
    await tester.pump();
    await tester.tap(find.byKey(SignInScreen.submitKey));
    await tester.pumpAndSettle();
    expect(auth.calls, <String>['email a@b.co']);
    expect(
      find.text('That email and password don’t match. Try again.'),
      findsOneWidget,
    );
  });

  testWidgets('offline disables Google and shows the offline banner', (
    tester,
  ) async {
    connectivity.online = false;
    await pump(tester);
    expect(find.textContaining('You’re offline'), findsOneWidget);
    final google = tester.widget<OutlinedButton>(
      find.byKey(SignInScreen.googleButtonKey),
    );
    expect(google.onPressed, isNull);
  });

  testWidgets('unconfigured builds say sign-in is not set up', (tester) async {
    auth = FakeAuthRepository(const AuthState.notConfigured());
    await pump(tester);
    expect(
      find.text('Sign-in isn’t set up in this build of Paper.'),
      findsOneWidget,
    );
  });
}
