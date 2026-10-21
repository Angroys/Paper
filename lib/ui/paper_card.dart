import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/paper_tokens.dart';

/// Card-like web surfaces (components.md §6).
enum PaperSurfaceKind {
  /// `.card`: gray-900, 1px gray-800, radius 8, no shadow.
  card,

  /// Citation popover / menus: gray-900, 1px **gray-700**, radius 8,
  /// shadow-xl.
  popover,

  /// Floating explanation shell: gray-950, 1px gray-800, radius 8,
  /// shadow-xl.
  floating,

  /// Toast: #161616, 1px gray-800, radius 8, shadow-md, backdrop blur.
  toast,

  /// Dialog: `.card` + shadow-xl.
  dialog,
}

/// A web `.card` (and its look-alikes via [kind]). Padding variants used
/// by the web: 12, 16, 20 (default), 24, 32 (`p-3` … `p-8`).
class PaperCard extends StatelessWidget {
  const PaperCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(PaperSpacing.tw5),
    this.kind = PaperSurfaceKind.card,
    this.clip = false,
    this.width,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final PaperSurfaceKind kind;

  /// `overflow-hidden` (tables): clip children to the radius.
  final bool clip;
  final double? width;

  static Color fillOf(PaperSurfaceKind kind) => switch (kind) {
    PaperSurfaceKind.floating => PaperWeb.gray950,
    PaperSurfaceKind.toast => PaperWeb.gray900Toast,
    _ => PaperWeb.gray900,
  };

  static Color borderOf(PaperSurfaceKind kind) =>
      kind == PaperSurfaceKind.popover ? PaperWeb.gray700 : PaperWeb.gray800;

  static List<BoxShadow>? shadowOf(PaperSurfaceKind kind) => switch (kind) {
    PaperSurfaceKind.card => null,
    PaperSurfaceKind.toast => PaperElevation.shadowMd,
    _ => PaperElevation.shadowXl,
  };

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: fillOf(kind),
      borderRadius: PaperRadii.borderLg,
      border: Border.all(color: borderOf(kind)),
      boxShadow: shadowOf(kind),
    );
    Widget box = Container(
      width: width,
      decoration: decoration,
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      padding: padding,
      child: child,
    );
    if (kind == PaperSurfaceKind.toast) {
      box = ClipRRect(
        borderRadius: PaperRadii.borderLg,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: box,
        ),
      );
    }
    return box;
  }
}
