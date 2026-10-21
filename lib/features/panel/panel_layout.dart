import 'package:meta/meta.dart';

import '../../theme/paper_tokens.dart';

/// Below this window height the panel never splits (layout-system.md §3).
const double kSplitMinWindowHeight = 480;

/// How the side panel is presented at a given window size.
@immutable
class PanelLayout {
  const PanelLayout({
    required this.mode,
    required this.defaultWidth,
    required this.minWidth,
    required this.maxWidth,
    this.fellBackToOverlay = false,
  });

  final PaperSidePanelMode mode;

  /// Class default width (bottom sheet: the full window width).
  final double defaultWidth;
  final double minWidth;
  final double maxWidth;

  /// A split class that had to use the overlay because the PDF would drop
  /// below its minimum width (`readerPanelOverlayHint`).
  final bool fellBackToOverlay;

  bool get isSplit => mode == PaperSidePanelMode.split;
  bool get isOverlay => mode == PaperSidePanelMode.overlay;
  bool get isBottomSheet => mode == PaperSidePanelMode.bottomSheet;

  /// Clamps a requested panel width into [minWidth, maxWidth].
  double clampWidth(double w) {
    final hi = maxWidth < minWidth ? minWidth : maxWidth;
    return w.clamp(minWidth, hi).toDouble();
  }

  @override
  bool operator ==(Object other) =>
      other is PanelLayout &&
      other.mode == mode &&
      other.defaultWidth == defaultWidth &&
      other.minWidth == minWidth &&
      other.maxWidth == maxWidth &&
      other.fellBackToOverlay == fellBackToOverlay;

  @override
  int get hashCode =>
      Object.hash(mode, defaultWidth, minWidth, maxWidth, fellBackToOverlay);

  @override
  String toString() =>
      'PanelLayout($mode, $defaultWidth [$minWidth..$maxWidth]'
      '${fellBackToOverlay ? ', fallback' : ''})';
}

/// Resolves the panel presentation on the **full window width** with the
/// web breakpoints (screens/reader.md §1, side-panel.md §1):
/// - `< 640`: bottom sheet.
/// - `640–1023`: overlay, 384 wide, right-anchored, no scrim.
/// - `>= 1024`: docked split at 384 (resizable), unless the user prefers the
///   overlay ([preferOverlay]) or the window is shorter than
///   [kSplitMinWindowHeight].
///
/// [windowClass] is accepted for older callers and ignored.
PanelLayout resolvePanelLayout({
  required double width,
  required double height,
  PaperWindowClass? windowClass,
  bool preferOverlay = false,
}) {
  if (width < PaperBreakpoints.twSm) {
    return PanelLayout(
      mode: PaperSidePanelMode.bottomSheet,
      defaultWidth: width,
      minWidth: width,
      maxWidth: width,
    );
  }
  if (width < PaperBreakpoints.twLg ||
      preferOverlay ||
      height < kSplitMinWindowHeight) {
    final max = (width * PaperBreakpoints.sidePanelMediumMaxFraction)
        .clamp(PaperBreakpoints.sidePanelMediumMin, double.infinity)
        .toDouble();
    return PanelLayout(
      mode: PaperSidePanelMode.overlay,
      defaultWidth: PaperBreakpoints.readerPanelWeb
          .clamp(PaperBreakpoints.sidePanelMediumMin, max)
          .toDouble(),
      minWidth: PaperBreakpoints.sidePanelMediumMin,
      maxWidth: max,
    );
  }
  // Docked: the PDF pane keeps at least half of the window.
  const min = PaperBreakpoints.sidePanelLargeMin;
  final max = (width * 0.5).clamp(min, double.infinity).toDouble();
  return PanelLayout(
    mode: PaperSidePanelMode.split,
    defaultWidth: PaperBreakpoints.readerPanelWeb.clamp(min, max).toDouble(),
    minWidth: min,
    maxWidth: max,
  );
}
