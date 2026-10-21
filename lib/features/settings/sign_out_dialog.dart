import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/auth_providers.dart';
import '../../core/core_providers.dart';
import '../../data/data_providers.dart';
import '../../domain/domain.dart';
import '../../l10n/app_localizations.dart';
import '../../sync/sync_providers.dart';
import '../../theme/paper_tokens.dart';
import '../../ui/ui.dart';

/// What the user chose in [SignOutDialog].
enum SignOutChoice { cancel, syncFirst, signOut }

/// [SignOutDialog] result: the button, and whether to remove this
/// account's papers from the device (off by default: they stay readable).
typedef SignOutDecision = ({SignOutChoice choice, bool removeLocalData});

/// Gathers the counts, shows [SignOutDialog] and signs out unless
/// cancelled. The app carries on as a guest; papers on this device are kept
/// unless the user ticked "remove". Returns true when signed out.
Future<bool> confirmAndSignOut(BuildContext context, WidgetRef ref) async {
  final pending = ref.read(syncServiceProvider).status.pendingCount;
  int localOnly;
  try {
    localOnly = await ref.read(noteRepositoryProvider).countLocalOnlyNotes();
  } on Object {
    localOnly = 0;
  }
  if (!context.mounted) return false;
  final online = ref.read(isOnlineProvider).value ?? true;
  final decision = await showPaperDialog<SignOutDecision>(
    context: context,
    builder: (context) => SignOutDialog(
      pendingCount: pending,
      localOnlyNotes: localOnly,
      online: online,
    ),
  );
  if (decision == null || decision.choice == SignOutChoice.cancel) {
    return false;
  }
  if (decision.choice == SignOutChoice.syncFirst) {
    try {
      await ref.read(syncServiceProvider).syncNow();
    } on Object {
      // Sign out anyway: the user asked to.
    }
  }
  await ref.read(signOutProvider)(keepLocalData: !decision.removeLocalData);
  return true;
}

/// `SignOutDialog` (settings.md): simple confirm, or the pending-changes
/// variant. Papers on this device stay readable after sign-out by default
/// (the safe choice); a checkbox removes them instead, and only then are
/// device-local notes (`signOutLocalOnlyBody`) and unsynced changes lost.
/// Cancel has the default focus; the destructive action never does.
class SignOutDialog extends StatefulWidget {
  const SignOutDialog({
    super.key,
    required this.pendingCount,
    required this.localOnlyNotes,
    required this.online,
  });

  static const Key removeLocalKey = ValueKey<String>('signOut.removeLocal');

  final int pendingCount;
  final int localOnlyNotes;
  final bool online;

  @override
  State<SignOutDialog> createState() => _SignOutDialogState();
}

class _SignOutDialogState extends State<SignOutDialog> {
  bool _remove = false;

  void _pop(SignOutChoice choice) =>
      Navigator.of(context)
          .pop<SignOutDecision>((choice: choice, removeLocalData: _remove));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final pending = widget.pendingCount > 0;
    final String body;
    if (!pending) {
      body = _remove ? l10n.signOutRemoveBody : l10n.signOutConfirmBody;
    } else {
      body = _remove
          ? l10n.signOutPendingBody(widget.pendingCount)
          : l10n.signOutPendingKeptBody(widget.pendingCount);
    }
    return PaperDialog(
      title: pending ? l10n.signOutPendingTitle : l10n.signOutConfirmTitle,
      // Body `mt-2`; the optional local-only paragraph and the checkbox
      // row follow in the content slot.
      body: body,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_remove && widget.localOnlyNotes > 0) ...<Widget>[
            Text(
              l10n.signOutLocalOnlyBody(widget.localOnlyNotes),
              key: const ValueKey<String>('signOut.localOnly'),
              style: t.bodyMedium?.copyWith(color: PaperWeb.gray400),
            ),
            const SizedBox(height: PaperSpacing.tw4),
          ],
          PaperCheckboxRow(
            key: SignOutDialog.removeLocalKey,
            value: _remove,
            label: l10n.signOutRemoveLocal,
            onChanged: (v) => setState(() => _remove = v),
          ),
        ],
      ),
      actions: <Widget>[
        PaperButton.secondary(
          label: l10n.commonCancel,
          autofocus: true,
          focusGap: PaperWeb.gray900,
          onPressed: () => _pop(SignOutChoice.cancel),
        ),
        if (pending && widget.online)
          PaperButton.secondary(
            label: l10n.signOutSyncFirst,
            focusGap: PaperWeb.gray900,
            onPressed: () => _pop(SignOutChoice.syncFirst),
          ),
        PaperButton.destructive(
          key: const ValueKey<String>('signOut.confirm'),
          label: pending ? l10n.signOutAnyway : l10n.settingsSignOut,
          size: PaperButtonSize.md,
          focusGap: PaperWeb.gray900,
          onPressed: () => _pop(SignOutChoice.signOut),
        ),
      ],
    );
  }
}

/// Signed-in user (null otherwise).
AppUser? currentUser(WidgetRef ref) => ref.watch(authStateProvider).value?.user;

/// Fire-and-forget wrapper for buttons.
void signOutTapped(BuildContext context, WidgetRef ref) =>
    unawaited(confirmAndSignOut(context, ref));
