// App-side motion constants from design/specs/motion.md §0.1.
//
// These are timings and thresholds, not curves; they reuse the token easings
// in PaperMotion (paper_tokens.dart).

/// Syncing glyph rotation: one turn per period, `PaperMotion.linear` (§2.9).
const Duration kSpinPeriod = Duration(milliseconds: 1000);

/// Dp of scroll in one direction before the reader toolbar hides/shows.
/// Stops the toolbar flickering on small scroll jitters.
const double kToolbarHideThreshold = 24;

/// Re-render PDF tiles this long after the last window/panel resize (§4.2).
const Duration kRerasterIdle = Duration(milliseconds: 120);

/// Skeletons appear only if a load takes longer than this.
const Duration kSkeletonDelay = Duration(milliseconds: 150);

/// Don't show the `syncing` state for syncs shorter than this.
const Duration kSyncingMinVisible = Duration(milliseconds: 400);

/// Programmatic scrolls longer than this many viewport heights jump instead
/// of animating (§2.11).
const double kAnimatedScrollMaxDistance = 1;

/// Undo snackbar after creating/deleting a highlight (flow F4).
const Duration kUndoSnackbarDurationHighlight = Duration(seconds: 5);

/// Undo snackbar after deleting from the library (flow F7).
const Duration kUndoSnackbarDurationLibraryDelete = Duration(seconds: 8);
