import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Every glyph the web-parity UI draws (components.md §19).
///
/// Web glyphs are the paper.college inline SVGs verbatim
/// (`assets/icons/*.svg`, copied from design/web-parity/icons). App-only
/// glyphs with no web source are Lucide paths re-exported at stroke 1.5
/// (`assets/icons/app/*.svg`). Text glyphs (`×`, `+`, `−`, `↩`, `↗`, `···`,
/// `Aa`) are not icons: render them as `Text`.
enum PaperIcons {
  // --- web glyphs (design/web-parity/icons) ---
  alertCircle('alert-circle'),
  bookmark('bookmark'),
  check('check'),
  chevronDown('chevron-down'),
  chevronRightSmall('chevron-right-small'),
  fileUpload('file-upload'),
  file('file'),
  highlighter('highlighter'),
  infoSmall('info-small'),
  info('info'),
  lines('lines'),
  navBack('nav-back'),
  navDashboard('nav-dashboard'),
  navPapers('nav-papers'),
  navProfile('nav-profile'),
  navStatistics('nav-statistics'),
  panelHide('panel-hide'),
  panelShow('panel-show'),
  readerBack('reader-back'),
  spinner('spinner'),
  timer('timer'),
  toastCheck('toast-check'),
  toastError('toast-error'),

  // --- app-only Lucide glyphs, stroke 1.5 (design/web-parity/icons/app) ---
  cloud('app/cloud'),
  cloudOff('app/cloud-off'),
  eraser('app/eraser'),
  eye('app/eye'),
  eyeOff('app/eye-off'),
  monitorSmartphone('app/monitor-smartphone'),
  mousePointer('app/mouse-pointer-2'),
  penLine('app/pen-line'),
  refreshCw('app/refresh-cw'),
  scan('app/scan'),
  search('app/search');

  const PaperIcons(this.path);

  /// Path below `assets/icons/`, without the extension.
  final String path;

  /// Asset key for `SvgPicture.asset`.
  String get asset => 'assets/icons/$path.svg';
}

/// Draws a [PaperIcons] glyph at [size] (default 16, the web's `h-4`) in
/// [color] (default: the ambient `IconTheme` colour, so buttons tint it).
///
/// [quarterTurns] rotates (e.g. `chevronDown` turned 2 for "up"); [mirror]
/// flips horizontally (e.g. `navBack` as "next"). Decorative unless a
/// [semanticLabel] is given.
class PaperIcon extends StatelessWidget {
  const PaperIcon(
    this.icon, {
    super.key,
    this.size = 16,
    this.color,
    this.semanticLabel,
    this.quarterTurns = 0,
    this.mirror = false,
  });

  final PaperIcons icon;
  final double size;
  final Color? color;
  final String? semanticLabel;
  final int quarterTurns;
  final bool mirror;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final tint = color ?? iconTheme.color ?? const Color(0xFFA3A3A3);
    Widget glyph = SvgPicture.asset(
      icon.asset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
      excludeFromSemantics: true,
    );
    if (quarterTurns != 0) {
      glyph = RotatedBox(quarterTurns: quarterTurns, child: glyph);
    }
    if (mirror) {
      glyph = Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(-1, 1, 1),
        child: glyph,
      );
    }
    final sized = SizedBox.square(dimension: size, child: glyph);
    if (semanticLabel == null) return ExcludeSemantics(child: sized);
    return Semantics(label: semanticLabel, image: true, child: sized);
  }
}

/// A [PaperIcon] that rotates by [turns] (0..1) with a [duration] ease
/// (disclosure chevrons: 180° open, glossary chevron 90°). Pass
/// `PaperMotion.of(context, PaperMotion.fast)` so reduced motion is instant.
class PaperRotatingIcon extends StatelessWidget {
  const PaperRotatingIcon(
    this.icon, {
    super.key,
    required this.turns,
    required this.duration,
    this.size = 16,
    this.color,
  });

  final PaperIcons icon;
  final double turns;
  final Duration duration;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween<double>(end: turns),
    duration: duration,
    curve: const Cubic(0.4, 0.0, 0.2, 1.0),
    builder: (context, t, child) =>
        Transform.rotate(angle: t * 2 * math.pi, child: child),
    child: PaperIcon(icon, size: size, color: color),
  );
}
