import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app/routes.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/paper_tokens.dart';
import '../../theme/theme_x.dart';
import 'sign_in_screen.dart';

/// Online-only features a guest sees a "Sign in to use …" prompt for
/// (sign-in is optional; nothing hard-blocks).
enum GuestFeature { sync, explanation, glossary, importLink }

/// Opens the sign-in screen on top of the current route. It can be closed
/// (back / close button) and closes itself once signed in, so the user
/// lands where they were.
Future<void> openSignIn(BuildContext context) async {
  final router = GoRouter.maybeOf(context);
  if (router != null) {
    await router.push<void>(AppRoutes.signIn);
    return;
  }
  // Outside the app router (widget tests, dialogs on a bare navigator).
  await Navigator.of(
    context,
  ).push<void>(MaterialPageRoute<void>(builder: (_) => const SignInScreen()));
}

(IconData, String, String) _copy(AppLocalizations l10n, GuestFeature f) =>
    switch (f) {
      GuestFeature.sync => (
        Symbols.cloud_sync_rounded,
        l10n.guestSyncTitle,
        l10n.guestSyncBody,
      ),
      GuestFeature.explanation => (
        Symbols.auto_awesome_rounded,
        l10n.guestExplainTitle,
        l10n.guestExplainBody,
      ),
      GuestFeature.glossary => (
        Symbols.menu_book_rounded,
        l10n.guestGlossaryTitle,
        l10n.guestGlossaryBody,
      ),
      GuestFeature.importLink => (
        Symbols.link_rounded,
        l10n.guestImportLinkTitle,
        l10n.guestImportLinkBody,
      ),
    };

/// Calm inline "Sign in to use …" block (guest mode): icon, title, one line
/// on what still works, and a Sign in button. Replaces a panel tab body or
/// sits in a settings card. Not an error: no error colours.
class SignInPrompt extends StatelessWidget {
  const SignInPrompt({super.key, required this.feature, this.dense = false});

  static const Key buttonKey = Key('signInPrompt.button');

  final GuestFeature feature;

  /// Left-aligned, smaller variant for settings cards.
  final bool dense;

  static Key keyFor(GuestFeature feature) =>
      ValueKey<String>('signInPrompt.${feature.name}');

  @override
  Widget build(BuildContext context) {
    final c = context.paper;
    final t = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final (icon, title, body) = _copy(l10n, feature);
    final button = FilledButton.tonal(
      key: buttonKey,
      onPressed: () => unawaited(openSignIn(context)),
      child: Text(l10n.commonSignIn),
    );
    if (dense) {
      return Semantics(
        key: keyFor(feature),
        container: true,
        child: Padding(
          padding: const EdgeInsets.all(PaperSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, size: PaperIconSize.md, color: c.textSecondary),
              const SizedBox(width: PaperSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: t.titleSmall),
                    const SizedBox(height: PaperSpacing.xs),
                    Text(
                      body,
                      style: t.bodyMedium?.copyWith(color: c.textSecondary),
                    ),
                    const SizedBox(height: PaperSpacing.md),
                    button,
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(PaperSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Semantics(
            key: keyFor(feature),
            container: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: PaperIconSize.xl, color: c.textMuted),
                const SizedBox(height: PaperSpacing.md),
                Text(title, style: t.titleSmall, textAlign: TextAlign.center),
                const SizedBox(height: PaperSpacing.sm),
                Text(
                  body,
                  style: t.bodyMedium?.copyWith(color: c.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: PaperSpacing.lg),
                button,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The same prompt as a dialog, for actions (import by link, the citation
/// popover's Import). "Not now" closes it; "Sign in" opens sign-in.
Future<void> showSignInPromptDialog(
  BuildContext context,
  GuestFeature feature,
) async {
  final l10n = AppLocalizations.of(context);
  final (_, title, body) = _copy(l10n, feature);
  final signIn = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      key: SignInPrompt.keyFor(feature),
      title: Text(title),
      content: Text(body),
      actions: <Widget>[
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.guestNotNow),
        ),
        FilledButton(
          key: SignInPrompt.buttonKey,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.commonSignIn),
        ),
      ],
    ),
  );
  if (signIn == true && context.mounted) await openSignIn(context);
}
