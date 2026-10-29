import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/routes.dart';
import '../../auth/auth_providers.dart';
import '../../core/core_providers.dart';
import '../../core/env.dart';
import '../../domain/domain.dart';
import '../../l10n/app_localizations.dart';
import '../../core/immersive.dart';
import '../../theme/paper_tokens.dart';
import '../../ui/ui.dart';

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

/// Alert-row message (sign-in.md §1.1 2e): [error] = `sm red-400`
/// (`role=alert`), otherwise a `sm gray-300` notice.
class _Banner {
  const _Banner(this.text, {this.error = true});
  final String text;
  final bool error;
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
  static const Key modeToggleKey = Key('signIn.modeToggle');

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
        () => _banner = _Banner(_l10n.authResetSent(email), error: false),
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

  TextStyle? _sm(Color color) =>
      Theme.of(context).textTheme.bodyMedium?.copyWith(color: color);

  TextStyle? _xs(Color color) =>
      Theme.of(context).textTheme.bodySmall?.copyWith(color: color);

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;
    // Unconfigured builds get an auth repository that is always
    // notConfigured (lib/auth/auth_providers.dart).
    final configured =
        ref.watch(authRepositoryProvider).currentState.status !=
        AuthStatus.notConfigured;
    final online = ref.watch(isOnlineProvider).value ?? true;
    final bp = WebBreakpoint.of(context);
    final pad = MediaQuery.viewPaddingOf(context);
    final vertical = bp.isSmUp ? PaperSpacing.tw24 : PaperSpacing.tw16;

    final Widget body;
    if (!configured) {
      body = _PlaceholderCard(title: l10n.authNotConfigured);
    } else if (!online) {
      body = _PlaceholderCard(
        title: l10n.authOfflineTitle,
        body: l10n.authOfflineBody,
        action: PaperButton.secondary(
          label: l10n.authRetry,
          focusGap: PaperWeb.gray900,
          onPressed: () => ref.invalidate(isOnlineProvider),
        ),
      );
    } else {
      body = switch (_mode) {
        _Mode.form => _buildForm(context, bp),
        _Mode.browserWait => _buildWait(context),
        _Mode.checkEmail => _buildCheckEmail(context),
      };
    }

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            _signUp ? l10n.signUpSubmit : l10n.signInSubmit,
            style: PaperTypography.pageTitle(PaperColors.dark),
          ),
        ),
        if (widget.sessionExpired) ...<Widget>[
          const SizedBox(height: PaperSpacing.tw2),
          Text(l10n.authSessionExpired, style: _sm(PaperWeb.gray400)),
        ],
        const SizedBox(height: PaperSpacing.tw8),
        body,
        const SizedBox(height: PaperSpacing.tw6),
        _LegalFooter(),
      ],
    );

    return Scaffold(
      backgroundColor: PaperWeb.gray950,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: SingleChildScrollView(
              padding: SafeViewPadding.resolve(
                context,
                base: EdgeInsets.fromLTRB(
                  PaperSpacing.tw6,
                  vertical,
                  PaperSpacing.tw6,
                  vertical,
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  // `max-w-sm` 384 box with `px-6`: a 336 column.
                  constraints: const BoxConstraints(maxWidth: 336),
                  child: AutofillGroup(child: column),
                ),
              ),
            ),
          ),
          // Sign-in is optional: it can always be dismissed (also with the
          // system back gesture).
          Positioned(
            top: PaperSpacing.tw4 + pad.top,
            left: PaperSpacing.tw4 + pad.left,
            child: PaperIconButton(
              key: SignInScreen.closeKey,
              tooltip: l10n.signInCloseTooltip,
              onPressed: _close,
              icon: const PaperIcon(PaperIcons.readerBack, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  /// The alert row (2e): field errors, then auth errors / notices.
  Widget? _alertRow() {
    final field = _emailError ?? _passwordError;
    final banner = field != null ? _Banner(field) : _banner;
    if (banner == null) return null;
    return Semantics(
      key: SignInScreen.bannerKey,
      liveRegion: true,
      child: Text(
        banner.text,
        style: _sm(banner.error ? PaperWeb.red400 : PaperWeb.gray300),
      ),
    );
  }

  Widget _buildForm(BuildContext context, WebBreakpoint bp) {
    final l10n = _l10n;
    final submitting = _busy;
    final fieldSize = bp.isSmUp
        ? PaperTextFieldSize.md
        : PaperTextFieldSize.mdBase;
    final alert = _alertRow();
    final children = <Widget>[
      PaperTextField(
        fieldKey: SignInScreen.emailFieldKey,
        controller: _email,
        focusNode: _emailFocus,
        label: l10n.signInEmailLabel,
        size: fieldSize,
        autofocus: _desktop,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const <String>[AutofillHints.email],
        textInputAction: TextInputAction.next,
        autocorrect: false,
        onChanged: (_) {
          if (_emailError != null) setState(() => _emailError = null);
        },
        onSubmitted: (_) => _passwordFocus.requestFocus(),
      ),
      const SizedBox(height: PaperSpacing.tw5),
      PaperTextField(
        fieldKey: SignInScreen.passwordFieldKey,
        controller: _password,
        focusNode: _passwordFocus,
        label: l10n.signInPasswordLabel,
        size: fieldSize,
        obscureText: !_showPassword,
        autocorrect: false,
        autofillHints: <String>[
          _signUp ? AutofillHints.newPassword : AutofillHints.password,
        ],
        onChanged: (_) {
          if (_passwordError != null) setState(() => _passwordError = null);
        },
        onSubmitted: (_) {
          if (!submitting) unawaited(_submit());
        },
        suffix: PaperIconButton(
          size: PaperIconButtonSize.s24,
          tooltip: _showPassword
              ? l10n.authHidePassword
              : l10n.authShowPassword,
          focusGap: PaperWeb.gray900,
          onPressed: () => setState(() => _showPassword = !_showPassword),
          icon: PaperIcon(_showPassword ? PaperIcons.eyeOff : PaperIcons.eye),
        ),
      ),
      if (alert != null) ...<Widget>[
        const SizedBox(height: PaperSpacing.tw5),
        alert,
      ],
      const SizedBox(height: PaperSpacing.tw5),
      PaperButton.primary(
        key: SignInScreen.submitKey,
        expand: true,
        label: submitting
            ? l10n.authSigningIn
            : (_signUp ? l10n.signUpSubmit : l10n.signInSubmit),
        onPressed: submitting ? null : () => unawaited(_submit()),
      ),
      if (!_signUp) ...<Widget>[
        const SizedBox(height: PaperSpacing.tw5),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          runSpacing: PaperSpacing.tw2,
          children: <Widget>[
            PaperLink.muted(
              label: l10n.signInForgotPassword,
              onPressed: submitting ? null : () => unawaited(_forgotPassword()),
            ),
            PaperLink.muted(
              label: l10n.signInMagicLink,
              onPressed: submitting ? null : () => unawaited(_magicLink()),
            ),
          ],
        ),
      ],
      const SizedBox(height: PaperSpacing.tw4),
      PaperButton.secondary(
        key: SignInScreen.googleButtonKey,
        expand: true,
        label: l10n.signInGoogle,
        onPressed: submitting ? null : () => unawaited(_google()),
      ),
      const SizedBox(height: PaperSpacing.tw6),
      Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Text(
            '${_signUp ? l10n.signInHaveAccountLead : l10n.signInCreateAccountLead} ',
            style: _sm(PaperWeb.gray400),
          ),
          PaperLink.strong(
            key: SignInScreen.modeToggleKey,
            label: _signUp
                ? l10n.signInHaveAccountAction
                : l10n.signInCreateAccountAction,
            onPressed: submitting
                ? null
                : () => setState(() {
                    _signUp = !_signUp;
                    _passwordError = null;
                    _banner = null;
                  }),
          ),
        ],
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _buildWait(BuildContext context) {
    final l10n = _l10n;
    // Desktop only: the browser may be unable to hand the link back.
    final missing = _deepLinkMissing && _desktop;
    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const PaperSpinner(),
              const SizedBox(width: PaperSpacing.tw2),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    l10n.authBrowserWaitTitle,
                    style: PaperTypography.cardTitle(PaperColors.dark),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: PaperSpacing.tw2),
          Text(l10n.authBrowserWaitBody, style: _sm(PaperWeb.gray400)),
          const SizedBox(height: PaperSpacing.tw4),
          Wrap(
            spacing: PaperSpacing.tw3,
            runSpacing: PaperSpacing.tw2,
            children: <Widget>[
              PaperButton.secondary(
                label: l10n.authReopenBrowser,
                focusGap: PaperWeb.gray900,
                onPressed: _busy ? null : () => unawaited(_google()),
              ),
              PaperButton.ghost(
                label: l10n.authCancel,
                focusGap: PaperWeb.gray900,
                onPressed: _cancelWait,
              ),
            ],
          ),
          if (_returnHint || missing) ...<Widget>[
            const SizedBox(height: PaperSpacing.tw3),
            Text(
              missing
                  ? l10n.authDeepLinkMissingHint
                  : l10n.authBrowserReturnHint,
              style: _xs(PaperWeb.gray400),
            ),
            const SizedBox(height: PaperSpacing.tw1),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: PaperLink(
                label: l10n.authUseEmailInstead,
                fontSize: 12,
                onPressed: _cancelWait,
              ),
            ),
          ],
          if (missing) ...<Widget>[
            const SizedBox(height: PaperSpacing.tw4),
            PaperTextField(
              fieldKey: SignInScreen.pasteLinkFieldKey,
              controller: _pasteLink,
              label: l10n.authPasteLinkLabel,
              hintText: '${Env.authCallbackUrl}?code=…',
              keyboardType: TextInputType.url,
              autocorrect: false,
              onSubmitted: (_) => unawaited(_submitPastedLink()),
            ),
            if (_pasteError != null) ...<Widget>[
              const SizedBox(height: PaperSpacing.tw1_5),
              Semantics(
                liveRegion: true,
                child: Text(_pasteError!, style: _xs(PaperWeb.red400)),
              ),
            ],
            const SizedBox(height: PaperSpacing.tw3),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: PaperButton.primary(
                key: SignInScreen.pasteLinkSubmitKey,
                label: l10n.commonContinue,
                focusGap: PaperWeb.gray900,
                onPressed: () => unawaited(_submitPastedLink()),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCheckEmail(BuildContext context) {
    final l10n = _l10n;
    final email = _email.text.trim();
    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            liveRegion: true,
            child: Text(
              _confirmEmail
                  ? l10n.authConfirmEmailTitle
                  : l10n.authCheckEmailTitle,
              style: PaperTypography.cardTitle(PaperColors.dark),
            ),
          ),
          const SizedBox(height: PaperSpacing.tw2),
          Text(l10n.authCheckEmailBody(email), style: _sm(PaperWeb.gray400)),
          if (_banner != null) ...<Widget>[
            const SizedBox(height: PaperSpacing.tw3),
            ?_alertRow(),
          ],
          const SizedBox(height: PaperSpacing.tw4),
          Wrap(
            spacing: PaperSpacing.tw3,
            runSpacing: PaperSpacing.tw2,
            children: <Widget>[
              PaperButton.secondary(
                label: _cooldown > 0
                    ? l10n.authResendCooldown(_cooldown)
                    : l10n.authResend,
                focusGap: PaperWeb.gray900,
                onPressed: _cooldown > 0 || _busy
                    ? null
                    : () => unawaited(_resend()),
              ),
              PaperButton.ghost(
                label: l10n.authUseAnotherEmail,
                focusGap: PaperWeb.gray900,
                onPressed: () {
                  _cooldownTimer?.cancel();
                  setState(() {
                    _mode = _Mode.form;
                    _cooldown = 0;
                    _banner = null;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// `PlaceholderCard` (components.md §17): offline / not configured.
class _PlaceholderCard extends StatelessWidget {
  const _PlaceholderCard({required this.title, this.body, this.action});

  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Semantics(
      key: SignInScreen.bannerKey,
      liveRegion: true,
      child: PaperCard(
        padding: const EdgeInsets.all(PaperSpacing.tw6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: t.labelLarge?.copyWith(color: PaperWeb.gray100)),
            if (body != null) ...<Widget>[
              const SizedBox(height: PaperSpacing.tw1),
              Text(
                body!,
                style: t.bodyMedium?.copyWith(color: PaperWeb.gray300),
              ),
            ],
            if (action != null) ...<Widget>[
              const SizedBox(height: PaperSpacing.tw4),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// App-only legal footer: "Terms · Privacy Policy", `xs gray-400`.
class _LegalFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Future<void> open(String path) => launchUrl(
      Uri.parse('${Env.defaultPaperApiBaseUrl}$path'),
      mode: LaunchMode.externalApplication,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        PaperLink.muted(
          label: l10n.signInTerms,
          fontSize: 12,
          onPressed: () => unawaited(open('/terms')),
        ),
        const SizedBox(width: PaperSpacing.tw2),
        ExcludeSemantics(
          child: Text(
            '·',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: PaperWeb.gray400),
          ),
        ),
        const SizedBox(width: PaperSpacing.tw2),
        PaperLink.muted(
          label: l10n.signInPrivacy,
          fontSize: 12,
          onPressed: () => unawaited(open('/privacy')),
        ),
      ],
    );
  }
}
