import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/core_providers.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/paper_tokens.dart';

/// PLACEHOLDER (feature-screens agent): sign-in per
/// design/specs/screens/sign-in.md.
class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final configured = ref.watch(envProvider).isConfigured;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(PaperSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    l10n.signInScreenHeading,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: PaperSpacing.sm),
                  Text(l10n.signInTagline, textAlign: TextAlign.center),
                  const SizedBox(height: PaperSpacing.xl),
                  OutlinedButton.icon(
                    onPressed: configured ? () {} : null,
                    icon: SvgPicture.asset(
                      'assets/brand/icons/google_g.svg',
                      width: 18,
                      height: 18,
                      excludeFromSemantics: true,
                    ),
                    label: Text(l10n.signInGoogle),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
