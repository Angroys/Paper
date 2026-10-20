import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../theme/paper_tokens.dart';
import 'app_settings.dart';
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
      builder: (context, child) =>
          DeepLinkListener(child: child ?? const SizedBox.shrink()),
    );
  }
}
