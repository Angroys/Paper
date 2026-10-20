import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../core/build_flags.dart';
import '../core/core_providers.dart';
import '../domain/domain.dart';
import 'router.dart';
import 'routes.dart';

/// Routes `paper://` links: `auth-callback` to [AuthRepository], and
/// `paper/<id>` to the reader. Handles the cold-start link once.
class DeepLinkListener extends ConsumerStatefulWidget {
  const DeepLinkListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DeepLinkListener> createState() => _DeepLinkListenerState();
}

class _DeepLinkListenerState extends ConsumerState<DeepLinkListener> {
  StreamSubscription<Uri>? _sub;

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
    switch (DeepLinkTarget.parse(uri)) {
      case AuthCallbackLink(:final uri):
        // Inert in offline-only builds (no sign-in).
        if (ref.read(offlineOnlyProvider)) {
          debugPrint('deep links: offline-only build, ignored $uri');
          return;
        }
        unawaited(ref.read(authRepositoryProvider).handleAuthCallback(uri));
      case OpenPaperLink(:final paperId):
        ref.read(routerProvider).go(AppRoutes.reader(paperId));
      case null:
        debugPrint('deep links: ignored $uri');
    }
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
