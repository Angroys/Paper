import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/auth_providers.dart';
import '../../core/core_providers.dart';
import '../../data/data_providers.dart';
import '../../domain/domain.dart';
import '../../l10n/app_localizations.dart';
import '../../sync/sync_providers.dart';
import '../../theme/theme_x.dart';

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
  final decision = await showDialog<SignOutDecision>(
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
    final c = context.paper;
    final pending = widget.pendingCount > 0;
    final String body;
    if (!pending) {
      body = _remove ? l10n.signOutRemoveBody : l10n.signOutConfirmBody;
    } else {
      body = _remove
          ? l10n.signOutPendingBody(widget.pendingCount)
          : l10n.signOutPendingKeptBody(widget.pendingCount);
    }
    return AlertDialog(
      title: Text(
        pending ? l10n.signOutPendingTitle : l10n.signOutConfirmTitle,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(body, key: const ValueKey<String>('signOut.body')),
          if (_remove && widget.localOnlyNotes > 0) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              l10n.signOutLocalOnlyBody(widget.localOnlyNotes),
              key: const ValueKey<String>('signOut.localOnly'),
            ),
          ],
          const SizedBox(height: 8),
          CheckboxListTile(
            key: SignOutDialog.removeLocalKey,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            value: _remove,
            onChanged: (v) => setState(() => _remove = v ?? false),
            title: Text(l10n.signOutRemoveLocal),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          autofocus: true,
          onPressed: () => _pop(SignOutChoice.cancel),
          child: Text(l10n.commonCancel),
        ),
        if (pending && widget.online)
          FilledButton(
            onPressed: () => _pop(SignOutChoice.syncFirst),
            child: Text(l10n.signOutSyncFirst),
          ),
        OutlinedButton(
          key: const ValueKey<String>('signOut.confirm'),
          style: OutlinedButton.styleFrom(
            foregroundColor: c.error,
            side: BorderSide(color: c.errorBorder),
          ),
          onPressed: () => _pop(SignOutChoice.signOut),
          child: Text(pending ? l10n.signOutAnyway : l10n.settingsSignOut),
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
