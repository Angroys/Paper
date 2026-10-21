import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/build_flags.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/library/library_screen.dart';
import '../features/reader/reader_route.dart';
import '../features/settings/settings_screen.dart';
import 'app_shell.dart';
import 'routes.dart';

/// The app router. There is no auth gate: sign-in is optional, so the app
/// always opens on the library (as a guest when nobody is signed in) and
/// nothing redirects to `/sign-in`. Sign-in is pushed on top of the current
/// route (`openSignIn`) and pops itself once signed in, so the user lands
/// where they were. Offline-only builds have no sign-in route at all.
final routerProvider = Provider<GoRouter>((ref) {
  final offline = ref.watch(offlineOnlyProvider);
  final router = GoRouter(
    initialLocation: AppRoutes.library,
    routes: <RouteBase>[
      GoRoute(path: '/', redirect: (_, _) => AppRoutes.library),
      if (!offline)
        GoRoute(
          path: AppRoutes.signIn,
          builder: (context, state) => SignInScreen(
            sessionExpired: state.uri.queryParameters['expired'] == '1',
          ),
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
        // Fade-through with a colour curtain: the PDF is never under an
        // opacity layer (motion.md §2.1, P9).
        pageBuilder: (context, state) => buildReaderPage(state),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
