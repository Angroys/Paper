import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/paper_tokens.dart';
import 'paper_icon.dart';

/// `spinner.svg` in accent, one turn per second (`animate-spin`); static
/// under reduced motion. Sizes 16 (default) and 20 (components.md §16).
class PaperSpinner extends StatefulWidget {
  const PaperSpinner({
    super.key,
    this.size = 16,
    this.color = PaperWeb.accent,
    this.semanticLabel,
  });

  final double size;
  final Color color;
  final String? semanticLabel;

  @override
  State<PaperSpinner> createState() => _PaperSpinnerState();
}

class _PaperSpinnerState extends State<PaperSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: PaperMotion.spin,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _spin.stop();
    } else if (!_spin.isAnimating) {
      unawaited(_spin.repeat());
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: RotationTransition(
      turns: _spin,
      child: PaperIcon(
        PaperIcons.spinner,
        size: widget.size,
        color: widget.color,
        semanticLabel: widget.semanticLabel,
      ),
    ),
  );
}

/// Rotates any [child] like [PaperSpinner] (sync "syncing" glyph).
class PaperSpinning extends StatefulWidget {
  const PaperSpinning({super.key, required this.child});
  final Widget child;

  @override
  State<PaperSpinning> createState() => _PaperSpinningState();
}

class _PaperSpinningState extends State<PaperSpinning>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: PaperMotion.spin,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _spin.stop();
    } else if (!_spin.isAnimating) {
      unawaited(_spin.repeat());
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: RotationTransition(turns: _spin, child: widget.child),
  );
}

/// 6px rounded track (gray-700) with an accent bar: [value] null =
/// indeterminate (1/3 bar sliding −100% → 300% over 1.2 s; static under
/// reduced motion), else determinate 0..1.
class PaperProgressBar extends StatefulWidget {
  const PaperProgressBar({super.key, this.value, this.semanticLabel});

  final double? value;
  final String? semanticLabel;

  @override
  State<PaperProgressBar> createState() => _PaperProgressBarState();
}

class _PaperProgressBarState extends State<PaperProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: PaperMotion.progressIndeterminate,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(PaperProgressBar old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final run =
        widget.value == null && !MediaQuery.disableAnimationsOf(context);
    if (run && !_c.isAnimating) {
      unawaited(_c.repeat());
    } else if (!run && _c.isAnimating) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    return Semantics(
      label: widget.semanticLabel,
      value: value == null ? null : '${(value * 100).round()}%',
      child: ClipRRect(
        borderRadius: PaperRadii.borderFull,
        child: SizedBox(
          height: 6,
          child: ColoredBox(
            color: PaperWeb.gray700,
            child: LayoutBuilder(
              builder: (context, box) {
                if (value != null) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: AnimatedContainer(
                      duration: PaperMotion.of(context, PaperMotion.fast),
                      curve: PaperMotion.standard,
                      width: box.maxWidth * value.clamp(0, 1),
                      decoration: const BoxDecoration(
                        color: PaperWeb.accent,
                        borderRadius: PaperRadii.borderFull,
                      ),
                    ),
                  );
                }
                final barW = box.maxWidth / 3;
                return AnimatedBuilder(
                  animation: _c,
                  builder: (context, child) {
                    final t = Curves.easeInOut.transform(_c.value);
                    final dx = _c.isAnimating
                        ? barW * (-1 + 4 * t)
                        : 0.0; // −100% → 300% of the bar width
                    return Transform.translate(
                      offset: Offset(dx, 0),
                      child: child,
                    );
                  },
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: barW,
                      decoration: const BoxDecoration(
                        color: PaperWeb.accent,
                        borderRadius: PaperRadii.borderFull,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// `animate-pulse` block: gray-800, radius 4, opacity 1 → .5 → 1 over 2 s
/// (static under reduced motion).
class PaperSkeleton extends StatefulWidget {
  const PaperSkeleton({super.key, this.width, this.height = 14});

  final double? width;
  final double height;

  @override
  State<PaperSkeleton> createState() => _PaperSkeletonState();
}

class _PaperSkeletonState extends State<PaperSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: PaperMotion.pulse,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
      _c.value = 0;
    } else if (!_c.isAnimating) {
      unawaited(_c.repeat());
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _c.drive(
      TweenSequence<double>(<TweenSequenceItem<double>>[
        TweenSequenceItem(
          tween: Tween<double>(
            begin: 1,
            end: 0.5,
          ).chain(CurveTween(curve: PaperMotion.pulseCurve)),
          weight: 1,
        ),
        TweenSequenceItem(
          tween: Tween<double>(
            begin: 0.5,
            end: 1,
          ).chain(CurveTween(curve: PaperMotion.pulseCurve)),
          weight: 1,
        ),
      ]),
    ),
    child: Container(
      width: widget.width,
      height: widget.height,
      decoration: const BoxDecoration(
        color: PaperWeb.gray800,
        borderRadius: PaperRadii.borderSm,
      ),
    ),
  );
}
