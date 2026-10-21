import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../core/build_flags.dart';
import '../core/core_providers.dart';
import '../domain/domain.dart';
import 'router.dart';
import 'routes.dart';

/// Drops repeats of the same `paper://` link. app_links delivers the
/// launch link through both `getInitialLink()` and `uriLinkStream` (and on
/// Windows it is also in argv), and an OAuth `code` can be exchanged only
/// once: a second exchange fails and would show "Couldn’t finish signing
/// in" although the first one worked.
///
/// * Auth callbacks with a `code` (or tokens): handled once per process.
/// * Anything else: repeats within [window] are dropped.
class DeepLinkDeduper {
  DeepLinkDeduper({
    this.window = const Duration(seconds: 5),
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  final Duration window;
  final DateTime Function() _now;
  final _seenAuth = <String>{};
  final _recent = <String, DateTime>{};

  /// True the first time [uri] should be handled.
  bool accept(Uri uri) {
    final key = uri.toString();
    final target = DeepLinkTarget.parse(uri);
    if (target is AuthCallbackLink &&
        (uri.queryParameters.containsKey('code') ||
            uri.fragment.contains('access_token'))) {
      return _seenAuth.add(key);
    }
    final now = _now();
    _recent.removeWhere((_, at) => now.difference(at) > window);
    if (_recent.containsKey(key)) return false;
    _recent[key] = now;
    return true;
  }
}

/// Routes `paper://` links: `auth-callback` to [AuthRepository], and
/// `paper/<id>` to the reader. Handles the cold-start link once.
///
/// OAuth return (PKCE): the browser opens `paper://auth-callback?code=…`;
/// the code is exchanged by `AuthRepository.handleAuthCallback` on a warm
/// start (link stream) and on a cold start (initial link). On a cold start
/// Supabase may still be initialising (the splash waits at most 2 s), so
/// the exchange first waits for the client; otherwise the code would reach
/// the "not configured" stand-in and be lost.
class DeepLinkListener extends ConsumerStatefulWidget {
  const DeepLinkListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DeepLinkListener> createState() => _DeepLinkListenerState();
}

class _DeepLinkListenerState extends ConsumerState<DeepLinkListener> {
  StreamSubscription<Uri>? _sub;
  final _dedupe = DeepLinkDeduper();

  @override
  void initState() {
    super.initState();
    final service = ref.read(deepLinkServiceProvider);
    _sub = service.links.listen(_handle);
    unawaited(
      service.initialLink().then((uri) {
        if (uri != null && mounted) _handle(uri);
      }),
    );
  }

  void _handle(Uri uri) {
    if (!_dedupe.accept(uri)) {
      debugPrint('deep links: repeat ignored');
      return;
    }
    switch (DeepLinkTarget.parse(uri)) {
      case AuthCallbackLink(:final uri):
        // Inert in offline-only builds (no sign-in).
        if (ref.read(offlineOnlyProvider)) {
          debugPrint('deep links: offline-only build, ignored $uri');
          return;
        }
        unawaited(_completeSignIn(uri));
      case OpenPaperLink(:final paperId):
        ref.read(routerProvider).go(AppRoutes.reader(paperId));
      case null:
        debugPrint('deep links: ignored $uri');
    }
  }

  Future<void> _completeSignIn(Uri uri) async {
    try {
      await ref.read(supabaseReadyProvider.future);
    } on Object catch (e) {
      debugPrint('deep links: Supabase unavailable ($e)');
    }
    if (!mounted) return;
    await ref.read(authRepositoryProvider).handleAuthCallback(uri);
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
