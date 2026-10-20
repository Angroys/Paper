import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/paper_tokens.dart';
import 'reader_screen.dart';

/// Library -> Reader fade-through (motion.md §2.1, catalog #2).
///
/// The PDF is never under an opacity layer: during 0–40% the reader is laid
/// out but hidden (tiles start rendering), then a solid `background`
/// curtain fades out by colour alpha. Reduced motion: instant cut.
Widget readerRouteTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  if (MediaQuery.disableAnimationsOf(context)) return child;
  final bg = Theme.of(context).extension<PaperColors>()!.background;
  final curtain = CurvedAnimation(
    parent: animation,
    curve: const Interval(0.4, 1.0, curve: PaperMotion.decelerate),
    reverseCurve: const Interval(0.4, 1.0, curve: PaperMotion.standard),
  );
  return AnimatedBuilder(
    animation: animation,
    child: child,
    builder: (context, child) => Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Visibility(
          visible: animation.value >= 0.4,
          maintainState: true,
          maintainAnimation: true,
          maintainSize: true,
          child: child!,
        ),
        if (animation.value < 1.0)
          IgnorePointer(
            child: ColoredBox(color: bg.withValues(alpha: 1.0 - curtain.value)),
          ),
      ],
    ),
  );
}

/// `PageTransitionsBuilder` form of [readerRouteTransition].
class ReaderPageTransitionsBuilder extends PageTransitionsBuilder {
  const ReaderPageTransitionsBuilder();

  @override
  Duration get transitionDuration => PaperMotion.page;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => readerRouteTransition(context, animation, secondaryAnimation, child);
}

/// go_router page for `/reader/:paperId`. INTEGRATION: use it in the
/// router as `pageBuilder: (context, state) => buildReaderPage(state)`
/// instead of `builder:`, so the generic fade (an opacity layer over the
/// whole reader, banned by motion.md §1.7) is not used.
Page<void> buildReaderPage(GoRouterState state) => CustomTransitionPage<void>(
  key: state.pageKey,
  transitionDuration: PaperMotion.page,
  reverseTransitionDuration: PaperMotion.page,
  transitionsBuilder: readerRouteTransition,
  child: ReaderScreen(paperId: state.pathParameters['paperId']!),
);
