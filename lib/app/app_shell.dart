import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/build_flags.dart';
import '../core/core_providers.dart';
import '../theme/paper_tokens.dart';
import '../theme/theme_x.dart';
import '../ui/ui.dart';
import 'app_nav_bar.dart';

/// Scaffold for the Library / Settings branches: the 48px [AppNavBar] on
/// top (both orientations, every width), then the branch body
/// (design/web-parity/screens/README.md §2). No rail, sidebar or bottom
/// bar. The reader and sign-in are full-screen routes outside this shell.
///
/// No `SafeArea`: the bar and body backgrounds bleed under cutouts and the
/// bar insets its own content; screens inset theirs by `viewPadding`.
class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.child,
  });

  /// 0 = Library, 1 = Settings.
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(offlineOnlyProvider);
    // Offline-only builds are meant to run without Supabase config.
    final configured = offline || ref.watch(envProvider).isConfigured;
    final pad = MediaQuery.viewPaddingOf(context);
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppNavBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
          ),
          if (!configured) const _NotConfiguredStrip(),
          Expanded(
            // The bar consumed the top inset.
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                viewPadding: pad.copyWith(top: 0),
                padding: MediaQuery.paddingOf(context).copyWith(top: 0),
              ),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// Developer-facing strip for builds without --dart-define config. Not
/// localised on purpose: release builds are always configured.
class _NotConfiguredStrip extends StatelessWidget {
  const _NotConfiguredStrip();

  @override
  Widget build(BuildContext context) {
    final colors = context.paper;
    return Semantics(
      liveRegion: true,
      child: ColoredBox(
        color: colors.surfaceVariant,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PaperSpacing.lg,
            vertical: PaperSpacing.sm,
          ),
          child: Row(
            children: <Widget>[
              PaperIcon(PaperIcons.cloudOff, color: colors.textMuted),
              const SizedBox(width: PaperSpacing.sm),
              Expanded(
                child: Text(
                  'Not configured: running without Supabase '
                  '(pass --dart-define-from-file=env/<name>.json).',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
