import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_settings.dart';
import '../../auth/auth_providers.dart';
import '../../core/build_flags.dart';
import '../../core/env.dart';
import '../../data/data_providers.dart';
import '../../domain/domain.dart';
import '../../l10n/app_localizations.dart';
import '../../sync/sync_providers.dart';
import '../../theme/paper_tokens.dart';
import '../../ui/ui.dart';
import '../auth/sign_in_prompt.dart';
import '../auth/sign_in_screen.dart' show kAppVersion;
import '../sync/sync_badge.dart' show syncLongText;
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

/// Settings (design/web-parity/screens/settings.md): one centred 720
/// column at every width, "Settings" title, then each section as a web
/// `.card p-5` with `PaperListRow` rows. Every setting applies instantly
/// and is device-local.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static Key sectionKey(SettingsSection s) =>
      ValueKey<String>('settings-section-${s.name}');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sections = settingsSectionsFor(
      offlineOnly: ref.watch(offlineOnlyProvider),
    );
    final pad = MediaQuery.viewPaddingOf(context);
    final top = WebBreakpoint.of(context).isSmUp
        ? PaperSpacing.tw16
        : PaperSpacing.tw12;
    return ColoredBox(
      color: PaperWeb.gray950,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          // `mx-auto max-w-3xl px-6`: a 768 box (padding included).
          final side = (width - math.min(width, 768)) / 2 + PaperSpacing.tw6;
          // A handful of cards: built eagerly in one scroll region.
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              side + pad.left,
              top,
              side + pad.right,
              top + pad.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Semantics(
                  header: true,
                  child: Text(
                    l10n.settingsTitle,
                    style: PaperTypography.pageTitle(PaperColors.dark),
                  ),
                ),
                for (var i = 0; i < sections.length; i++) ...<Widget>[
                  SizedBox(
                    height: i == 0 ? PaperSpacing.tw8 : PaperSpacing.tw6,
                  ),
                  _SectionCard(
                    key: sectionKey(sections[i]),
                    title: _label(l10n, sections[i]),
                    child: _section(sections[i]),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  static String _label(AppLocalizations l10n, SettingsSection s) => switch (s) {
    SettingsSection.account => l10n.settingsSectionAccount,
    SettingsSection.appearance => l10n.settingsSectionAppearance,
    SettingsSection.reader => l10n.settingsSectionReader,
    SettingsSection.storage => l10n.settingsSectionStorage,
    SettingsSection.sync => l10n.settingsSectionSync,
    SettingsSection.about => l10n.settingsSectionAbout,
  };

  static Widget _section(SettingsSection s) => switch (s) {
    SettingsSection.account => const _AccountSection(),
    SettingsSection.appearance => const _AppearanceSection(),
    SettingsSection.reader => const _ReaderSection(),
    SettingsSection.storage => const _StorageSection(),
    SettingsSection.sync => const _SyncSection(),
    SettingsSection.about => const _AboutSection(),
  };
}

/// A section: `PaperCard p-5`, `cardTitle` heading, content below.
class _SectionCard extends StatelessWidget {
  const _SectionCard({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => PaperCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            title,
            style: PaperTypography.cardTitle(PaperColors.dark),
          ),
        ),
        child,
      ],
    ),
  );
}

/// `PaperListRow` list at `mt-3`.
class _Rows extends StatelessWidget {
  const _Rows({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: PaperSpacing.tw3),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

/// Footer actions: `mt-4 flex flex-wrap items-center gap-3`.
class _Footer extends StatelessWidget {
  const _Footer({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: PaperSpacing.tw4),
    child: Wrap(
      spacing: PaperSpacing.tw3,
      runSpacing: PaperSpacing.tw3,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    ),
  );
}

TextStyle? _sm(BuildContext context, Color color) =>
    Theme.of(context).textTheme.bodyMedium?.copyWith(color: color);

TextStyle? _xs(BuildContext context, Color color) =>
    Theme.of(context).textTheme.bodySmall?.copyWith(color: color);

Future<void> _openWeb(String path) => launchUrl(
  Uri.parse('${Env.defaultPaperApiBaseUrl}$path'),
  mode: LaunchMode.externalApplication,
);

/// A row whose only content is a `PaperLink.accent` (Manage account,
/// Terms, Privacy, Licenses, How syncing works).
class _LinkRow extends StatelessWidget {
  const _LinkRow({
    super.key,
    required this.label,
    required this.onPressed,
    this.external = false,
    this.last = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool external;
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: PaperSpacing.tw3),
    decoration: BoxDecoration(
      border: last
          ? null
          : const Border(bottom: BorderSide(color: PaperWeb.gray800)),
    ),
    alignment: AlignmentDirectional.centerStart,
    child: PaperLink(
      label: label,
      trailing: external ? '↗' : null,
      onPressed: onPressed,
    ),
  );
}

class _AccountSection extends ConsumerWidget {
  const _AccountSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // Guests: sign-in / create account lives here (sign-in is optional).
    if (ref.watch(isGuestProvider)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            key: const ValueKey<String>('settings-guest'),
            padding: const EdgeInsets.only(top: PaperSpacing.tw4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.guestAccountTitle,
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: PaperWeb.gray100),
                ),
                const SizedBox(height: PaperSpacing.tw1),
                Text(
                  l10n.guestAccountBody,
                  style: _sm(context, PaperWeb.gray400),
                ),
              ],
            ),
          ),
          const _Rows(children: <Widget>[_ExportNotesRow(last: true)]),
          _Footer(
            children: <Widget>[
              PaperButton.primary(
                key: const ValueKey<String>('settings-sign-in'),
                label: l10n.commonSignIn,
                focusGap: PaperWeb.gray900,
                onPressed: () => unawaited(openSignIn(context)),
              ),
            ],
          ),
        ],
      );
    }
    final user = currentUser(ref);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (user != null)
          Padding(
            padding: const EdgeInsets.only(top: PaperSpacing.tw4),
            child: _Identity(user: user),
          ),
        _Rows(
          children: <Widget>[
            _LinkRow(
              label: l10n.settingsManageAccount,
              external: true,
              onPressed: () => unawaited(_openWeb('/settings')),
            ),
            const _ExportNotesRow(last: true),
          ],
        ),
        if (user != null)
          _Footer(
            children: <Widget>[
              PaperButton.destructive(
                key: const ValueKey<String>('settings-sign-out'),
                label: l10n.settingsSignOut,
                size: PaperButtonSize.md,
                focusGap: PaperWeb.gray900,
                onPressed: () => signOutTapped(context, ref),
              ),
            ],
          ),
      ],
    );
  }
}

/// Avatar 64 (`accentSoft` + initials) · name · email.
class _Identity extends StatelessWidget {
  const _Identity({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = user.displayName ?? user.email ?? '';
    final initials = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    return Row(
      children: <Widget>[
        ExcludeSemantics(
          child: Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: PaperWeb.accentSoft,
              shape: BoxShape.circle,
            ),
            child: Text(
              initials,
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(color: PaperWeb.accentInk, letterSpacing: 0),
            ),
          ),
        ),
        const SizedBox(width: PaperSpacing.tw4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                user.displayName ?? l10n.settingsDisplayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: PaperWeb.gray100),
              ),
              if (user.email != null)
                Text(
                  user.email!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _xs(context, PaperWeb.gray400),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Copies every note to the clipboard as text; "Notes copied." shows
/// inline in green for 2 s.
class _ExportNotesRow extends ConsumerStatefulWidget {
  const _ExportNotesRow({this.last = false});

  final bool last;

  @override
  ConsumerState<_ExportNotesRow> createState() => _ExportNotesRowState();
}

class _ExportNotesRowState extends ConsumerState<_ExportNotesRow> {
  Timer? _timer;
  bool _copied = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    final text = await ref.read(noteRepositoryProvider).exportAllAsText();
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    setState(() => _copied = true);
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PaperListRow(
      key: const ValueKey<String>('settings-export-notes'),
      title: l10n.settingsExportNotes,
      last: widget.last,
      onTap: () => unawaited(_copy()),
      trailing: _copied
          ? Semantics(
              liveRegion: true,
              child: Text(
                l10n.settingsNotesCopied,
                style: _xs(context, PaperWeb.green400),
              ),
            )
          : null,
    );
  }
}

class _AppearanceSection extends ConsumerWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final reduce = ref.watch(reduceMotionProvider);
    return _Rows(
      children: <Widget>[
        PaperListRow(
          title: l10n.settingsReduceMotion,
          description: l10n.settingsReduceMotionBody,
          last: true,
          stackBelowSm: true,
          trailing: PaperSegmented<bool>(
            key: const ValueKey<String>('settings-reduce-motion'),
            segments: <PaperSegment<bool>>[
              PaperSegment<bool>(
                value: false,
                label: l10n.settingsReduceMotionSystem,
              ),
              PaperSegment<bool>(
                value: true,
                label: l10n.settingsReduceMotionOn,
              ),
            ],
            selected: reduce,
            onChanged: (v) => ref.read(reduceMotionProvider.notifier).set(v),
          ),
        ),
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
    Widget toggle(
      String key,
      String label,
      bool value,
      ValueChanged<bool> on,
    ) => PaperListRow(
      title: label,
      alignTop: true,
      last: key == 'settings-single-key',
      trailing: PaperCheckbox(
        key: ValueKey<String>(key),
        size: 20,
        value: value,
        semanticLabel: label,
        focusGap: PaperWeb.gray900,
        onChanged: (v) => on(v ?? false),
      ),
    );
    return _Rows(
      children: <Widget>[
        PaperListRow(
          title: l10n.settingsPanelStyle,
          stackBelowSm: true,
          trailing: PaperSegmented<PanelStyle>(
            key: const ValueKey<String>('settings-panel-style'),
            segments: <PaperSegment<PanelStyle>>[
              PaperSegment<PanelStyle>(
                value: PanelStyle.split,
                label: l10n.panelStyleSplit,
              ),
              PaperSegment<PanelStyle>(
                value: PanelStyle.overlay,
                label: l10n.panelStyleOverlay,
              ),
            ],
            selected: prefs.panelStyle,
            onChanged: ctrl.setPanelStyle,
          ),
        ),
        toggle(
          'settings-auto-pen',
          l10n.settingsAutoPen,
          prefs.autoSwitchToPen,
          ctrl.setAutoSwitchToPen,
        ),
        toggle(
          'settings-single-key',
          l10n.settingsSingleKeyShortcuts,
          prefs.singleKeyShortcuts,
          ctrl.setSingleKeyShortcuts,
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

class _StorageSection extends ConsumerStatefulWidget {
  const _StorageSection();

  @override
  ConsumerState<_StorageSection> createState() => _StorageSectionState();
}

class _StorageSectionState extends ConsumerState<_StorageSection> {
  bool _cleared = false;

  Widget _clearCacheButton(AppLocalizations l10n) => PaperButton.secondary(
    key: const ValueKey<String>('settings-clear-cache'),
    label: l10n.storageClearCache,
    focusGap: PaperWeb.gray900,
    onPressed: () {
      // Thumbnails and decoded images; never user data.
      PaintingBinding.instance.imageCache
        ..clear()
        ..clearLiveImages();
      setState(() => _cleared = true);
    },
  );

  Widget get _clearedLine => Semantics(
    liveRegion: true,
    child: Text(
      AppLocalizations.of(context).storageCacheCleared,
      style: _sm(context, PaperWeb.green400),
    ),
  );

  Future<void> _removeAll(List<Paper> papers) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showPaperDialog<bool>(
      context: context,
      builder: (context) => PaperDialog(
        title: l10n.storageRemoveAllTitle,
        body: l10n.storageRemoveAllBody,
        actions: <Widget>[
          PaperButton.secondary(
            label: l10n.commonCancel,
            autofocus: true,
            focusGap: PaperWeb.gray900,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          PaperButton.destructive(
            key: const ValueKey<String>('settings-remove-all-confirm'),
            label: l10n.storageRemoveAll,
            size: PaperButtonSize.md,
            focusGap: PaperWeb.gray900,
            onPressed: () => Navigator.of(context).pop(true),
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Offline-only builds: every paper is the only copy on this device, so
    // there are no downloads to manage. Export notes moves here from the
    // (hidden) Account section.
    if (ref.watch(offlineOnlyProvider)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _Rows(children: <Widget>[_ExportNotesRow(last: true)]),
          _Footer(
            children: <Widget>[
              _clearCacheButton(l10n),
              if (_cleared) _clearedLine,
            ],
          ),
        ],
      );
    }
    final async = ref.watch(downloadedPapersProvider);
    final papers = async.value ?? const <Paper>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: PaperSpacing.tw2),
        if (!async.hasValue && !async.hasError)
          const Align(
            alignment: AlignmentDirectional.centerStart,
            child: PaperSkeleton(width: 64, height: 12),
          )
        else
          Text(
            l10n.storageDownloadedPapers(papers.length),
            style: _sm(context, PaperWeb.gray400),
          ),
        if (papers.isEmpty && async.hasValue)
          Padding(
            padding: const EdgeInsets.only(top: PaperSpacing.tw3),
            child: Text(
              l10n.storageNoDownloads,
              style: _sm(context, PaperWeb.gray400),
            ),
          )
        else if (papers.isNotEmpty)
          _Rows(
            children: <Widget>[
              for (var i = 0; i < papers.length; i++)
                PaperListRow(
                  key: ValueKey<String>('download-${papers[i].id}'),
                  title: papers[i].title,
                  titleColor: PaperWeb.gray100,
                  titleMaxLines: 1,
                  descriptionWidget: _FileSize(path: papers[i].localFilePath),
                  last: i == papers.length - 1,
                  trailing: PaperButton.secondary(
                    label: l10n.storageRemove,
                    size: PaperButtonSize.xs,
                    focusGap: PaperWeb.gray900,
                    onPressed: () => unawaited(
                      ref
                          .read(paperRepositoryProvider)
                          .removeDownload(papers[i].id),
                    ),
                  ),
                ),
            ],
          ),
        _Footer(
          children: <Widget>[
            PaperButton.destructive(
              key: const ValueKey<String>('settings-remove-all'),
              label: l10n.storageRemoveAll,
              size: PaperButtonSize.md,
              focusGap: PaperWeb.gray900,
              onPressed: papers.isEmpty
                  ? null
                  : () => unawaited(_removeAll(papers)),
            ),
            _clearCacheButton(l10n),
            if (_cleared) _clearedLine,
          ],
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
    builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) {
        return const PaperSkeleton(width: 64, height: 12);
      }
      return Text(
        snap.data == null ? '' : _formatBytes(snap.data!),
        style: _xs(context, PaperWeb.gray400),
      );
    },
  );
}

class _SyncSection extends ConsumerWidget {
  const _SyncSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (ref.watch(isGuestProvider)) {
      return const Padding(
        padding: EdgeInsets.only(top: PaperSpacing.tw3),
        child: SignInPrompt(feature: GuestFeature.sync, dense: true),
      );
    }
    final status = ref.watch(syncStatusProvider).value ?? SyncStatus.idle;
    final replaced =
        ref.watch(replacedVersionsProvider).value ?? const <ReplacedVersion>[];
    final offline = status.phase == SyncPhase.offline;
    final canSync = !offline && status.phase != SyncPhase.syncing;
    final color = switch (status.phase) {
      SyncPhase.synced => PaperWeb.green400,
      SyncPhase.syncing => PaperWeb.accent,
      SyncPhase.pending => PaperWeb.amber400,
      SyncPhase.error => PaperWeb.red400,
      SyncPhase.offline => PaperWeb.gray400,
    };
    return _Rows(
      children: <Widget>[
        PaperListRow(
          key: const ValueKey<String>('settings-sync-status'),
          title: l10n.settingsSectionSync,
          descriptionWidget: Semantics(
            liveRegion: true,
            child: Row(
              children: <Widget>[
                if (status.phase == SyncPhase.syncing) ...<Widget>[
                  const PaperSpinner(),
                  const SizedBox(width: PaperSpacing.tw1_5),
                ],
                Flexible(
                  child: Text(
                    offline
                        ? '${syncLongText(context, status)} · '
                              '${l10n.settingsNeedsConnection}'
                        : syncLongText(context, status),
                    style: _xs(context, color),
                  ),
                ),
              ],
            ),
          ),
          trailing: PaperButton.secondary(
            label: l10n.settingsSyncNow,
            focusGap: PaperWeb.gray900,
            onPressed: canSync
                ? () => unawaited(ref.read(syncServiceProvider).syncNow())
                : null,
          ),
        ),
        PaperListRow(
          title: l10n.syncReplacedVersions(replaced.length),
          trailing: PaperButton.ghost(
            label: l10n.syncReview,
            size: PaperButtonSize.xs,
            focusGap: PaperWeb.gray900,
            onPressed: () => unawaited(showSyncSheet(context)),
          ),
        ),
        _LinkRow(
          label: l10n.syncHowItWorksTitle,
          last: true,
          onPressed: () => unawaited(showSyncHowItWorks(context)),
        ),
      ],
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _Rows(
      children: <Widget>[
        PaperListRow(
          title: l10n.aboutVersion(kAppVersion),
          titleColor: PaperWeb.gray400,
        ),
        _LinkRow(
          label: l10n.aboutTerms,
          external: true,
          onPressed: () => unawaited(_openWeb('/terms')),
        ),
        _LinkRow(
          label: l10n.aboutPrivacy,
          external: true,
          onPressed: () => unawaited(_openWeb('/privacy')),
        ),
        _LinkRow(
          key: const ValueKey<String>('settings-licenses'),
          label: l10n.aboutLicenses,
          last: true,
          onPressed: () => showLicensePage(
            context: context,
            applicationName: l10n.appName,
            applicationVersion: kAppVersion,
          ),
        ),
      ],
    );
  }
}
