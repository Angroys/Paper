import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_settings.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/paper_tokens.dart';

/// PLACEHOLDER (feature-screens agent): settings per
/// design/specs/screens/settings.md. Theme + licenses only for now.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final mode = ref.watch(themeModeProvider);
    final margin = PaperSpacing.margin(PaperWindowClass.ofContext(context));
    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: margin,
        vertical: PaperSpacing.xl,
      ),
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            l10n.settingsTitle,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: PaperSpacing.lg),
        ListTile(
          title: Text(l10n.settingsTheme),
          trailing: DropdownButton<ThemeMode>(
            value: mode,
            onChanged: (m) {
              if (m != null) ref.read(themeModeProvider.notifier).set(m);
            },
            items: <DropdownMenuItem<ThemeMode>>[
              DropdownMenuItem(
                value: ThemeMode.system,
                child: Text(l10n.themeSystem),
              ),
              DropdownMenuItem(
                value: ThemeMode.light,
                child: Text(l10n.themeLight),
              ),
              DropdownMenuItem(
                value: ThemeMode.dark,
                child: Text(l10n.themeDark),
              ),
            ],
          ),
        ),
        ListTile(
          title: Text(l10n.aboutLicenses),
          onTap: () =>
              showLicensePage(context: context, applicationName: l10n.appName),
        ),
      ],
    );
  }
}
