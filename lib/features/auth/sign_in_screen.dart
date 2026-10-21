import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/routes.dart';
import '../../auth/auth_providers.dart';
import '../../core/core_providers.dart';
import '../../core/env.dart';
import '../../domain/domain.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/paper_tokens.dart';
import '../../theme/theme_x.dart';

/// App version shown in the sign-in footer (`--dart-define=APP_VERSION`).
const String kAppVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: '1.0.0',
);

/// How long after the app regains focus, with no callback, before
/// `authBrowserReturnHint` shows (flows F2a).
const Duration kBrowserReturnHintDelay = Duration(seconds: 2);

/// How long the browser wait lasts before desktop builds offer the
/// "paste the link" fallback (`authDeepLinkMissingHint`, flows F2a).
const Duration kDeepLinkMissingDelay = Duration(seconds: 30);

/// Resend cooldown for the magic link / confirmation email.
const int kResendCooldownSeconds = 60;

enum _Mode { form, browserWait, checkEmail }

/// Status-region message. [error] = AuthErrorBanner; otherwise an info /
/// offline banner.
class _Banner {
  const _Banner(this.text, {this.error = true, this.icon});
  final String text;
  final bool error;
  final IconData? icon;
}

/// Sign-in (screens/sign-in.md, flows F2): Google via the system browser,
/// email + password (sign in / create account), magic link, forgot
/// password, the browser-wait state with a desktop "paste the link"
/// fallback, and offline / not-configured / error states.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key, this.sessionExpired = false});

  /// Opened after the session expired (`authSessionExpired` banner).
  final bool sessionExpired;

  static const Key googleButtonKey = Key('signIn.google');
  static const Key emailFieldKey = Key('signIn.email');
  static const Key passwordFieldKey = Key('signIn.password');
  static const Key submitKey = Key('signIn.submit');
  static const Key pasteLinkFieldKey = Key('signIn.pasteLink');
  static const Key pasteLinkSubmitKey = Key('signIn.pasteLinkSubmit');
  static const Key bannerKey = Key('signIn.banner');
  static const Key closeKey = Key('signIn.close');

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _pasteLink = TextEditingController();
  final _passwordFocus = FocusNode();
  final _emailFocus = FocusNode();

  _Mode _mode = _Mode.form;
  bool _signUp = false;
  bool _showPassword = false;
  bool _busy = false;
  _Banner? _banner;
  String? _emailError;
  String? _passwordError;
  String? _pasteError;

  // Browser wait.
  bool _returnHint = false;
  bool _deepLinkMissing = false;
  Timer? _returnTimer;
  Timer? _missingTimer;
  AppLifecycleListener? _lifecycle;

  // Check email.
  bool _confirmEmail = false;
  int _cooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(() {
      if (!_emailFocus.hasFocus) _validateEmailOnBlur();
    });
    if (widget.sessionExpired) {
      _banner = const _Banner('');
    }
    // Sign-in is optional and pushed on top of where the user was: once
    // signed in (form, Google return or magic link), go back there.
    ref.listenManual<AsyncValue<AuthState>>(authStateProvider, (prev, next) {
      final was = prev?.value?.isSignedIn ?? false;
      if (!was && (next.value?.isSignedIn ?? false)) _close();
    });
    ref.listenManual<AsyncValue<AuthFailedException>>(authErrorsProvider, (
      _,
      next,
    ) {
      final e = next.value;
      if (e == null || !mounted) return;
      _leaveWait();
      setState(() => _banner = _Banner(_authFailureText(e, google: true)));
    });
  }

  @override
  void dispose() {
    _leaveWait();
    _cooldownTimer?.cancel();
    _email.dispose();
    _password.dispose();
    _pasteLink.dispose();
    _passwordFocus.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  AppLocalizations get _l10n => AppLocalizations.of(context);

  /// Leaves sign-in: back to the previous route, or the library when the
  /// screen was opened directly (e.g. a restored `/sign-in` location).
  void _close() {
    if (!mounted) return;
    _leaveWait();
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    GoRouter.maybeOf(context)?.go(AppRoutes.library);
  }

  bool get _desktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  bool _validEmail(String v) => _emailPattern.hasMatch(v.trim());

  void _validateEmailOnBlur() {
    final v = _email.text.trim();
    setState(() {
      _emailError = v.isEmpty || _validEmail(v) ? null : _l10n.authEmailInvalid;
    });
  }

  String _authFailureText(AuthFailedException e, {bool google = false}) =>
      switch (e.reason) {
        AuthFailureReason.cancelled => _l10n.authGoogleCancelled,
        AuthFailureReason.invalidCredentials => _l10n.authInvalidCredentials,
        AuthFailureReason.emailNotConfirmed => _l10n.authConfirmEmailTitle,
        AuthFailureReason.rateLimited => _l10n.authRateLimited(
          kResendCooldownSeconds,
        ),
        AuthFailureReason.exchangeFailed => _l10n.authCodeExchangeFailed,
        AuthFailureReason.unknown =>
          google ? _l10n.authGoogleFailed : _l10n.errorGeneric,
      };

  void _announce(String text) {
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        text,
        Directionality.of(context),
      ),
    );
  }

  /// Runs an auth action with the shared error mapping.
  Future<bool> _run(
    Future<void> Function() action, {
    bool google = false,
  }) async {
    setState(() {
      _busy = true;
      _banner = null;
      _passwordError = null;
    });
    try {
      await action();
      return true;
    } on AuthFailedException catch (e) {
      if (!mounted) return false;
      if (e.reason == AuthFailureReason.invalidCredentials) {
        setState(() => _passwordError = _l10n.authInvalidCredentials);
        _passwordFocus.requestFocus();
      } else if (e.reason == AuthFailureReason.emailNotConfirmed) {
        _enterCheckEmail(confirm: true);
      } else {
        setState(() => _banner = _Banner(_authFailureText(e, google: google)));
      }
    } on OfflineException {
      if (mounted) setState(() => _banner = _Banner(_l10n.authNetworkError));
    } on NotConfiguredException {
      if (mounted) setState(() => _banner = _Banner(_l10n.authNotConfigured));
    } on Object {
      if (mounted) {
        setState(
          () => _banner = _Banner(
            google ? _l10n.authGoogleFailed : _l10n.errorGeneric,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    return false;
  }

  // ---------------------------------------------------------------- Google

  Future<void> _google() async {
    final repo = ref.read(authRepositoryProvider);
    final ok = await _run(repo.signInWithGoogle, google: true);
    if (ok && mounted) _enterWait();
  }

  void _enterWait() {
    setState(() {
      _mode = _Mode.browserWait;
      _returnHint = false;
      _deepLinkMissing = false;
      _pasteError = null;
    });
    _announce(_l10n.authBrowserWaitTitle);
    _lifecycle?.dispose();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        _returnTimer?.cancel();
        _returnTimer = Timer(kBrowserReturnHintDelay, () {
          if (mounted && _mode == _Mode.browserWait) {
            setState(() => _returnHint = true);
          }
        });
      },
    );
    _missingTimer?.cancel();
    _missingTimer = Timer(kDeepLinkMissingDelay, () {
      if (mounted && _mode == _Mode.browserWait) {
        setState(() => _deepLinkMissing = true);
      }
    });
  }

  void _leaveWait() {
    _returnTimer?.cancel();
    _missingTimer?.cancel();
    _lifecycle?.dispose();
    _lifecycle = null;
  }

  void _cancelWait() {
    _leaveWait();
    setState(() => _mode = _Mode.form);
  }

  /// Desktop fallback: the user pastes the `paper://auth-callback?...` link
  /// the browser could not hand to the app.
  Future<void> _submitPastedLink() async {
    final raw = _pasteLink.text.trim();
    final uri = Uri.tryParse(raw);
    final target = uri == null ? null : DeepLinkTarget.parse(uri);
    if (target is! AuthCallbackLink) {
      setState(() => _pasteError = _l10n.authPasteLinkInvalid);
      return;
    }
    setState(() => _pasteError = null);
    final handled = await ref
        .read(authRepositoryProvider)
        .handleAuthCallback(target.uri);
    if (!mounted) return;
    if (!handled) setState(() => _pasteError = _l10n.authPasteLinkInvalid);
  }

  // ----------------------------------------------------------------- Email

  bool get _canSubmit =>
      !_busy && _email.text.trim().isNotEmpty && _password.text.isNotEmpty;

  Future<void> _submit() async {
    if (!_validEmail(_email.text)) {
      setState(() => _emailError = _l10n.authEmailInvalid);
      return;
    }
    if (_password.text.isEmpty) {
      setState(() => _passwordError = _l10n.authPasswordRequired);
      return;
    }
    final repo = ref.read(authRepositoryProvider);
    final email = _email.text.trim();
    final password = _password.text;
    if (_signUp) {
      var needsConfirm = false;
      final ok = await _run(() async {
        needsConfirm = await repo.signUpWithEmailPassword(
          email: email,
          password: password,
        );
      });
      if (ok && needsConfirm && mounted) _enterCheckEmail(confirm: false);
    } else {
      await _run(
        () => repo.signInWithEmailPassword(email: email, password: password),
      );
    }
  }

  Future<void> _magicLink() async {
    if (!_validEmail(_email.text)) {
      setState(() => _emailError = _l10n.authEmailInvalid);
      _emailFocus.requestFocus();
      return;
    }
    final repo = ref.read(authRepositoryProvider);
    final ok = await _run(() => repo.sendMagicLink(_email.text.trim()));
    if (ok && mounted) _enterCheckEmail(confirm: false);
  }

  Future<void> _forgotPassword() async {
    if (!_validEmail(_email.text)) {
      setState(() => _emailError = _l10n.authEmailInvalid);
      _emailFocus.requestFocus();
      return;
    }
    final email = _email.text.trim();
    final repo = ref.read(authRepositoryProvider);
    final ok = await _run(() => repo.sendPasswordReset(email));
    if (ok && mounted) {
      setState(
        () => _banner = _Banner(
          _l10n.authResetSent(email),
          error: false,
          icon: Symbols.mail_rounded,
        ),
      );
    }
  }

  void _enterCheckEmail({required bool confirm}) {
    setState(() {
      _mode = _Mode.checkEmail;
      _confirmEmail = confirm;
    });
    _startCooldown();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = kResendCooldownSeconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _resend() async {
    final repo = ref.read(authRepositoryProvider);
    final ok = await _run(() => repo.sendMagicLink(_email.text.trim()));
    if (ok && mounted) _startCooldown();
  }

  // ----------------------------------------------------------------- Build

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;
    final c = context.paper;
    // Unconfigured builds get an auth repository that is always
    // notConfigured (lib/auth/auth_providers.dart).
    final configured =
        ref.watch(authRepositoryProvider).currentState.status !=
        AuthStatus.notConfigured;
    final online = ref.watch(isOnlineProvider).value ?? true;
    final disabled = !configured || !online || _busy;

    // Status region (live): not configured > offline > error / info.
    _Banner? banner;
    if (!configured) {
      banner = _Banner(
        l10n.authNotConfigured,
        error: false,
        icon: Symbols.cloud_off_rounded,
      );
    } else if (!online) {
      banner = _Banner(
        '${l10n.authOfflineTitle}. ${l10n.authOfflineBody}',
        error: false,
        icon: Symbols.cloud_off_rounded,
      );
    } else if (_banner != null) {
      banner = _banner!.text.isEmpty
          ? _Banner(l10n.authSessionExpired)
          : _banner;
    }

    final Widget stateBody = switch (_mode) {
      _Mode.form => _buildForm(context, disabled: disabled),
      _Mode.browserWait => _buildWait(context),
      _Mode.checkEmail => _buildCheckEmail(context),
    };

    final form = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            SvgPicture.asset(
              'assets/brand/splash/splash-logo.svg',
              width: 32,
              height: 32,
              semanticsLabel: l10n.a11yAppLogo,
            ),
            const SizedBox(width: PaperSpacing.sm),
            Text(
              l10n.appName,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: PaperSpacing.xl),
        Semantics(
          header: true,
          child: Text(
            l10n.signInScreenHeading,
            style: Theme.of(context).textTheme.headlineLarge,
          ),
        ),
        const SizedBox(height: PaperSpacing.xs),
        Text(
          l10n.signInTagline,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: PaperSpacing.xl),
        AnimatedSwitcher(
          duration: PaperMotion.fade(context, PaperMotion.fast),
          child: banner == null
              ? const SizedBox.shrink()
              : Padding(
                  key: ValueKey<String>(banner.text),
                  padding: const EdgeInsets.only(bottom: PaperSpacing.lg),
                  child: _StatusBanner(banner: banner),
                ),
        ),
        AnimatedSwitcher(
          duration: PaperMotion.fade(context, PaperMotion.base),
          switchInCurve: PaperMotion.standard,
          switchOutCurve: PaperMotion.standard,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: <Widget>[...previous, ?current],
          ),
          child: KeyedSubtree(key: ValueKey<_Mode>(_mode), child: stateBody),
        ),
        const SizedBox(height: PaperSpacing.xl),
        _Footer(),
      ],
    );

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            Positioned.fill(child: _layout(form)),
            // Sign-in is optional: it can always be dismissed (also with
            // the system back gesture).
            Positioned(
              top: PaperSpacing.sm,
              left: PaperSpacing.sm,
              child: IconButton(
                key: SignInScreen.closeKey,
                tooltip: l10n.signInCloseTooltip,
                onPressed: _close,
                icon: const Icon(Symbols.close_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _layout(Widget form) => LayoutBuilder(
    builder: (context, constraints) {
      final wc = PaperWindowClass.of(constraints.maxWidth);
      final column = Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(PaperSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: AutofillGroup(child: form),
          ),
        ),
      );
      final showBrand =
          wc.index >= PaperWindowClass.expanded.index &&
          constraints.maxHeight >= 560;
      if (!showBrand) return column;
      return Padding(
        padding: EdgeInsets.all(PaperSpacing.margin(wc)),
        child: Row(
          children: <Widget>[
            Expanded(
              flex: wc == PaperWindowClass.extraLarge ? 6 : 5,
              child: const _BrandPanel(),
            ),
            SizedBox(width: PaperSpacing.gutter(wc)),
            Expanded(
              flex: wc == PaperWindowClass.extraLarge ? 6 : 7,
              child: column,
            ),
          ],
        ),
      );
    },
  );

  Widget _buildForm(BuildContext context, {required bool disabled}) {
    final l10n = _l10n;
    final c = context.paper;
    final submitting = _busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            key: SignInScreen.googleButtonKey,
            onPressed: disabled ? null : () => unawaited(_google()),
            style: OutlinedButton.styleFrom(
              backgroundColor: c.surface,
              foregroundColor: c.textPrimary,
              side: BorderSide(color: c.outline),
            ),
            icon: SvgPicture.asset(
              'assets/brand/icons/google_g.svg',
              width: 20,
              height: 20,
              excludeFromSemantics: true,
            ),
            label: Text(l10n.signInGoogle),
          ),
        ),
        const SizedBox(height: PaperSpacing.lg),
        Row(
          children: <Widget>[
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: PaperSpacing.md),
              child: Text(
                l10n.signInDividerOr,
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: c.textMuted),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: PaperSpacing.lg),
        _Label(l10n.signInEmailLabel),
        TextField(
          key: SignInScreen.emailFieldKey,
          controller: _email,
          focusNode: _emailFocus,
          readOnly: submitting,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const <String>[AutofillHints.email],
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() {
            if (_emailError != null) _emailError = null;
          }),
          onSubmitted: (_) => _passwordFocus.requestFocus(),
          decoration: InputDecoration(errorText: _emailError),
        ),
        const SizedBox(height: PaperSpacing.md),
        _Label(l10n.signInPasswordLabel),
        TextField(
          key: SignInScreen.passwordFieldKey,
          controller: _password,
          focusNode: _passwordFocus,
          readOnly: submitting,
          obscureText: !_showPassword,
          autofillHints: <String>[
            _signUp ? AutofillHints.newPassword : AutofillHints.password,
          ],
          onChanged: (_) => setState(() {
            if (_passwordError != null) _passwordError = null;
          }),
          onSubmitted: (_) {
            if (_canSubmit && !disabled) unawaited(_submit());
          },
          decoration: InputDecoration(
            errorText: _passwordError,
            suffixIcon: IconButton(
              tooltip: _showPassword
                  ? l10n.authHidePassword
                  : l10n.authShowPassword,
              onPressed: () => setState(() => _showPassword = !_showPassword),
              icon: Icon(
                _showPassword
                    ? Symbols.visibility_off_rounded
                    : Symbols.visibility_rounded,
                size: 20,
              ),
            ),
          ),
        ),
        const SizedBox(height: PaperSpacing.lg),
        SizedBox(
          height: 48,
          child: FilledButton(
            key: SignInScreen.submitKey,
            onPressed: disabled || !_canSubmit
                ? null
                : () => unawaited(_submit()),
            child: submitting
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: PaperSpacing.sm),
                      Text(l10n.authSigningIn),
                    ],
                  )
                : Text(_signUp ? l10n.signUpSubmit : l10n.signInSubmit),
          ),
        ),
        const SizedBox(height: PaperSpacing.sm),
        Wrap(
          children: <Widget>[
            if (!_signUp)
              TextButton(
                onPressed: disabled ? null : () => unawaited(_forgotPassword()),
                child: Text(l10n.signInForgotPassword),
              ),
            TextButton(
              onPressed: disabled ? null : () => unawaited(_magicLink()),
              child: Text(l10n.signInMagicLink),
            ),
          ],
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: _busy
                ? null
                : () => setState(() {
                    _signUp = !_signUp;
                    _passwordError = null;
                  }),
            child: Text(
              _signUp
                  ? l10n.signInHaveAccountPrompt
                  : l10n.signInCreateAccountPrompt,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWait(BuildContext context) {
    final l10n = _l10n;
    final c = context.paper;
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(
          child: Semantics(
            label: l10n.authBrowserWaitTitle,
            child: const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ),
        ),
        const SizedBox(height: PaperSpacing.lg),
        Text(
          l10n.authBrowserWaitTitle,
          style: t.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: PaperSpacing.sm),
        Text(
          l10n.authBrowserWaitBody,
          style: t.bodyMedium?.copyWith(color: c.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: PaperSpacing.lg),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: PaperSpacing.sm,
          children: <Widget>[
            OutlinedButton(
              onPressed: _busy ? null : () => unawaited(_google()),
              child: Text(l10n.authReopenBrowser),
            ),
            TextButton(onPressed: _cancelWait, child: Text(l10n.authCancel)),
          ],
        ),
        if (_returnHint && !_deepLinkMissing) ...<Widget>[
          const SizedBox(height: PaperSpacing.md),
          Text(
            l10n.authBrowserReturnHint,
            textAlign: TextAlign.center,
            style: t.bodySmall?.copyWith(color: c.textSecondary),
          ),
        ],
        if (_deepLinkMissing && _desktop) ...<Widget>[
          const SizedBox(height: PaperSpacing.lg),
          Text(
            l10n.authDeepLinkMissingHint,
            style: t.bodySmall?.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: PaperSpacing.md),
          _Label(l10n.authPasteLinkLabel),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: TextField(
                  key: SignInScreen.pasteLinkFieldKey,
                  controller: _pasteLink,
                  keyboardType: TextInputType.url,
                  onSubmitted: (_) => unawaited(_submitPastedLink()),
                  decoration: InputDecoration(
                    hintText: '${Env.authCallbackUrl}?code=…',
                    errorText: _pasteError,
                    errorMaxLines: 3,
                  ),
                ),
              ),
              const SizedBox(width: PaperSpacing.sm),
              FilledButton(
                key: SignInScreen.pasteLinkSubmitKey,
                onPressed: () => unawaited(_submitPastedLink()),
                child: Text(l10n.commonContinue),
              ),
            ],
          ),
          const SizedBox(height: PaperSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: _cancelWait,
              child: Text(l10n.authUseEmailInstead),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCheckEmail(BuildContext context) {
    final l10n = _l10n;
    final c = context.paper;
    final t = Theme.of(context).textTheme;
    final email = _email.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: c.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(Symbols.mail_rounded, size: 32, color: c.primary),
          ),
        ),
        const SizedBox(height: PaperSpacing.lg),
        Text(
          _confirmEmail ? l10n.authConfirmEmailTitle : l10n.authCheckEmailTitle,
          style: t.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: PaperSpacing.sm),
        Text(
          l10n.authCheckEmailBody(email),
          style: t.bodyMedium?.copyWith(color: c.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: PaperSpacing.lg),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: PaperSpacing.sm,
          children: <Widget>[
            OutlinedButton(
              onPressed: _cooldown > 0 || _busy
                  ? null
                  : () => unawaited(_resend()),
              child: Text(
                _cooldown > 0
                    ? l10n.authResendCooldown(_cooldown)
                    : l10n.authResend,
              ),
            ),
            TextButton(
              onPressed: () {
                _cooldownTimer?.cancel();
                setState(() {
                  _mode = _Mode.form;
                  _cooldown = 0;
                });
              },
              child: Text(l10n.authUseAnotherEmail),
            ),
          ],
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: PaperSpacing.sm),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelLarge
          ?.copyWith(color: context.paper.textPrimary),
    ),
  );
}

/// `AuthErrorBanner` (error) / `OfflineBanner` (info): live region.
class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.banner});

  final _Banner banner;

  @override
  Widget build(BuildContext context) {
    final c = context.paper;
    final error = banner.error;
    return Semantics(
      key: SignInScreen.bannerKey,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: PaperSpacing.md,
          vertical: PaperSpacing.md,
        ),
        decoration: BoxDecoration(
          color: error ? c.errorSurface : c.surfaceVariant,
          border: Border.all(color: error ? c.errorBorder : c.border),
          borderRadius: PaperRadii.borderLg,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              banner.icon ?? Symbols.error_rounded,
              size: PaperIconSize.md,
              color: error ? c.error : c.textSecondary,
            ),
            const SizedBox(width: PaperSpacing.sm),
            Expanded(
              child: Text(
                banner.text,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: error ? c.onErrorSurface : c.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    final c = context.paper;
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: PaperRadii.borderXl,
      ),
      padding: const EdgeInsets.all(PaperSpacing.xxl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: c.pdfPage,
                borderRadius: PaperRadii.borderSm,
              ),
              child: Padding(
                padding: const EdgeInsets.all(PaperSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (var i = 0; i < 9; i++) ...<Widget>[
                      FractionallySizedBox(
                        widthFactor: i == 8 ? 0.5 : 1,
                        child: Container(
                          height: 8,
                          color: i == 3
                              ? PaperHighlightColor.blue.wash.withValues(
                                  alpha: 0.5,
                                )
                              : const Color(0xFFE5E5E5),
                        ),
                      ),
                      const SizedBox(height: PaperSpacing.md),
                    ],
                    const Spacer(),
                    Semantics(
                      excludeSemantics: true,
                      child: Text(
                        l10n.appName,
                        style: const TextStyle(
                          color: Color(0xFF737373),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.paper;
    final small = Theme.of(context).textTheme.bodySmall;
    Future<void> open(String path) => launchUrl(
      Uri.parse('${Env.defaultPaperApiBaseUrl}$path'),
      mode: LaunchMode.externalApplication,
    );
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        TextButton(
          onPressed: () => unawaited(open('/terms')),
          child: Text(l10n.signInTerms, style: small),
        ),
        Text('·', style: small?.copyWith(color: c.textMuted)),
        TextButton(
          onPressed: () => unawaited(open('/privacy')),
          child: Text(l10n.signInPrivacy, style: small),
        ),
        const SizedBox(width: PaperSpacing.md),
        Text(
          l10n.aboutVersion(kAppVersion),
          style: small?.copyWith(color: c.textMuted),
        ),
      ],
    );
  }
}
