import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../auth/auth_providers.dart';
import '../../core/format.dart';
import '../../domain/domain.dart';
import '../../l10n/app_localizations.dart';
import '../../sync/sync_providers.dart';
import '../../theme/paper_tokens.dart';
import '../../ui/ui.dart';
import 'sync_badge.dart';

/// Opens the SyncSheet as a `PaperDialog` (`max-w-md`, `p-5`): status,
/// queued / failed / replaced items, Close + Sync now. It scrolls inside
/// when taller than the window.
Future<void> showSyncSheet(BuildContext context) => showPaperDialog<void>(
  context: context,
  builder: (context) => const _SyncSheetDialog(),
);

class _SyncSheetDialog extends ConsumerWidget {
  const _SyncSheetDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final status = ref.watch(syncStatusProvider).value ?? SyncStatus.idle;
    final canSync =
        status.phase != SyncPhase.offline && status.phase != SyncPhase.syncing;
    return PaperDialog(
      title: l10n.settingsSectionSync,
      content: const SyncSheet(),
      actions: <Widget>[
        PaperButton.secondary(
          label: l10n.commonClose,
          focusGap: PaperWeb.gray900,
          onPressed: () => Navigator.of(context).pop(),
        ),
        PaperButton.primary(
          key: const ValueKey<String>('sync-now'),
          label: l10n.syncNow,
          focusGap: PaperWeb.gray900,
          tooltip: status.phase == SyncPhase.offline
              ? l10n.settingsNeedsConnection
              : null,
          onPressed: canSync
              ? () => unawaited(ref.read(syncServiceProvider).syncNow())
              : null,
        ),
      ],
    );
  }
}

/// Label for one outbox op ("1 highlight", "1 rename"...).
String syncOpLabel(AppLocalizations l10n, SyncOp op) =>
    switch ((op.entity, op.kind)) {
      (SyncEntity.paper, SyncOpKind.create) => l10n.syncChangeUpload(1),
      (SyncEntity.paper, SyncOpKind.update) => l10n.syncChangeRename(1),
      (_, SyncOpKind.delete) => l10n.syncChangeDelete(1),
      _ => l10n.syncChangeHighlights(1),
    };

/// SyncSheet body: status line, pending changes, items that couldn't
/// sync (Try again / Discard), replaced versions (Restore mine / Dismiss),
/// "How syncing works" and a link to the Sync settings.
class SyncSheet extends ConsumerWidget {
  const SyncSheet({super.key});

  static const int _maxRows = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final status = ref.watch(syncStatusProvider).value ?? SyncStatus.idle;
    final ops = ref.watch(pendingOpsProvider).value ?? const <SyncOp>[];
    final replaced =
        ref.watch(replacedVersionsProvider).value ?? const <ReplacedVersion>[];
    final service = ref.read(syncServiceProvider);

    final pending = ops.where((o) => !o.failed).toList();
    final failed = ops.where((o) => o.failed).toList();

    // Pending grouped by type.
    final groups = <String, int>{};
    for (final op in pending) {
      final key = switch ((op.entity, op.kind)) {
        (SyncEntity.paper, SyncOpKind.create) => 'upload',
        (SyncEntity.paper, SyncOpKind.update) => 'rename',
        (_, SyncOpKind.delete) => 'delete',
        _ => 'highlights',
      };
      groups[key] = (groups[key] ?? 0) + 1;
    }
    String groupLabel(String key, int n) => switch (key) {
      'upload' => l10n.syncChangeUpload(n),
      'rename' => l10n.syncChangeRename(n),
      'delete' => l10n.syncChangeDelete(n),
      _ => l10n.syncChangeHighlights(n),
    };

    final statusColor = switch (status.phase) {
      SyncPhase.synced => PaperWeb.green400,
      SyncPhase.syncing => PaperWeb.accent,
      SyncPhase.pending => PaperWeb.amber400,
      SyncPhase.error => PaperWeb.red400,
      SyncPhase.offline => PaperWeb.gray400,
    };
    TextStyle? xs(Color c) => t.bodySmall?.copyWith(color: c);

    Widget section(String title) => Padding(
      padding: const EdgeInsets.only(top: PaperSpacing.tw4),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: t.labelLarge?.copyWith(color: PaperWeb.gray300),
        ),
      ),
    );
    Widget more(int n) => Padding(
      padding: const EdgeInsets.only(top: PaperSpacing.tw2),
      child: Text(l10n.syncAndMore(n), style: xs(PaperWeb.gray400)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Semantics(
          liveRegion: true,
          child: Row(
            children: <Widget>[
              PaperIcon(syncPhaseIcon(status.phase), color: statusColor),
              const SizedBox(width: PaperSpacing.tw2),
              Expanded(
                child: Text(
                  syncLongText(context, status),
                  style: xs(statusColor),
                ),
              ),
            ],
          ),
        ),
        if (status.authExpired) ...<Widget>[
          const SizedBox(height: PaperSpacing.tw3),
          Container(
            key: const ValueKey<String>('sync-auth-expired'),
            padding: const EdgeInsets.all(PaperSpacing.tw4),
            decoration: BoxDecoration(
              color: PaperWeb.red950,
              border: Border.all(color: PaperWeb.red900),
              borderRadius: PaperRadii.borderLg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.syncAuthExpired,
                  style: t.bodyMedium?.copyWith(color: PaperWeb.red300),
                ),
                const SizedBox(height: PaperSpacing.tw3),
                PaperButton.secondary(
                  label: l10n.syncSignInAgain,
                  size: PaperButtonSize.xs,
                  focusGap: PaperWeb.red950,
                  onPressed: () => unawaited(signInAgain(context, ref)),
                ),
              ],
            ),
          ),
        ],
        if (pending.isNotEmpty) ...<Widget>[
          section(
            status.phase == SyncPhase.offline
                ? l10n.syncPendingOffline(pending.length)
                : l10n.syncPendingCount(pending.length),
          ),
          const SizedBox(height: PaperSpacing.tw1),
          for (final (i, e) in groups.entries.take(_maxRows).indexed)
            PaperListRow(
              title: groupLabel(e.key, e.value),
              titleColor: PaperWeb.gray100,
              last: i == math.min(groups.length, _maxRows) - 1,
            ),
          if (groups.length > _maxRows) more(groups.length - _maxRows),
        ],
        if (failed.isNotEmpty) ...<Widget>[
          section(l10n.syncErrorSummary(failed.length)),
          const SizedBox(height: PaperSpacing.tw1),
          for (final (i, op) in failed.take(_maxRows).indexed)
            PaperListRow(
              key: ValueKey<String>('sync-failed-${op.id}'),
              title: syncOpLabel(l10n, op),
              titleColor: PaperWeb.gray100,
              description: op.lastError == 'notFound'
                  ? l10n.syncItemPaperDeleted
                  : l10n.syncItemRejected,
              last: i == math.min(failed.length, _maxRows) - 1,
              trailing: Wrap(
                spacing: PaperSpacing.tw1,
                children: <Widget>[
                  PaperButton.ghost(
                    label: l10n.syncRetry,
                    size: PaperButtonSize.xs,
                    focusGap: PaperWeb.gray900,
                    onPressed: () => unawaited(service.retryOp(op.id)),
                  ),
                  PaperButton.destructive(
                    label: l10n.syncDiscard,
                    focusGap: PaperWeb.gray900,
                    onPressed: () => unawaited(service.discardOp(op.id)),
                  ),
                ],
              ),
            ),
          if (failed.length > _maxRows) more(failed.length - _maxRows),
        ],
        section(l10n.syncReplacedVersions(replaced.length)),
        const SizedBox(height: PaperSpacing.tw1),
        if (replaced.isEmpty)
          Text(l10n.syncReplacedEmpty, style: xs(PaperWeb.gray400))
        else ...<Widget>[
          for (final (i, r) in replaced.indexed)
            ReplacedVersionTile(
              key: ValueKey<String>('replaced-${r.id}'),
              version: r,
              last: i == replaced.length - 1,
              onRestore: () => unawaited(service.restoreReplaced(r.id)),
              onDismiss: () => unawaited(service.dismissReplaced(r.id)),
            ),
          const SizedBox(height: PaperSpacing.tw2),
          Text(l10n.syncReplacedExpiry, style: xs(PaperWeb.gray400)),
        ],
        const SizedBox(height: PaperSpacing.tw4),
        Wrap(
          spacing: PaperSpacing.tw4,
          runSpacing: PaperSpacing.tw2,
          children: <Widget>[
            PaperLink(
              label: l10n.syncHowItWorksTitle,
              onPressed: () => unawaited(showSyncHowItWorks(context)),
            ),
            PaperLink(
              label: l10n.syncSettingsLink,
              onPressed: () {
                Navigator.of(context).pop();
                GoRouter.maybeOf(context)?.go(AppRoutes.settings);
              },
            ),
          ],
        ),
      ],
    );
  }
}

/// Auth expired → sign in again. Ends the dead session only (the outbox
/// and local data stay, and are kept for the same account).
Future<void> signInAgain(BuildContext context, WidgetRef ref) async {
  final router = GoRouter.maybeOf(context);
  final auth = ref.read(authRepositoryProvider);
  unawaited(Navigator.of(context).maybePop());
  try {
    await auth.signOut();
  } on Object {
    // Best effort: the session is already dead.
  }
  // Pushed: closing sign-in (or signing in) returns to where the user was.
  await router?.push<void>('${AppRoutes.signIn}?expired=1');
}

Future<void> showSyncHowItWorks(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showPaperDialog<void>(
    context: context,
    builder: (context) => PaperDialog(
      title: l10n.syncHowItWorksTitle,
      body: l10n.syncHowItWorksBody,
      actions: <Widget>[
        PaperButton.primary(
          label: l10n.commonOk,
          autofocus: true,
          focusGap: PaperWeb.gray900,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );
}

/// One replaced version (a `PaperListRow`): what was mine and when, when
/// the kept one was written; Restore mine / Dismiss.
class ReplacedVersionTile extends StatelessWidget {
  const ReplacedVersionTile({
    super.key,
    required this.version,
    required this.onRestore,
    required this.onDismiss,
    this.last = false,
  });

  final ReplacedVersion version;
  final VoidCallback onRestore;
  final VoidCallback onDismiss;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final mine = version.mine;
    final value = mine['note'] ?? mine['title'] ?? mine['body'] ?? '';
    return PaperListRow(
      title: '${l10n.syncReplacedYours}: “$value”',
      titleColor: PaperWeb.gray100,
      titleMaxLines: 3,
      last: last,
      descriptionWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${formatWhen(context, version.mineUpdatedAt)} · '
            '${l10n.syncReplacedKept} · '
            '${formatWhen(context, version.theirsUpdatedAt)}',
            style: t.bodySmall?.copyWith(color: PaperWeb.gray400),
          ),
          const SizedBox(height: PaperSpacing.tw2),
          Wrap(
            spacing: PaperSpacing.tw1,
            children: <Widget>[
              PaperButton.ghost(
                label: l10n.syncRestoreMine,
                size: PaperButtonSize.xs,
                focusGap: PaperWeb.gray900,
                onPressed: onRestore,
              ),
              PaperButton.ghost(
                label: l10n.syncDismiss,
                size: PaperButtonSize.xs,
                focusGap: PaperWeb.gray900,
                onPressed: onDismiss,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
