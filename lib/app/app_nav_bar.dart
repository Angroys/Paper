import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../core/build_flags.dart';
import '../features/auth/sign_in_prompt.dart';
import '../features/sync/sync_badge.dart';
import '../l10n/app_localizations.dart';
import '../theme/paper_tokens.dart';
import '../ui/ui.dart';

/// One top-level destination of the [AppNavBar].
@immutable
class AppNavDestination {
  const AppNavDestination({
    required this.icon,
    required this.label,
    required this.key,
  });

  final PaperIcons icon;
  final String label;
  final Key key;
}

/// The app's only navigation chrome (design/web-parity/screens/README.md
/// §2): a 48px top bar in both orientations, in the web's sidebar-item
/// language. Shown on Library and Settings; the reader and sign-in routes
/// sit outside the shell, so they have no bar.
///
/// `[24] Paper [16] [Library] [4] [Settings] … (sync) [8] Sign in [24]`
///
/// Backgrounds bleed under cutouts; content is inset by `viewPadding`.
class AppNavBar extends ConsumerWidget {
  const AppNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  static const Key barKey = ValueKey<String>('app-nav-bar');
  static const Key wordmarkKey = ValueKey<String>('app-nav-wordmark');
  static const Key libraryKey = ValueKey<String>('app-nav-library');
  static const Key settingsKey = ValueKey<String>('app-nav-settings');
  static const Key signInKey = ValueKey<String>('app-nav-sign-in');

  /// Bar height without the top inset and the 1px hairline.
  static const double height = 48;

  /// 0 = Library, 1 = Settings.
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final offline = ref.watch(offlineOnlyProvider);
    final guest = ref.watch(isGuestProvider);
    final pad = MediaQuery.viewPaddingOf(context);
    final showLabels = WebBreakpoint.of(context).isSmUp;
    final destinations = <AppNavDestination>[
      AppNavDestination(
        icon: PaperIcons.navPapers,
        label: l10n.navLibrary,
        key: libraryKey,
      ),
      AppNavDestination(
        icon: PaperIcons.navProfile,
        label: l10n.navSettings,
        key: settingsKey,
      ),
    ];

    return Semantics(
      key: barKey,
      container: true,
      explicitChildNodes: true,
      label: l10n.a11yAppNavigation,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: PaperWeb.gray950,
          border: Border(bottom: BorderSide(color: PaperWeb.gray800)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            PaperSpacing.tw6 + pad.left,
            pad.top,
            PaperSpacing.tw6 + pad.right,
            1, // the hairline
          ),
          child: SizedBox(
            height: height,
            child: Row(
              children: <Widget>[
                _Wordmark(
                  label: l10n.appName,
                  onPressed: () => onDestinationSelected(0),
                ),
                const SizedBox(width: PaperSpacing.tw4),
                for (var i = 0; i < destinations.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: PaperSpacing.tw1),
                  _NavItem(
                    destination: destinations[i],
                    selected: i == selectedIndex,
                    showLabel: showLabels,
                    onPressed: () => onDestinationSelected(i),
                  ),
                ],
                const Spacer(),
                if (!offline && !guest) const SyncBadge(),
                if (!offline && guest)
                  _NavLink(
                    key: signInKey,
                    label: l10n.commonSignIn,
                    onPressed: () => unawaited(openSignIn(context)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

TextStyle _navText(double size, FontWeight weight, Color color) => TextStyle(
  fontFamily: PaperTypography.sans,
  fontFamilyFallback: PaperTypography.sansFallback,
  fontSize: size,
  height: 20 / size,
  leadingDistribution: TextLeadingDistribution.even,
  fontWeight: weight,
  color: color,
);

/// "Paper": 14/20 600, tracking-tight, gray-100. Goes to the library.
class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => PaperPressable(
    key: AppNavBar.wordmarkKey,
    onPressed: onPressed,
    semanticLabel: label,
    excludeSemantics: true,
    builder: (context, states) => PaperFocusRing(
      show: states.contains(WidgetState.focused),
      radius: PaperRadii.borderMd,
      gap: PaperWeb.gray950,
      child: Text(
        label,
        style: _navText(
          14,
          FontWeight.w600,
          PaperWeb.gray100,
        ).copyWith(letterSpacing: -0.35),
      ),
    ),
  );
}

/// Destination item: `btn-ghost justify-start gap-3 px-3 py-2` + 16px
/// glyph; active = accent-soft / accent-ink. Icon-only 36×36 below 640.
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.showLabel,
    required this.onPressed,
  });

  final AppNavDestination destination;
  final bool selected;
  final bool showLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => PaperPressable(
    key: destination.key,
    onPressed: onPressed,
    selected: selected,
    semanticLabel: destination.label,
    excludeSemantics: true,
    tooltip: showLabel ? null : destination.label,
    builder: (context, states) {
      final Color fill;
      final Color ink;
      if (selected) {
        fill = PaperWeb.accentSoft;
        ink = PaperWeb.accentInk;
      } else if (states.contains(WidgetState.pressed)) {
        fill = PaperWeb.gray700;
        ink = PaperWeb.gray100;
      } else if (states.contains(WidgetState.hovered)) {
        fill = PaperWeb.gray800;
        ink = PaperWeb.gray100;
      } else {
        fill = const Color(0x00000000);
        ink = PaperWeb.gray400;
      }
      return PaperFocusRing(
        show: states.contains(WidgetState.focused),
        radius: PaperRadii.borderMd,
        gap: PaperWeb.gray950,
        child: PaperColorBox(
          color: fill,
          radius: PaperRadii.borderMd,
          constraints: showLabel
              ? const BoxConstraints.tightFor(height: 36)
              : const BoxConstraints.tightFor(width: 36, height: 36),
          padding: showLabel
              ? const EdgeInsets.symmetric(horizontal: PaperSpacing.tw3)
              : null,
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              PaperIcon(destination.icon, color: ink),
              if (showLabel) ...<Widget>[
                const SizedBox(width: PaperSpacing.tw3),
                Text(
                  destination.label,
                  style: _navText(14, FontWeight.w500, ink),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

/// `navLinkClass`: `px-2 py-1 text-sm` gray-400 → gray-100, radius 6, no
/// fill.
class _NavLink extends StatelessWidget {
  const _NavLink({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => PaperPressable(
    onPressed: onPressed,
    semanticLabel: label,
    excludeSemantics: true,
    builder: (context, states) {
      final hot =
          states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.pressed);
      return PaperFocusRing(
        show: states.contains(WidgetState.focused),
        radius: PaperRadii.borderMd,
        gap: PaperWeb.gray950,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PaperSpacing.tw2,
            vertical: PaperSpacing.tw1,
          ),
          child: AnimatedDefaultTextStyle(
            duration: PaperMotion.of(context, PaperMotion.colors),
            style: _navText(
              14,
              FontWeight.w400,
              hot ? PaperWeb.gray100 : PaperWeb.gray400,
            ),
            child: Text(label),
          ),
        ),
      );
    },
  );
}
