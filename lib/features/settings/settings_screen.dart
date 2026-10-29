import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_settings.dart';
import '../../app/app_shell.dart';
import '../../auth/auth_providers.dart';
import '../../core/build_flags.dart';
import '../../core/core_providers.dart';
import '../../core/env.dart';
import '../../data/data_providers.dart';
import '../../domain/domain.dart';
import '../../l10n/app_localizations.dart';
import '../../sync/sync_providers.dart';
import '../../theme/paper_tokens.dart';
import '../../theme/theme_x.dart';
import '../auth/sign_in_prompt.dart';
import '../auth/sign_in_screen.dart' show kAppVersion;
import '../sync/sync_badge.dart';
import '../sync/sync_sheet.dart';
import 'sign_out_dialog.dart';

enum SettingsSection { account, appearance, reader, storage, sync, about }

/// Sections shown, in order. Offline-only builds have no account or sync.
List<SettingsSection> settingsSectionsFor({required bool offlineOnly}) =>
    offlineOnly
    ? const <SettingsSection>[
        SettingsSection.appearance,
        SettingsSection.reader,
        SettingsSection.storage,
        SettingsSection.about,
      ]
    : SettingsSection.values;

/// Downloaded papers (Settings › Storage).
final downloadedPapersProvider = StreamProvider.autoDispose<List<Paper>>(
  (ref) => ref
      .watch(paperRepositoryProvider)
      .watchPapers(sort: PaperSort.title)
      .map(
        (papers) => papers
            .where((p) => p.downloadState == DownloadState.downloaded)
            .toList(),
      ),
);

/// Settings (screens/settings.md): single grouped list on compact / medium,
/// master–detail on expanded+. Every setting applies instantly and is
/// device-local.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  SettingsSection? _picked;

  String _label(AppLocalizations l10n, SettingsSection s) => switch (s) {
    SettingsSection.account => l10n.settingsSectionAccount,
    SettingsSection.appearance => l10n.settingsSectionAppearance,
    SettingsSection.reader => l10n.settingsSectionReader,
    SettingsSection.storage => l10n.settingsSectionStorage,
    SettingsSection.sync => l10n.settingsSectionSync,
    SettingsSection.about => l10n.settingsSectionAbout,
  };

  IconData _icon(SettingsSection s) => switch (s) {
    SettingsSection.account => Symbols.person_rounded,
    SettingsSection.appearance => Symbols.contrast_rounded,
    SettingsSection.reader => Symbols.menu_book_rounded,
    SettingsSection.storage => Symbols.download_rounded,
    SettingsSection.sync => Symbols.sync_rounded,
    SettingsSection.about => Symbols.info_rounded,
  };

  Widget _section(SettingsSection s) => switch (s) {
    SettingsSection.account => const _AccountSection(),
    SettingsSection.appearance => const _AppearanceSection(),
    SettingsSection.reader => const _ReaderSection(),
    SettingsSection.storage => const _StorageSection(),
    SettingsSection.sync => const _SyncSection(),
    SettingsSection.about => const _AboutSection(),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.paper;
    final sections = settingsSectionsFor(
      offlineOnly: ref.watch(offlineOnlyProvider),
    );
    final picked = _picked;
    final selected = picked != null && sections.contains(picked)
        ? picked
        : sections.first;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wc = PaperWindowClass.of(constraints.maxWidth);
        final margin = PaperSpacing.margin(wc);
        final title = Padding(
          padding: EdgeInsets.fromLTRB(margin, PaperSpacing.xl, margin, 0),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.settingsTitle,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                ),
              ),
              const ShellSyncBadge(),
            ],
          ),
        );

        if (!wc.hasSplitView) {
          return ListView(
            padding: const EdgeInsets.only(bottom: PaperSpacing.xxl),
            children: <Widget>[
              title,
              for (final s in sections)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: margin),
                  child: _SectionGroup(
                    title: _label(l10n, s),
                    child: _section(s),
                  ),
                ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            title,
            const SizedBox(height: PaperSpacing.lg),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 280,
                    child: ListView(
                      padding: EdgeInsets.symmetric(horizontal: margin / 2),
                      children: <Widget>[
                        for (final s in sections)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: ListTile(
                              key: ValueKey<String>('settings-nav-${s.name}'),
                              dense: true,
                              selected: s == selected,
                              selectedTileColor: c.primarySoft,
                              selectedColor: c.onPrimarySoft,
                              shape: RoundedRectangleBorder(
                                borderRadius: PaperRadii.borderMd,
                              ),
                              leading: Icon(_icon(s), size: 20),
                              title: Text(_label(l10n, s)),
                              trailing: s == SettingsSection.sync
                                  ? const SyncBadge()
                                  : null,
                              onTap: () => setState(() => _picked = s),
                            ),
                          ),
                      ],
                    ),
                  ),
                  VerticalDivider(width: 1, color: c.border),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: ListView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: PaperSpacing.sm,
                          ),
                          children: <Widget>[
                            _SectionGroup(
                              title: _label(l10n, selected),
                              child: _section(selected),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// `SettingsSection`: overline + grouped card.
class _SectionGroup extends StatelessWidget {
  const _SectionGroup({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.paper;
    return Padding(
      padding: const EdgeInsets.only(top: PaperSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.44,
                color: c.textMuted,
              ),
            ),
          ),
          const SizedBox(height: PaperSpacing.sm),
          Material(
            color: c.surface,
            shape: RoundedRectangleBorder(
              borderRadius: PaperRadii.borderLg,
              side: BorderSide(color: c.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: child,
          ),
        ],
      ),
    );
  }
}

Future<void> _openWeb(String path) => launchUrl(
  Uri.parse('${Env.defaultPaperApiBaseUrl}$path'),
  mode: LaunchMode.externalApplication,
);

void _snack(BuildContext context, String text) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

class _AccountSection extends ConsumerWidget {
  const _AccountSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = context.paper;
    final user = currentUser(ref);
    final name = user?.displayName ?? user?.email ?? '';
    final initials = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    // Guests: sign-in / create account lives here (sign-in is optional).
    if (ref.watch(isGuestProvider)) {
      return Column(
        children: <Widget>[
          ListTile(
            key: const ValueKey<String>('settings-guest'),
            leading: CircleAvatar(
              backgroundColor: c.surfaceVariant,
              foregroundColor: c.textSecondary,
              child: const Icon(Symbols.person_rounded, size: 20),
            ),
            title: Text(l10n.guestAccountTitle),
            subtitle: Text(l10n.guestAccountBody),
            isThreeLine: true,
          ),
          ListTile(
            key: const ValueKey<String>('settings-sign-in'),
            leading: Icon(Symbols.login_rounded, size: 20, color: c.primary),
            title: Text(l10n.commonSignIn, style: TextStyle(color: c.primary)),
            onTap: () => unawaited(openSignIn(context)),
          ),
          const _ExportNotesTile(),
        ],
      );
    }
    return Column(
      children: <Widget>[
        if (user != null)
          ListTile(
            leading: CircleAvatar(
              backgroundColor: c.primarySoft,
              foregroundColor: c.onPrimarySoft,
              child: Text(initials),
            ),
            title: Text(user.displayName ?? l10n.settingsDisplayName),
            subtitle: Text(user.email ?? ''),
          ),
        ListTile(
          title: Text(l10n.settingsManageAccount),
          trailing: const Icon(Symbols.open_in_new_rounded, size: 18),
          onTap: () => unawaited(_openWeb('/settings')),
        ),
        const _ExportNotesTile(),
        if (user != null)
          ListTile(
            key: const ValueKey<String>('settings-sign-out'),
            leading: Icon(Symbols.logout_rounded, size: 20, color: c.error),
            title: Text(l10n.settingsSignOut, style: TextStyle(color: c.error)),
            onTap: () => signOutTapped(context, ref),
          ),
      ],
    );
  }
}

/// Copies every note to the clipboard as text.
class _ExportNotesTile extends ConsumerWidget {
  const _ExportNotesTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      key: const ValueKey<String>('settings-export-notes'),
      title: Text(l10n.settingsExportNotes),
      leading: const Icon(Symbols.content_copy_rounded, size: 20),
      onTap: () async {
        final text = await ref.read(noteRepositoryProvider).exportAllAsText();
        await Clipboard.setData(ClipboardData(text: text));
        if (context.mounted) _snack(context, l10n.settingsNotesCopied);
      },
    );
  }
}

class _AppearanceSection extends ConsumerWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final mode = ref.watch(themeModeProvider);
    final reduce = ref.watch(reduceMotionProvider);
    return Padding(
      padding: const EdgeInsets.all(PaperSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.settingsTheme,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: PaperSpacing.sm),
          ThemeSelector(
            mode: mode,
            onChanged: ref.read(themeModeProvider.notifier).set,
          ),
          const SizedBox(height: PaperSpacing.xl),
          Text(
            l10n.settingsReduceMotion,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          Text(
            l10n.settingsReduceMotionBody,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: PaperSpacing.sm),
          SegmentedButton<bool>(
            key: const ValueKey<String>('settings-reduce-motion'),
            segments: <ButtonSegment<bool>>[
              ButtonSegment(
                value: false,
                label: Text(l10n.settingsReduceMotionSystem),
              ),
              ButtonSegment(
                value: true,
                label: Text(l10n.settingsReduceMotionOn),
              ),
            ],
            selected: <bool>{reduce},
            onSelectionChanged: (s) =>
                ref.read(reduceMotionProvider.notifier).set(s.first),
          ),
        ],
      ),
    );
  }
}

/// `ThemeSelector`: System / Light / Dark tiles (radio group, labelled by
/// name, never by swatch). Switching is instant (motion #53).
class ThemeSelector extends StatelessWidget {
  const ThemeSelector({super.key, required this.mode, required this.onChanged});

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.paper;
    Widget tile(ThemeMode m, String label, Color bg) {
      final selected = m == mode;
      return Semantics(
        inMutuallyExclusiveGroup: true,
        checked: selected,
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          key: ValueKey<String>('theme-${m.name}'),
          borderRadius: PaperRadii.borderLg,
          onTap: () => onChanged(m),
          child: Column(
            children: <Widget>[
              Container(
                width: 120,
                height: 88,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: PaperRadii.borderLg,
                  border: Border.all(
                    color: selected ? c.primary : c.border,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Stack(
                  children: <Widget>[
                    Positioned(
                      left: 24,
                      top: 16,
                      right: 24,
                      bottom: 0,
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(8),
                        alignment: Alignment.topLeft,
                        child: Container(
                          height: 4,
                          width: 40,
                          color: PaperHighlightColor.blue.wash,
                        ),
                      ),
                    ),
                    if (selected)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: CircleAvatar(
                          radius: 10,
                          backgroundColor: c.primary,
                          child: Icon(
                            Symbols.check_rounded,
                            size: 14,
                            color: c.onPrimary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: PaperSpacing.xs),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Wrap(
      spacing: PaperSpacing.md,
      runSpacing: PaperSpacing.md,
      children: <Widget>[
        tile(ThemeMode.system, l10n.themeSystem, const Color(0xFF737373)),
        tile(ThemeMode.light, l10n.themeLight, const Color(0xFFFAFAFA)),
        tile(ThemeMode.dark, l10n.themeDark, const Color(0xFF0A0A0A)),
      ],
    );
  }
}

class _ReaderSection extends ConsumerWidget {
  const _ReaderSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final prefs = ref.watch(readerPrefsProvider);
    final ctrl = ref.read(readerPrefsProvider.notifier);
    return Column(
      children: <Widget>[
        ListTile(
          title: Text(l10n.settingsPanelStyle),
          trailing: SegmentedButton<PanelStyle>(
            key: const ValueKey<String>('settings-panel-style'),
            showSelectedIcon: false,
            segments: <ButtonSegment<PanelStyle>>[
              ButtonSegment(
                value: PanelStyle.split,
                label: Text(l10n.panelStyleSplit),
              ),
              ButtonSegment(
                value: PanelStyle.overlay,
                label: Text(l10n.panelStyleOverlay),
              ),
            ],
            selected: <PanelStyle>{prefs.panelStyle},
            onSelectionChanged: (s) => ctrl.setPanelStyle(s.first),
          ),
        ),
        SwitchListTile(
          key: const ValueKey<String>('settings-auto-pen'),
          title: Text(l10n.settingsAutoPen),
          value: prefs.autoSwitchToPen,
          onChanged: ctrl.setAutoSwitchToPen,
        ),
        SwitchListTile(
          key: const ValueKey<String>('settings-single-key'),
          title: Text(l10n.settingsSingleKeyShortcuts),
          value: prefs.singleKeyShortcuts,
          onChanged: ctrl.setSingleKeyShortcuts,
        ),
      ],
    );
  }
}

String _formatBytes(int bytes) {
  const units = <String>['B', 'KB', 'MB', 'GB'];
  var v = bytes.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(i == 0 ? 0 : 1)} ${units[i]}';
}

class _StorageSection extends ConsumerWidget {
  const _StorageSection();

  Widget _clearCacheButton(BuildContext context) => OutlinedButton(
    key: const ValueKey<String>('settings-clear-cache'),
    onPressed: () {
      // Thumbnails and decoded images; never user data.
      PaintingBinding.instance.imageCache
        ..clear()
        ..clearLiveImages();
      _snack(context, AppLocalizations.of(context).storageCacheCleared);
    },
    child: Text(AppLocalizations.of(context).storageClearCache),
  );

  Future<void> _removeAll(
    BuildContext context,
    WidgetRef ref,
    List<Paper> papers,
  ) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.storageRemoveAllTitle),
        content: Text(l10n.storageRemoveAllBody),
        actions: <Widget>[
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.storageRemoveAll),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final repo = ref.read(paperRepositoryProvider);
    for (final p in papers) {
      await repo.removeDownload(p.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = context.paper;
    final t = Theme.of(context).textTheme;
    // Offline-only builds: every paper is the only copy on this device, so
    // there are no downloads to manage. Export notes moves here from the
    // (hidden) Account section.
    if (ref.watch(offlineOnlyProvider)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _ExportNotesTile(),
          Padding(
            padding: const EdgeInsets.all(PaperSpacing.lg),
            child: Wrap(children: <Widget>[_clearCacheButton(context)]),
          ),
        ],
      );
    }
    final papers = ref.watch(downloadedPapersProvider).value ?? const <Paper>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            PaperSpacing.lg,
            PaperSpacing.lg,
            PaperSpacing.lg,
            PaperSpacing.xs,
          ),
          child: Text(
            l10n.storageDownloadedPapers(papers.length),
            style: t.labelLarge,
          ),
        ),
        if (papers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: PaperSpacing.lg,
              vertical: PaperSpacing.sm,
            ),
            child: Text(
              l10n.storageNoDownloads,
              style: t.bodySmall?.copyWith(color: c.textMuted),
            ),
          )
        else
          for (final p in papers)
            ListTile(
              key: ValueKey<String>('download-${p.id}'),
              title: Text(
                p.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: _FileSize(path: p.localFilePath),
              trailing: OutlinedButton(
                onPressed: () => unawaited(
                  ref.read(paperRepositoryProvider).removeDownload(p.id),
                ),
                child: Text(l10n.storageRemove),
              ),
            ),
        Padding(
          padding: const EdgeInsets.all(PaperSpacing.lg),
          child: Wrap(
            spacing: PaperSpacing.sm,
            runSpacing: PaperSpacing.sm,
            children: <Widget>[
              OutlinedButton(
                onPressed: papers.isEmpty
                    ? null
                    : () => unawaited(_removeAll(context, ref, papers)),
                style: OutlinedButton.styleFrom(foregroundColor: c.error),
                child: Text(l10n.storageRemoveAll),
              ),
              _clearCacheButton(context),
            ],
          ),
        ),
      ],
    );
  }
}

class _FileSize extends StatefulWidget {
  const _FileSize({required this.path});

  final String? path;

  @override
  State<_FileSize> createState() => _FileSizeState();
}

class _FileSizeState extends State<_FileSize> {
  late final Future<int?> _size = _read();

  Future<int?> _read() async {
    final path = widget.path;
    if (path == null) return null;
    try {
      return await File(path).length();
    } on FileSystemException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<int?>(
    future: _size,
    builder: (context, snap) => Text(
      snap.data == null ? '' : _formatBytes(snap.data!),
      style: PaperTypography.pageIndicator(context.paper),
    ),
  );
}

class _SyncSection extends ConsumerWidget {
  const _SyncSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (ref.watch(isGuestProvider)) {
      return const SignInPrompt(feature: GuestFeature.sync, dense: true);
    }
    final status = ref.watch(syncStatusProvider).value ?? SyncStatus.idle;
    final replaced =
        ref.watch(replacedVersionsProvider).value ?? const <ReplacedVersion>[];
    final canSync =
        status.phase != SyncPhase.offline && status.phase != SyncPhase.syncing;
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            const Expanded(child: SyncBadge(form: SyncBadgeForm.long)),
            Padding(
              padding: const EdgeInsets.only(right: PaperSpacing.md),
              child: Tooltip(
                message: status.phase == SyncPhase.offline
                    ? l10n.settingsNeedsConnection
                    : '',
                child: OutlinedButton(
                  onPressed: canSync
                      ? () => unawaited(ref.read(syncServiceProvider).syncNow())
                      : null,
                  child: Text(l10n.settingsSyncNow),
                ),
              ),
            ),
          ],
        ),
        ListTile(
          title: Text(l10n.syncReplacedVersions(replaced.length)),
          trailing: const Icon(Symbols.chevron_right_rounded),
          onTap: () => unawaited(showSyncSheet(context)),
        ),
        ListTile(
          title: Text(l10n.syncHowItWorksTitle),
          trailing: const Icon(Symbols.chevron_right_rounded),
          onTap: () => unawaited(showSyncHowItWorks(context)),
        ),
      ],
    );
  }
}

class _AboutSection extends ConsumerWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final online = ref.watch(isOnlineProvider).value ?? true;
    return Column(
      children: <Widget>[
        ListTile(title: Text(l10n.aboutVersion(kAppVersion))),
        ListTile(
          title: Text(l10n.aboutTerms),
          trailing: const Icon(Symbols.open_in_new_rounded, size: 18),
          enabled: online,
          onTap: () => unawaited(_openWeb('/terms')),
        ),
        ListTile(
          title: Text(l10n.aboutPrivacy),
          trailing: const Icon(Symbols.open_in_new_rounded, size: 18),
          enabled: online,
          onTap: () => unawaited(_openWeb('/privacy')),
        ),
        ListTile(
          key: const ValueKey<String>('settings-licenses'),
          title: Text(l10n.aboutLicenses),
          trailing: const Icon(Symbols.chevron_right_rounded),
          onTap: () => showLicensePage(
            context: context,
            applicationName: l10n.appName,
            applicationVersion: kAppVersion,
          ),
        ),
      ],
    );
  }
}
