import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app/routes.dart';
import '../../auth/auth_providers.dart';
import '../../core/format.dart';
import '../../domain/domain.dart';
import '../../l10n/app_localizations.dart';
import '../../sync/sync_providers.dart';
import '../../theme/paper_tokens.dart';
import '../../theme/theme_x.dart';
import '../../ui/ui.dart';
import 'sync_badge.dart';

/// Opens the SyncSheet: an anchored-style dialog (360 wide) on large+
/// windows, a modal bottom sheet otherwise.
Future<void> showSyncSheet(BuildContext context) {
  final wc = PaperWindowClass.ofContext(context);
  if (wc.usesSidebar) {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        alignment: Alignment.topLeft,
        insetPadding: const EdgeInsets.all(PaperSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360, maxHeight: 640),
          child: const SyncSheet(),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: const SyncSheet(),
    ),
  );
}

/// Label for one outbox op ("1 highlight", "1 rename"...).
String syncOpLabel(AppLocalizations l10n, SyncOp op) =>
    switch ((op.entity, op.kind)) {
      (SyncEntity.paper, SyncOpKind.create) => l10n.syncChangeUpload(1),
      (SyncEntity.paper, SyncOpKind.update) => l10n.syncChangeRename(1),
      (_, SyncOpKind.delete) => l10n.syncChangeDelete(1),
      _ => l10n.syncChangeHighlights(1),
    };

/// SyncSheet body: status + Sync now, pending changes, items that couldn't
/// sync (Retry / Discard), replaced versions (Restore mine / Dismiss),
/// "How syncing works" and a link to the Sync settings.
class SyncSheet extends ConsumerWidget {
  const SyncSheet({super.key});

  static const int _maxRows = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = context.paper;
    final t = Theme.of(context).textTheme;
    final status = ref.watch(syncStatusProvider).value ?? SyncStatus.idle;
    final ops = ref.watch(pendingOpsProvider).value ?? const <SyncOp>[];
    final replaced =
        ref.watch(replacedVersionsProvider).value ?? const <ReplacedVersion>[];
    final service = ref.read(syncServiceProvider);

    final pending = ops.where((o) => !o.failed).toList();
    final failed = ops.where((o) => o.failed).toList();
    final canSync =
        status.phase != SyncPhase.offline && status.phase != SyncPhase.syncing;

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

    Widget section(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(
        PaperSpacing.lg,
        PaperSpacing.lg,
        PaperSpacing.lg,
        PaperSpacing.xs,
      ),
      child: Semantics(header: true, child: Text(title, style: t.labelLarge)),
    );

    return Material(
      color: Colors.transparent,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: PaperSpacing.lg),
        children: <Widget>[
          // Header: long status + Sync now.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              PaperSpacing.lg,
              PaperSpacing.md,
              PaperSpacing.md,
              PaperSpacing.sm,
            ),
            child: Row(
              children: <Widget>[
                PaperIcon(
                  syncPhaseIcon(status.phase),
                  color: syncPhaseColor(c, status.phase),
                ),
                const SizedBox(width: PaperSpacing.sm),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      syncLongText(context, status),
                      style: t.labelLarge,
                    ),
                  ),
                ),
                Tooltip(
                  message: status.phase == SyncPhase.offline
                      ? l10n.settingsNeedsConnection
                      : '',
                  child: TextButton.icon(
                    key: const ValueKey<String>('sync-now'),
                    onPressed: canSync
                        ? () => unawaited(service.syncNow())
                        : null,
                    icon: const Icon(Symbols.sync_rounded, size: 18),
                    label: Text(l10n.syncNow),
                  ),
                ),
              ],
            ),
          ),
          if (status.authExpired)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: PaperSpacing.lg),
              child: Container(
                key: const ValueKey<String>('sync-auth-expired'),
                padding: const EdgeInsets.all(PaperSpacing.md),
                decoration: BoxDecoration(
                  color: c.errorSurface,
                  border: Border.all(color: c.errorBorder),
                  borderRadius: PaperRadii.borderLg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.syncAuthExpired,
                      style: t.bodyMedium?.copyWith(color: c.onErrorSurface),
                    ),
                    const SizedBox(height: PaperSpacing.sm),
                    FilledButton(
                      onPressed: () => unawaited(signInAgain(context, ref)),
                      child: Text(l10n.syncSignInAgain),
                    ),
                  ],
                ),
              ),
            ),
          const Divider(height: PaperSpacing.lg),
          if (pending.isNotEmpty) ...<Widget>[
            section(
              status.phase == SyncPhase.offline
                  ? l10n.syncPendingOffline(pending.length)
                  : l10n.syncPendingCount(pending.length),
            ),
            for (final e in groups.entries.take(_maxRows))
              ListTile(
                dense: true,
                leading: Icon(
                  Symbols.cloud_upload_rounded,
                  size: 16,
                  color: c.textSecondary,
                ),
                title: Text(groupLabel(e.key, e.value)),
              ),
            if (groups.length > _maxRows)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: PaperSpacing.lg,
                ),
                child: Text(l10n.syncAndMore(groups.length - _maxRows)),
              ),
          ],
          if (failed.isNotEmpty) ...<Widget>[
            section(l10n.syncErrorSummary(failed.length)),
            for (final op in failed.take(_maxRows))
              Padding(
                key: ValueKey<String>('sync-failed-${op.id}'),
                padding: const EdgeInsets.symmetric(
                  horizontal: PaperSpacing.lg,
                  vertical: PaperSpacing.xs,
                ),
                child: Container(
                  padding: const EdgeInsets.all(PaperSpacing.md),
                  decoration: BoxDecoration(
                    color: c.errorSurface,
                    borderRadius: PaperRadii.borderMd,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(
                            Symbols.warning_rounded,
                            size: 16,
                            color: c.error,
                          ),
                          const SizedBox(width: PaperSpacing.sm),
                          Expanded(
                            child: Text(
                              syncOpLabel(l10n, op),
                              style: t.labelLarge?.copyWith(
                                color: c.onErrorSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        op.lastError == 'notFound'
                            ? l10n.syncItemPaperDeleted
                            : l10n.syncItemRejected,
                        style: t.bodySmall?.copyWith(color: c.onErrorSurface),
                      ),
                      Wrap(
                        spacing: PaperSpacing.sm,
                        children: <Widget>[
                          TextButton(
                            onPressed: () =>
                                unawaited(service.discardOp(op.id)),
                            child: Text(l10n.syncDiscard),
                          ),
                          TextButton(
                            onPressed: () => unawaited(service.retryOp(op.id)),
                            child: Text(l10n.syncRetry),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            if (failed.length > _maxRows)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: PaperSpacing.lg,
                ),
                child: Text(l10n.syncAndMore(failed.length - _maxRows)),
              ),
          ],
          section(l10n.syncReplacedVersions(replaced.length)),
          if (replaced.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: PaperSpacing.lg),
              child: Text(
                l10n.syncReplacedEmpty,
                style: t.bodySmall?.copyWith(color: c.textMuted),
              ),
            )
          else ...<Widget>[
            for (final r in replaced)
              ReplacedVersionTile(
                key: ValueKey<String>('replaced-${r.id}'),
                version: r,
                onRestore: () => unawaited(service.restoreReplaced(r.id)),
                onDismiss: () => unawaited(service.dismissReplaced(r.id)),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: PaperSpacing.lg),
              child: Text(
                l10n.syncReplacedExpiry,
                style: t.bodySmall?.copyWith(color: c.textMuted),
              ),
            ),
          ],
          const Divider(height: PaperSpacing.xl),
          ListTile(
            title: Text(l10n.syncHowItWorksTitle),
            trailing: const Icon(Symbols.chevron_right_rounded),
            onTap: () => unawaited(showSyncHowItWorks(context)),
          ),
          ListTile(
            title: Text(l10n.syncSettingsLink),
            trailing: const Icon(Symbols.chevron_right_rounded),
            onTap: () {
              Navigator.of(context).pop();
              GoRouter.maybeOf(context)?.go(AppRoutes.settings);
            },
          ),
        ],
      ),
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
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.syncHowItWorksTitle),
      content: Text(l10n.syncHowItWorksBody),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonOk),
        ),
      ],
    ),
  );
}

/// One replaced version: what was mine, when, and when the kept one was
/// written; Restore mine / Dismiss.
class ReplacedVersionTile extends StatelessWidget {
  const ReplacedVersionTile({
    super.key,
    required this.version,
    required this.onRestore,
    required this.onDismiss,
  });

  final ReplacedVersion version;
  final VoidCallback onRestore;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.paper;
    final t = Theme.of(context).textTheme;
    final mine = version.mine;
    final value = mine['note'] ?? mine['title'] ?? mine['body'] ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: PaperSpacing.lg,
        vertical: PaperSpacing.xs,
      ),
      child: Container(
        padding: const EdgeInsets.all(PaperSpacing.md),
        decoration: BoxDecoration(
          color: c.surfaceVariant,
          borderRadius: PaperRadii.borderMd,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${l10n.syncReplacedYours}: “$value”',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: t.bodyMedium,
            ),
            Text(
              formatWhen(context, version.mineUpdatedAt),
              style: t.bodySmall?.copyWith(color: c.textMuted),
            ),
            const SizedBox(height: PaperSpacing.xs),
            Text(
              '${l10n.syncReplacedKept} · ${formatWhen(context, version.theirsUpdatedAt)}',
              style: t.bodySmall?.copyWith(color: c.textSecondary),
            ),
            Wrap(
              spacing: PaperSpacing.sm,
              children: <Widget>[
                OutlinedButton(
                  onPressed: onRestore,
                  child: Text(l10n.syncRestoreMine),
                ),
                TextButton(onPressed: onDismiss, child: Text(l10n.syncDismiss)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
