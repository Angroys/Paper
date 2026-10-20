import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_providers.dart';
import '../domain/domain.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/library/library_screen.dart';
import '../features/reader/reader_screen.dart';
import '../features/settings/settings_screen.dart';
import 'app_shell.dart';
import 'routes.dart';

/// Auth gate for go_router. Pure so it can be unit tested.
///
/// - not configured: everything is reachable (dev / tests).
/// - unknown (session restore running): stay put; the splash covers it.
/// - signed out: only /sign-in.
/// - signed in: /sign-in bounces to /library.
String? authRedirect(AuthState auth, String location) {
  final atSignIn = location == AppRoutes.signIn;
  switch (auth.status) {
    case AuthStatus.notConfigured:
    case AuthStatus.unknown:
      return null;
    case AuthStatus.signedOut:
      return atSignIn ? null : AppRoutes.signIn;
    case AuthStatus.signedIn:
      return atSignIn ? AppRoutes.library : null;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  final refresh = _StreamListenable(auth.watchAuthState());
  final router = GoRouter(
    initialLocation: AppRoutes.library,
    refreshListenable: refresh,
    redirect: (context, state) =>
        authRedirect(auth.currentState, state.matchedLocation),
    routes: <RouteBase>[
      GoRoute(path: '/', redirect: (_, _) => AppRoutes.library),
      GoRoute(
        path: AppRoutes.signIn,
        builder: (context, state) => const SignInScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (i) =>
              shell.goBranch(i, initialLocation: i == shell.currentIndex),
          child: shell,
        ),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.library,
                builder: (context, state) => const LibraryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.settings,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      // Full-screen route: the shell nav never coexists with the PDF.
      GoRoute(
        path: AppRoutes.readerPattern,
        builder: (context, state) =>
            ReaderScreen(paperId: state.pathParameters['paperId']!),
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

/// Bridges a stream to the [Listenable] go_router re-evaluates on.
class _StreamListenable extends ChangeNotifier {
  _StreamListenable(Stream<Object?> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _sub;

  @override
  void dispose() {
    unawaited(_sub.cancel());
    super.dispose();
  }
}
