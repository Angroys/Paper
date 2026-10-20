import '../theme/paper_tokens.dart';

/// Window-class resolver with hysteresis (layout-system.md §3).
///
/// A class change commits only once the width is
/// [PaperBreakpoints.hysteresis] dp past the boundary, so dragging a desktop
/// window edge across a breakpoint doesn't flicker the layout. The token
/// resolver [PaperWindowClass.of] stays stateless; this adds the memory.
PaperWindowClass resolveWindowClass(
  double width, {
  PaperWindowClass? previous,
  double hysteresis = PaperBreakpoints.hysteresis,
}) {
  final raw = PaperWindowClass.of(width);
  if (previous == null || raw == previous) return raw;
  if (raw.index > previous.index) {
    // Growing: the class we'd be in if we were `hysteresis` narrower.
    final damped = PaperWindowClass.of(width - hysteresis);
    return damped.index > previous.index ? damped : previous;
  }
  // Shrinking.
  final damped = PaperWindowClass.of(width + hysteresis);
  return damped.index < previous.index ? damped : previous;
}
