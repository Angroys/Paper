import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../domain/domain.dart';
import '../l10n/app_localizations.dart';
import '../sync/sync_providers.dart';
import '../theme/paper_tokens.dart';
import 'app_settings.dart';
import 'app_shortcuts.dart';
import 'deep_link_listener.dart';
import 'router.dart';

/// Root widget. Wrap in a `ProviderScope` (main.dart / tests).
class PaperApp extends ConsumerWidget {
  const PaperApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      debugShowCheckedModeBanner: false,
      theme: PaperTheme.light(),
      darkTheme: PaperTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      // Theme switches are instant (no colour lerp across the whole tree).
      themeAnimationDuration: Duration.zero,
      localizationsDelegates: const <LocalizationsDelegate<Object?>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (context, child) => _ReduceMotion(
        child: AppShortcuts(
          child: SyncLifecycle(
            child: DeepLinkListener(child: child ?? const SizedBox.shrink()),
          ),
        ),
      ),
    );
  }
}

/// Settings › Appearance › Reduce motion = On forces
/// `MediaQuery.disableAnimations` for the whole app (motion.md §3.1).
class _ReduceMotion extends ConsumerWidget {
  const _ReduceMotion({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forced = ref.watch(reduceMotionProvider);
    if (!forced) return child;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child,
    );
  }
}

/// Starts the outbox [SyncService] once a user is signed in and stops it
/// on sign-out (or when the session ends).
class SyncLifecycle extends ConsumerStatefulWidget {
  const SyncLifecycle({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SyncLifecycle> createState() => _SyncLifecycleState();
}

class _SyncLifecycleState extends ConsumerState<SyncLifecycle> {
  SyncService? _running;

  @override
  void initState() {
    super.initState();
    ref.listenManual<AsyncValue<AuthState>>(
      authStateProvider,
      (_, next) => _apply(next.value),
      fireImmediately: true,
    );
  }

  void _apply(AuthState? auth) {
    if (auth == null) return;
    if (auth.isSignedIn) {
      final service = ref.read(syncServiceProvider);
      if (identical(service, _running)) return;
      _running = service;
      unawaited(service.start());
    } else if (auth.status == AuthStatus.signedOut) {
      final service = _running;
      _running = null;
      if (service != null) unawaited(service.stop());
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
