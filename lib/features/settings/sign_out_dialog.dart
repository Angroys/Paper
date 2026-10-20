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

/// Gathers the counts, shows [SignOutDialog] and signs out (wiping local
/// data) unless cancelled. Returns true when signed out.
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
  final choice = await showDialog<SignOutChoice>(
    context: context,
    builder: (context) => SignOutDialog(
      pendingCount: pending,
      localOnlyNotes: localOnly,
      online: online,
    ),
  );
  if (choice == null || choice == SignOutChoice.cancel) return false;
  if (choice == SignOutChoice.syncFirst) {
    try {
      await ref.read(syncServiceProvider).syncNow();
    } on Object {
      // Sign out anyway: the user asked to.
    }
  }
  await ref.read(signOutProvider)();
  return true;
}

/// `SignOutDialog` (settings.md): simple confirm, or the pending-changes
/// variant; adds `signOutLocalOnlyBody` whenever device-local notes exist
/// (they are wiped). Cancel has the default focus; the destructive action
/// never does.
class SignOutDialog extends StatelessWidget {
  const SignOutDialog({
    super.key,
    required this.pendingCount,
    required this.localOnlyNotes,
    required this.online,
  });

  final int pendingCount;
  final int localOnlyNotes;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.paper;
    final pending = pendingCount > 0;
    return AlertDialog(
      title: Text(
        pending ? l10n.signOutPendingTitle : l10n.signOutConfirmTitle,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            pending
                ? l10n.signOutPendingBody(pendingCount)
                : l10n.signOutConfirmBody,
          ),
          if (localOnlyNotes > 0) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              l10n.signOutLocalOnlyBody(localOnlyNotes),
              key: const ValueKey<String>('signOut.localOnly'),
            ),
          ],
        ],
      ),
      actions: <Widget>[
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(SignOutChoice.cancel),
          child: Text(l10n.commonCancel),
        ),
        if (pending && online)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(SignOutChoice.syncFirst),
            child: Text(l10n.signOutSyncFirst),
          ),
        OutlinedButton(
          key: const ValueKey<String>('signOut.confirm'),
          style: OutlinedButton.styleFrom(
            foregroundColor: c.error,
            side: BorderSide(color: c.errorBorder),
          ),
          onPressed: () => Navigator.of(context).pop(SignOutChoice.signOut),
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
