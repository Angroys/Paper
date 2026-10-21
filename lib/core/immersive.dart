import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Android sticky-immersive full screen (design/web-parity/screens/README.md
/// §4). Status and navigation bars stay hidden on every screen; an edge swipe
/// reveals them transiently and the OS auto-hides them again.
///
/// The mode is (re-)applied:
/// - once by [install] (call it from `main()` before `runApp`);
/// - on every [AppLifecycleState.resumed] (back from the file picker, OAuth
///   browser, share sheet, permission dialog ...);
/// - from [SystemChrome.setSystemUIChangeCallback] when the bars became
///   visible, after [revealDelay] so a deliberate peek isn't cut short;
/// - after the IME closes (view inset bottom back to 0), after [imeDelay] so
///   the close animation finishes first.
///
/// Everything is a no-op unless [enabled] (defaults to Android, never under
/// `flutter test`, where the platform defaults to Android too).
class ImmersiveMode with WidgetsBindingObserver {
  ImmersiveMode({
    bool? enabled,
    this.revealDelay = const Duration(seconds: 1),
    this.imeDelay = const Duration(milliseconds: 300),
    double Function()? imeInset,
  }) : enabled = enabled ?? _defaultEnabled,
       _imeInset = imeInset ?? _platformImeInset;

  /// The process-wide instance installed by `main()`.
  static final ImmersiveMode instance = ImmersiveMode();

  /// Whether calls reach [SystemChrome].
  final bool enabled;

  /// Delay before re-hiding bars the system reported as visible.
  final Duration revealDelay;

  /// Delay before re-applying after the IME closed.
  final Duration imeDelay;

  final double Function() _imeInset;

  /// The overlay style used while bars are transiently shown: transparent
  /// bars with light icons over the dark-only `background` (#0a0a0a).
  static const SystemUiOverlayStyle overlayStyle = SystemUiOverlayStyle(
    statusBarColor: Color(0x00000000),
    systemNavigationBarColor: Color(0x00000000),
    systemNavigationBarDividerColor: Color(0x00000000),
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarContrastEnforced: false,
    systemStatusBarContrastEnforced: false,
  );

  bool _installed = false;
  double _lastImeInset = 0;
  Timer? _pending;

  static bool get _defaultEnabled {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    // `flutter test` reports Android as the default platform; never touch
    // the system UI from tests unless a test opts in explicitly.
    return !_isFlutterTest;
  }

  static bool get _isFlutterTest =>
      Platform.environment.containsKey('FLUTTER_TEST');

  static double _platformImeInset() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    return views.isEmpty ? 0 : views.first.viewInsets.bottom;
  }

  /// Applies the mode now and starts listening for the re-apply triggers.
  /// Idempotent. Call after `WidgetsFlutterBinding.ensureInitialized()`.
  Future<void> install() async {
    if (!enabled || _installed) return;
    _installed = true;
    WidgetsBinding.instance.addObserver(this);
    _lastImeInset = _imeInset();
    await SystemChrome.setSystemUIChangeCallback(onSystemUiChange);
    SystemChrome.setSystemUIOverlayStyle(overlayStyle);
    await apply();
  }

  /// Stops listening (tests).
  @visibleForTesting
  Future<void> uninstall() async {
    if (!_installed) return;
    _installed = false;
    _pending?.cancel();
    _pending = null;
    WidgetsBinding.instance.removeObserver(this);
    await SystemChrome.setSystemUIChangeCallback(null);
  }

  /// Hides both system bars in sticky-immersive mode.
  Future<void> apply() async {
    if (!enabled) return;
    _pending?.cancel();
    _pending = null;
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _applyAfter(Duration delay) {
    _pending?.cancel();
    _pending = Timer(delay, () {
      _pending = null;
      unawaited(apply());
    });
  }

  /// [SystemChrome.setSystemUIChangeCallback] handler.
  @visibleForTesting
  Future<void> onSystemUiChange(bool systemOverlaysAreVisible) async {
    if (systemOverlaysAreVisible) _applyAfter(revealDelay);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(apply());
  }

  @override
  void didChangeMetrics() {
    final inset = _imeInset();
    final closed = _lastImeInset > 0 && inset <= 0;
    _lastImeInset = inset;
    if (closed) _applyAfter(imeDelay);
  }
}

/// Pads [child] by `MediaQuery.viewPaddingOf(context)` (display cutout, and
/// real bar insets in multi-window) on the chosen sides, plus [base]. The
/// bottom side uses `MediaQuery.paddingOf` so it collapses under the IME.
///
/// "Backgrounds bleed, content insets" (README §4.4): use this around
/// content, never around a whole screen, and never instead of `SafeArea`
/// on backgrounds. IME insets are not included (§4.6).
class SafeViewPadding extends StatelessWidget {
  const SafeViewPadding({
    super.key,
    this.base = EdgeInsets.zero,
    this.left = true,
    this.top = true,
    this.right = true,
    this.bottom = true,
    required this.child,
  });

  /// Padding added on top of the view padding (e.g. the web `px-6`).
  final EdgeInsets base;
  final bool left;
  final bool top;
  final bool right;
  final bool bottom;
  final Widget child;

  /// `base` plus the view padding on the selected sides.
  static EdgeInsets resolve(
    BuildContext context, {
    EdgeInsets base = EdgeInsets.zero,
    bool left = true,
    bool top = true,
    bool right = true,
    bool bottom = true,
  }) {
    final p = MediaQuery.viewPaddingOf(context);
    return base +
        EdgeInsets.only(
          left: left ? p.left : 0,
          top: top ? p.top : 0,
          right: right ? p.right : 0,
          // `padding` (not `viewPadding`) at the bottom: it drops to 0 while
          // the IME covers the bar, so callers that already lift content by
          // the IME (a resizing Scaffold, the panel's viewInsets padding)
          // don't add the bar inset on top of the keyboard.
          bottom: bottom ? MediaQuery.paddingOf(context).bottom : 0,
        );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: resolve(
      context,
      base: base,
      left: left,
      top: top,
      right: right,
      bottom: bottom,
    ),
    child: child,
  );
}
