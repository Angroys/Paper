import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/paper_tokens.dart';
import '../../ui/ui.dart';
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

(String, String) _copy(AppLocalizations l10n, GuestFeature f) => switch (f) {
  GuestFeature.sync => (l10n.guestSyncTitle, l10n.guestSyncBody),
  GuestFeature.explanation => (l10n.guestExplainTitle, l10n.guestExplainBody),
  GuestFeature.glossary => (l10n.guestGlossaryTitle, l10n.guestGlossaryBody),
  GuestFeature.importLink => (
    l10n.guestImportLinkTitle,
    l10n.guestImportLinkBody,
  ),
};

/// Calm inline "Sign in to use …" block (guest mode): title, one line on
/// what still works, and a primary Sign in button. Replaces a panel tab
/// body (`EmptyStateText` layout, centred) or sits in a settings card
/// ([dense], left-aligned). Not an error: no error colours, no icon.
class SignInPrompt extends StatelessWidget {
  const SignInPrompt({super.key, required this.feature, this.dense = false});

  static const Key buttonKey = Key('signInPrompt.button');

  final GuestFeature feature;

  /// Left-aligned variant for settings cards (no outer padding).
  final bool dense;

  static Key keyFor(GuestFeature feature) =>
      ValueKey<String>('signInPrompt.${feature.name}');

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final (title, body) = _copy(l10n, feature);
    final button = PaperButton.primary(
      key: buttonKey,
      label: l10n.commonSignIn,
      focusGap: PaperWeb.gray900,
      onPressed: () => unawaited(openSignIn(context)),
    );
    final align = dense ? TextAlign.start : TextAlign.center;
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: dense
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: <Widget>[
        Text(
          title,
          textAlign: align,
          style: dense
              ? t.labelLarge?.copyWith(color: PaperWeb.gray100)
              : PaperTypography.cardTitle(PaperColors.dark),
        ),
        const SizedBox(height: PaperSpacing.tw1),
        Text(
          body,
          textAlign: align,
          style: t.bodyMedium?.copyWith(color: PaperWeb.gray400),
        ),
        const SizedBox(height: PaperSpacing.tw4),
        button,
      ],
    );
    if (dense) {
      return Semantics(key: keyFor(feature), container: true, child: column);
    }
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: PaperSpacing.tw2,
          vertical: PaperSpacing.tw10,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Semantics(
            key: keyFor(feature),
            container: true,
            child: column,
          ),
        ),
      ),
    );
  }
}

/// The same prompt as a [PaperDialog], for actions (import by link, the
/// citation popover's Import). "Not now" closes it; "Sign in" opens
/// sign-in.
Future<void> showSignInPromptDialog(
  BuildContext context,
  GuestFeature feature,
) async {
  final l10n = AppLocalizations.of(context);
  final (title, body) = _copy(l10n, feature);
  final signIn = await showPaperDialog<bool>(
    context: context,
    builder: (context) => PaperDialog(
      key: SignInPrompt.keyFor(feature),
      title: title,
      body: body,
      actions: <Widget>[
        PaperButton.secondary(
          label: l10n.guestNotNow,
          autofocus: true,
          focusGap: PaperWeb.gray900,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        PaperButton.primary(
          key: SignInPrompt.buttonKey,
          label: l10n.commonSignIn,
          focusGap: PaperWeb.gray900,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
  if (signIn == true && context.mounted) await openSignIn(context);
}
