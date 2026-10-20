import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/core_providers.dart';
import '../core/window_class.dart';
import '../l10n/app_localizations.dart';
import '../theme/paper_tokens.dart';
import '../theme/theme_x.dart';

/// Window-class-aware scaffold for Library / Settings (layout-system.md
/// §3.1):
///
/// | class | navigation |
/// |---|---|
/// | compact | bottom NavigationBar ([AppShell.bottomNavKey]) |
/// | medium, expanded | collapsed 72dp NavigationRail ([AppShell.railKey]) |
/// | large, extraLarge | extended 240 / 256dp sidebar ([AppShell.sidebarKey]) |
///
/// The reader is a full-screen route outside this shell.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.child,
  });

  static const Key bottomNavKey = Key('appShell.bottomNav');
  static const Key railKey = Key('appShell.rail');
  static const Key sidebarKey = Key('appShell.sidebar');

  /// 0 = Library, 1 = Settings.
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  PaperWindowClass? _windowClass;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final configured = ref.watch(envProvider).isConfigured;
    final destinations = <_Destination>[
      _Destination(Symbols.library_books_rounded, l10n.navLibrary),
      _Destination(Symbols.settings_rounded, l10n.navSettings),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final windowClass = _windowClass = resolveWindowClass(
          constraints.maxWidth,
          previous: _windowClass,
        );
        Widget body = widget.child;
        if (!configured) {
          body = Column(
            children: <Widget>[
              const _NotConfiguredStrip(),
              Expanded(child: body),
            ],
          );
        }

        if (windowClass == PaperWindowClass.compact) {
          return Scaffold(
            body: SafeArea(bottom: false, child: body),
            bottomNavigationBar: NavigationBar(
              key: AppShell.bottomNavKey,
              selectedIndex: widget.selectedIndex,
              onDestinationSelected: widget.onDestinationSelected,
              destinations: <Widget>[
                for (final d in destinations)
                  NavigationDestination(icon: Icon(d.icon), label: d.label),
              ],
            ),
          );
        }

        final extended = windowClass.usesSidebar;
        return Scaffold(
          body: SafeArea(
            child: Row(
              children: <Widget>[
                NavigationRail(
                  key: extended ? AppShell.sidebarKey : AppShell.railKey,
                  extended: extended,
                  minWidth: PaperBreakpoints.navRailWidth,
                  minExtendedWidth: windowClass.navigationWidth,
                  labelType: extended
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  selectedIndex: widget.selectedIndex,
                  onDestinationSelected: widget.onDestinationSelected,
                  leading: extended
                      ? _SidebarHeader(title: l10n.appName)
                      : null,
                  destinations: <NavigationRailDestination>[
                    for (final d in destinations)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        label: Text(d.label),
                      ),
                  ],
                ),
                VerticalDivider(width: 1, color: context.paper.border),
                Expanded(child: body),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Destination {
  const _Destination(this.icon, this.label);
  final IconData icon;
  final String label;
}

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: PaperSpacing.lg,
      vertical: PaperSpacing.md,
    ),
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleMedium,
      semanticsLabel: title,
    ),
  );
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
              Icon(
                Symbols.cloud_off_rounded,
                size: 16,
                color: colors.textMuted,
              ),
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
