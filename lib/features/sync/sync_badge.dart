import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../auth/auth_providers.dart';
import '../../core/format.dart';
import '../../domain/domain.dart';
import '../../l10n/app_localizations.dart';
import '../../sync/sync_providers.dart';
import '../../theme/motion_extras.dart';
import '../../theme/paper_tokens.dart';
import '../../theme/theme_x.dart';
import '../auth/sign_in_prompt.dart';
import 'sync_sheet.dart';

/// The three SyncBadge forms (components.md §2).
enum SyncBadgeForm {
  /// Icon + count dot: rail bottom, compact app bar, reader toolbar.
  icon,

  /// Pill with short text: reader toolbar on large+ with a pointer.
  short,

  /// Icon + long text: sidebar row, Settings › Sync, SyncSheet header.
  long,
}

IconData syncPhaseIcon(SyncPhase phase) => switch (phase) {
  SyncPhase.synced => Symbols.cloud_done_rounded,
  SyncPhase.syncing => Symbols.sync_rounded,
  SyncPhase.pending => Symbols.cloud_upload_rounded,
  SyncPhase.offline => Symbols.cloud_off_rounded,
  SyncPhase.error => Symbols.warning_rounded,
};

Color syncPhaseColor(PaperColors c, SyncPhase phase) => switch (phase) {
  SyncPhase.synced => c.statusSynced,
  SyncPhase.syncing => c.statusSyncing,
  SyncPhase.pending => c.statusSyncPending,
  SyncPhase.offline => c.statusOffline,
  SyncPhase.error => c.statusSyncError,
};

String syncShortText(AppLocalizations l10n, SyncPhase phase) => switch (phase) {
  SyncPhase.synced => l10n.syncStateSynced,
  SyncPhase.syncing => l10n.syncStateSyncing,
  SyncPhase.pending => l10n.syncStatePending,
  SyncPhase.offline => l10n.syncStateOffline,
  SyncPhase.error => l10n.syncStateError,
};

/// Long text for [status] shown as [phase] (sync-status.md table).
String syncLongText(
  BuildContext context,
  SyncStatus status, {
  SyncPhase? phase,
}) {
  final l10n = AppLocalizations.of(context);
  switch (phase ?? status.phase) {
    case SyncPhase.synced:
      final last = status.lastSyncedAt;
      return last == null
          ? l10n.syncNeverSynced
          : l10n.syncLastSynced(formatWhen(context, last));
    case SyncPhase.syncing:
      return status.progressTotal > 0
          ? l10n.syncProgress(status.progressDone, status.progressTotal)
          : l10n.syncStateSyncing;
    case SyncPhase.pending:
      return l10n.syncPendingCount(status.pendingCount);
    case SyncPhase.offline:
      return status.pendingCount > 0
          ? l10n.syncPendingOffline(status.pendingCount)
          : l10n.syncOfflineNoChanges;
    case SyncPhase.error:
      return status.authExpired
          ? l10n.syncAuthExpired
          : l10n.syncErrorSummary(status.failedCount);
  }
}

int _count(SyncStatus s, SyncPhase phase) => switch (phase) {
  SyncPhase.pending || SyncPhase.offline => s.pendingCount,
  SyncPhase.error => s.failedCount,
  _ => 0,
};

/// Global sync indicator. Always a button that opens the SyncSheet; state
/// is never colour-only (own icon shape + text). `syncing` shows only for
/// syncs longer than [kSyncingMinVisible].
class SyncBadge extends ConsumerStatefulWidget {
  const SyncBadge({super.key, this.form = SyncBadgeForm.icon});

  final SyncBadgeForm form;

  @override
  ConsumerState<SyncBadge> createState() => _SyncBadgeState();
}

class _SyncBadgeState extends ConsumerState<SyncBadge> {
  SyncPhase? _shown;
  Timer? _syncingDelay;

  @override
  void dispose() {
    _syncingDelay?.cancel();
    super.dispose();
  }

  SyncPhase _resolve(SyncPhase actual) {
    if (actual != SyncPhase.syncing) {
      _syncingDelay?.cancel();
      _syncingDelay = null;
      return _shown = actual;
    }
    if (_shown == SyncPhase.syncing) return SyncPhase.syncing;
    _syncingDelay ??= Timer(kSyncingMinVisible, () {
      if (!mounted) return;
      final now = ref.read(syncStatusProvider).value?.phase;
      if (now == SyncPhase.syncing) setState(() => _shown = SyncPhase.syncing);
    });
    return _shown ?? SyncPhase.synced;
  }

  @override
  Widget build(BuildContext context) {
    // Guests (no account): the badge is the library chrome's small
    // "Sign in" affordance instead of a sync state.
    if (ref.watch(isGuestProvider)) return GuestSignInBadge(form: widget.form);
    final l10n = AppLocalizations.of(context);
    final c = context.paper;
    final status = ref.watch(syncStatusProvider).value ?? SyncStatus.idle;
    final phase = _resolve(status.phase);
    final longText = syncLongText(context, status, phase: phase);
    final color = syncPhaseColor(c, phase);
    final count = _count(status, phase);

    Widget glyph = Icon(
      syncPhaseIcon(phase),
      key: ValueKey<SyncPhase>(phase),
      size: widget.form == SyncBadgeForm.short ? 18 : PaperIconSize.md,
      color: color,
    );
    if (phase == SyncPhase.syncing) glyph = _Spinner(child: glyph);
    if (count > 0 && widget.form != SyncBadgeForm.long) {
      glyph = Badge(
        label: Text('$count'),
        backgroundColor: color,
        textColor: c.onSecondary,
        child: glyph,
      );
    }
    final switched = AnimatedSwitcher(
      duration: PaperMotion.fade(context, PaperMotion.base),
      switchInCurve: PaperMotion.standard,
      switchOutCurve: PaperMotion.standard,
      child: KeyedSubtree(key: ValueKey<SyncPhase>(phase), child: glyph),
    );

    final Widget child = switch (widget.form) {
      SyncBadgeForm.icon => SizedBox(
        width: 40,
        height: 40,
        child: Center(child: switched),
      ),
      SyncBadgeForm.short => Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: phase == SyncPhase.error ? c.errorSurface : c.surfaceVariant,
          border: phase == SyncPhase.error
              ? Border.all(color: c.errorBorder)
              : null,
          borderRadius: PaperRadii.borderFull,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            switched,
            const SizedBox(width: 6),
            Text(
              count > 0
                  ? '${syncShortText(l10n, phase)} · $count'
                  : syncShortText(l10n, phase),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: phase == SyncPhase.error
                    ? c.onErrorSurface
                    : c.textPrimary,
              ),
            ),
          ],
        ),
      ),
      SyncBadgeForm.long => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: PaperSpacing.md,
          vertical: PaperSpacing.sm,
        ),
        child: Row(
          children: <Widget>[
            switched,
            const SizedBox(width: PaperSpacing.sm),
            Expanded(
              child: Text(
                longText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(fontSize: 13, color: c.textPrimary),
              ),
            ),
          ],
        ),
      ),
    };

    return Semantics(
      button: true,
      label: l10n.syncBadgeSemantics(longText),
      excludeSemantics: true,
      child: Tooltip(
        message: longText,
        child: InkWell(
          key: const ValueKey<String>('sync-badge'),
          borderRadius: widget.form == SyncBadgeForm.long
              ? PaperRadii.borderMd
              : PaperRadii.borderFull,
          onTap: () => unawaited(showSyncSheet(context)),
          child: child,
        ),
      ),
    );
  }
}

/// [SyncBadge] in guest mode: a calm "Sign in" affordance in the same slot
/// (rail bottom, sidebar row, compact top bar, reader toolbar, Settings ›
/// Sync). Opens the sign-in screen, which can be dismissed.
class GuestSignInBadge extends StatelessWidget {
  const GuestSignInBadge({super.key, this.form = SyncBadgeForm.icon});

  static const Key badgeKey = ValueKey<String>('guest-sign-in-badge');

  final SyncBadgeForm form;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.paper;
    final t = Theme.of(context).textTheme;
    final glyph = Icon(
      Symbols.account_circle_rounded,
      size: form == SyncBadgeForm.short ? 18 : PaperIconSize.md,
      color: c.textSecondary,
    );
    final Widget child = switch (form) {
      SyncBadgeForm.icon => SizedBox(
        width: 40,
        height: 40,
        child: Center(child: glyph),
      ),
      SyncBadgeForm.short => Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: c.surfaceVariant,
          borderRadius: PaperRadii.borderFull,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            glyph,
            const SizedBox(width: 6),
            Text(
              l10n.commonSignIn,
              style: t.labelMedium?.copyWith(color: c.textPrimary),
            ),
          ],
        ),
      ),
      SyncBadgeForm.long => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: PaperSpacing.md,
          vertical: PaperSpacing.sm,
        ),
        child: Row(
          children: <Widget>[
            glyph,
            const SizedBox(width: PaperSpacing.sm),
            Expanded(
              child: Text(
                l10n.guestSyncTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: t.labelLarge?.copyWith(
                  fontSize: 13,
                  color: c.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    };
    return Semantics(
      button: true,
      label: l10n.guestBadgeSemantics,
      excludeSemantics: true,
      child: Tooltip(
        message: l10n.guestSyncTitle,
        child: InkWell(
          key: badgeKey,
          borderRadius: form == SyncBadgeForm.long
              ? PaperRadii.borderMd
              : PaperRadii.borderFull,
          onTap: () => unawaited(openSignIn(context)),
          child: child,
        ),
      ),
    );
  }
}

/// Syncing glyph rotation (motion #24): 1 turn / [kSpinPeriod], linear,
/// in its own RepaintBoundary (B8); static under reduced motion.
class _Spinner extends StatefulWidget {
  const _Spinner({required this.child});

  final Widget child;

  @override
  State<_Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<_Spinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: kSpinPeriod,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _spin.stop();
    } else if (!_spin.isAnimating) {
      unawaited(_spin.repeat());
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: RotationTransition(turns: _spin, child: widget.child),
  );
}
