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

/// Resolves the panel presentation (layout-system.md §4):
/// - `compact`: bottom sheet.
/// - `medium`: overlay side sheet (PDF does not resize).
/// - `expanded`+: resizable split, unless the user prefers overlay, the
///   window is shorter than [kSplitMinWindowHeight], or the split would push
///   the PDF below its minimum width ([PaperWindowClass.splitFallsBackToOverlay]).
PanelLayout resolvePanelLayout({
  required double width,
  required double height,
  required PaperWindowClass windowClass,
  bool preferOverlay = false,
}) {
  switch (windowClass.sidePanelMode) {
    case PaperSidePanelMode.bottomSheet:
      return PanelLayout(
        mode: PaperSidePanelMode.bottomSheet,
        defaultWidth: width,
        minWidth: width,
        maxWidth: width,
      );
    case PaperSidePanelMode.overlay:
      return _overlay(width, windowClass, fellBack: false);
    case PaperSidePanelMode.split:
      final fallsBack = windowClass.splitFallsBackToOverlay(width);
      if (fallsBack || preferOverlay || height < kSplitMinWindowHeight) {
        return _overlay(width, windowClass, fellBack: fallsBack);
      }
      final min = windowClass.sidePanelMinWidth!;
      final max = windowClass.sidePanelMaxWidth(width)!;
      return PanelLayout(
        mode: PaperSidePanelMode.split,
        defaultWidth: windowClass.sidePanelWidth!.clamp(min, max).toDouble(),
        minWidth: min,
        maxWidth: max,
      );
  }
}

PanelLayout _overlay(
  double width,
  PaperWindowClass windowClass, {
  required bool fellBack,
}) {
  final min = windowClass.sidePanelMinWidth!;
  final max = width * windowClass.sidePanelMaxFraction!;
  final hi = max < min ? min : max;
  return PanelLayout(
    mode: PaperSidePanelMode.overlay,
    defaultWidth: windowClass.sidePanelWidth!.clamp(min, hi).toDouble(),
    minWidth: min,
    maxWidth: hi,
    fellBackToOverlay: fellBack,
  );
}
