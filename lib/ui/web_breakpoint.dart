import 'package:flutter/widgets.dart';

import '../theme/paper_tokens.dart';

/// Tailwind's default `screens` on the **full window width**
/// (design/web-parity/screens/README.md §3.1). Web-parity layouts switch on
/// these, never on [PaperWindowClass] (whose thresholds differ).
///
/// Min-width and inclusive, with no hysteresis, exactly like CSS media
/// queries: `WebBreakpoint.of(context) >= WebBreakpoint.lg` is the app's
/// `lg:` prefix.
enum WebBreakpoint {
  /// `width < 640` (no prefix).
  base(0),

  /// `sm:` 640 ≤ width < 768.
  sm(PaperBreakpoints.twSm),

  /// `md:` 768 ≤ width < 1024.
  md(PaperBreakpoints.twMd),

  /// `lg:` 1024 ≤ width < 1280.
  lg(PaperBreakpoints.twLg),

  /// `xl:` 1280 ≤ width < 1536.
  xl(PaperBreakpoints.twXl),

  /// `2xl:` width ≥ 1536.
  xxl(PaperBreakpoints.tw2xl);

  const WebBreakpoint(this.minWidth);

  /// Inclusive lower bound in logical px.
  final double minWidth;

  /// The breakpoint for a window [width] (do not subtract insets/chrome).
  static WebBreakpoint fromWidth(double width) {
    for (final b in values.reversed) {
      if (width >= b.minWidth) return b;
    }
    return base;
  }

  /// The breakpoint for the current window. Rebuilds only on size changes
  /// (`MediaQuery.sizeOf`).
  static WebBreakpoint of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);

  bool operator >=(WebBreakpoint other) => index >= other.index;
  bool operator >(WebBreakpoint other) => index > other.index;
  bool operator <=(WebBreakpoint other) => index <= other.index;
  bool operator <(WebBreakpoint other) => index < other.index;

  /// `sm:` and up (labels shown, desktop-style rows).
  bool get isSmUp => this >= sm;

  /// `lg:` and up (docked reader panel).
  bool get isLgUp => this >= lg;
}
