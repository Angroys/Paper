import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../core/window_class.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/motion_extras.dart';
import '../../theme/paper_tokens.dart';
import '../../theme/theme_x.dart';
import 'panel_layout.dart';

/// Reader + side panel container (layout-system.md §4, motion #3–#6).
///
/// - `split` (expanded+): the panel slides in as an overlay, *then* the
///   viewport commits to the narrower width in one relayout; on close the
///   viewport commits to full width first, then the panel slides out
///   (motion.md §2.3). The [SplitDragHandle] resizes the panel; during the
///   drag the viewport keeps its pre-drag constraints and is drawn through a
///   `Transform.scale` (no relayout, no re-render), committed on drag end
///   (§1.5).
/// - `overlay` (medium, or a split class that falls back): side sheet from
///   the right over a colour-animated scrim; the PDF never resizes and is
///   inert while the scrim is up.
/// - `bottomSheet` (compact): sheet snapping 40% / 90% of the height.
///
/// Live window resizes keep the viewport at its last committed size, scaled
/// to fit, and commit [kRerasterIdle] after the last size change (§4.2).
class ReaderSplitView extends StatefulWidget {
  const ReaderSplitView({
    super.key,
    required this.reader,
    required this.panel,
    required this.open,
    required this.onClose,
    this.preferOverlay = false,
    this.initialPanelWidth,
    this.onPanelWidthCommitted,
    this.onLayoutChanged,
  });

  /// The PDF viewport (and its popover layer).
  final Widget reader;

  /// The side panel body (tab bar + tabs).
  final Widget panel;
  final bool open;

  /// Scrim tap, snap-closed drag, sheet swipe down.
  final VoidCallback onClose;

  /// Settings › Reader › "Panel style" = Overlay.
  final bool preferOverlay;

  /// Persisted split width (per device); null = class default.
  final double? initialPanelWidth;

  /// Called on drag end / keyboard resize with the committed width.
  final ValueChanged<double>? onPanelWidthCommitted;

  /// Reports the resolved layout (e.g. to show `readerPanelOverlayHint`).
  final ValueChanged<PanelLayout>? onLayoutChanged;

  @override
  State<ReaderSplitView> createState() => _ReaderSplitViewState();
}

class _ReaderSplitViewState extends State<ReaderSplitView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slide = AnimationController(
    vsync: this,
    value: widget.open ? 1 : 0,
  )..addStatusListener(_onSlideStatus);

  final GlobalKey _readerKey = GlobalKey(debugLabel: 'reader-viewport');
  PaperWindowClass? _windowClass;
  PanelLayout? _layout;
  double? _panelWidth;

  /// Split only: the viewport currently laid out narrow.
  late bool _committedOpen = widget.open;

  // Split drag.
  double? _dragWidth;
  double? _pendingDragWidth;
  bool _frameScheduled = false;

  // Live resize.
  Size? _committedSize;
  Size? _latestSize;
  Timer? _resizeTimer;

  // Bottom sheet height fraction.
  double _sheetFraction = 0.4;

  @override
  void didUpdateWidget(ReaderSplitView old) {
    super.didUpdateWidget(old);
    if (widget.open != old.open) _animateOpen(widget.open);
  }

  @override
  void dispose() {
    _resizeTimer?.cancel();
    _slide.dispose();
    super.dispose();
  }

  void _animateOpen(bool open) {
    final layout = _layout;
    if (open) {
      _slide.duration = PaperMotion.of(context, PaperMotion.slow);
      _sheetFraction = 0.4;
      if (_slide.duration == Duration.zero) {
        // Reduced motion: instant layout change, one commit, no slide.
        _committedOpen = layout?.isSplit ?? false;
        _slide.value = 1;
        return;
      }
      unawaited(
        _slide.animateTo(1, curve: PaperMotion.decelerate),
      );
    } else {
      if (layout != null && layout.isSplit && _committedOpen) {
        // Commit, then slide: the viewport widens under the panel first.
        setState(() => _committedOpen = false);
      }
      _slide.duration = PaperMotion.of(context, PaperMotion.base);
      unawaited(_slide.animateBack(0, curve: PaperMotion.accelerate));
    }
  }

  void _onSlideStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && widget.open) {
      // Slide, then commit (one relayout of the viewport).
      if (!_committedOpen && mounted) setState(() => _committedOpen = true);
    } else if (status == AnimationStatus.dismissed && mounted) {
      setState(() {
        _committedOpen = false;
        _dragWidth = null;
      });
    }
  }

  double _currentWidth(PanelLayout layout) =>
      layout.clampWidth(_panelWidth ?? widget.initialPanelWidth ?? layout.defaultWidth);

  // -------------------------------------------------------------------
  // Split drag (motion #6, §1.5)
  // -------------------------------------------------------------------

  void _onDragUpdate(double dx, PanelLayout layout) {
    final base = _pendingDragWidth ?? _dragWidth ?? _currentWidth(layout);
    // Allow dragging below min (towards the snap-close threshold).
    _pendingDragWidth = (base - dx).clamp(0.0, layout.maxWidth).toDouble();
    if (_frameScheduled) return;
    _frameScheduled = true;
    // Coalesce pointer moves to one update per frame.
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _frameScheduled = false;
      if (!mounted) return;
      setState(() => _dragWidth = _pendingDragWidth);
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _onDragEnd(PanelLayout layout) {
    final w = _pendingDragWidth ?? _dragWidth;
    _pendingDragWidth = null;
    if (w == null) return;
    if (w < layout.minWidth - PaperBreakpoints.sidePanelCloseSnap) {
      // Snap closed: haptic tick on touch, slide out, then commit.
      unawaited(HapticFeedback.selectionClick());
      setState(() => _dragWidth = null);
      widget.onClose();
      return;
    }
    final committed = layout.clampWidth(w);
    setState(() {
      _dragWidth = null;
      _panelWidth = committed;
    });
    widget.onPanelWidthCommitted?.call(committed);
  }

  void _jumpTo(double width, PanelLayout layout) {
    final committed = layout.clampWidth(width);
    setState(() => _panelWidth = committed);
    widget.onPanelWidthCommitted?.call(committed);
  }

  // -------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final wc = resolveWindowClass(size.width, previous: _windowClass);
        _windowClass = wc;
        final layout = resolvePanelLayout(
          width: size.width,
          height: size.height,
          windowClass: wc,
          preferOverlay: widget.preferOverlay,
        );
        if (layout != _layout) {
          final previous = _layout;
          _layout = layout;
          if (previous != null && previous.mode != layout.mode) {
            // Window-class change: shells swap instantly (motion #51).
            _committedOpen = widget.open && layout.isSplit;
          }
          final cb = widget.onLayoutChanged;
          if (cb != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) => cb(layout));
          }
        }
        _trackResize(size);
        return switch (layout.mode) {
          PaperSidePanelMode.split => _buildSplit(context, size, layout),
          PaperSidePanelMode.overlay => _buildOverlay(context, size, layout),
          PaperSidePanelMode.bottomSheet => _buildSheet(context, size),
        };
      },
    );
  }

  void _trackResize(Size size) {
    _latestSize = size;
    final committed = _committedSize;
    if (committed == null) {
      _committedSize = size;
      return;
    }
    if (committed == size) return;
    _resizeTimer?.cancel();
    _resizeTimer = Timer(kRerasterIdle, () {
      if (!mounted) return;
      setState(() => _committedSize = _latestSize);
    });
  }

  /// The viewport at [width] x [height]. During a split drag it keeps
  /// [committedWidth]; during a live window resize it keeps the width it
  /// had at the last committed window size. Either way it is drawn scaled
  /// to [width] until the commit.
  Widget _viewport(double width, double height, {double? committedWidth}) {
    final committed = _committedSize;
    final latest = _latestSize;
    final resizing =
        committed != null && latest != null && committed != latest;
    final fromWidth =
        committedWidth ??
        (resizing ? width * committed.width / latest.width : null);
    final w = (fromWidth == null || fromWidth <= 0) ? width : fromWidth;
    // Same tree shape whether or not it is scaled, so the viewport state
    // (the open document) is never rebuilt by a drag or a resize.
    return SizedBox(
      width: width,
      height: height,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: w,
          maxWidth: w,
          minHeight: height,
          maxHeight: height,
          child: Transform.scale(
            scale: width / w,
            alignment: Alignment.topLeft,
            child: KeyedSubtree(key: _readerKey, child: widget.reader),
          ),
        ),
      ),
    );
  }

  Widget _buildSplit(BuildContext context, Size size, PanelLayout layout) {
    final c = context.paper;
    final panelW = _currentWidth(layout);
    final dragW = _dragWidth;
    final visiblePanelW = dragW ?? panelW;
    final committedViewportW = _committedOpen
        ? size.width - panelW - PaperChrome.splitDividerWidth
        : size.width;
    final touch = Theme.of(context).platform == TargetPlatform.android;
    final hit = touch
        ? PaperChrome.splitHitWidthTouch
        : PaperChrome.splitHitWidthPointer;
    final showPanel = widget.open || !_slide.isDismissed;

    Widget viewport;
    if (dragW != null && _committedOpen) {
      // Drag: keep pre-drag constraints, scale the existing raster.
      final target = (size.width - dragW - PaperChrome.splitDividerWidth)
          .clamp(1.0, size.width)
          .toDouble();
      viewport = _viewport(
        target,
        size.height,
        committedWidth: committedViewportW,
      );
    } else {
      viewport = _viewport(committedViewportW, size.height);
    }

    return Stack(
      children: <Widget>[
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: dragW != null && _committedOpen
              ? (size.width - dragW - PaperChrome.splitDividerWidth)
                    .clamp(1.0, size.width)
                    .toDouble()
              : committedViewportW,
          child: viewport,
        ),
        if (showPanel)
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            width: visiblePanelW + PaperChrome.splitDividerWidth + hit / 2,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(_slide),
              child: Stack(
                children: <Widget>[
                  Positioned(
                    top: 0,
                    bottom: 0,
                    right: 0,
                    width: visiblePanelW,
                    child: ColoredBox(
                      color: c.surface,
                      child: RepaintBoundary(child: widget.panel),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: 0,
                    width: hit,
                    child: SplitDragHandle(
                      hitWidth: hit,
                      widthPercent: visiblePanelW / size.width,
                      onDragUpdate: (dx) => _onDragUpdate(dx, layout),
                      onDragEnd: () => _onDragEnd(layout),
                      onReset: () => _jumpTo(layout.defaultWidth, layout),
                      onKeyResize: (delta) => _jumpTo(panelW + delta, layout),
                      onKeyMin: () => _jumpTo(layout.minWidth, layout),
                      onKeyMax: () => _jumpTo(layout.maxWidth, layout),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _scrim(BuildContext context) {
    final c = context.paper;
    return AnimatedModalBarrier(
      color: ColorTween(
        begin: c.scrim.withValues(alpha: 0),
        end: c.scrim,
      ).animate(_slide),
      dismissible: true,
      onDismiss: widget.onClose,
    );
  }

  Widget _buildOverlay(BuildContext context, Size size, PanelLayout layout) {
    final c = context.paper;
    final panelW = layout.clampWidth(_panelWidth ?? layout.defaultWidth);
    final showPanel = widget.open || !_slide.isDismissed;
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: ExcludeFocus(
            excluding: widget.open,
            child: AbsorbPointer(
              absorbing: widget.open,
              child: _viewport(size.width, size.height),
            ),
          ),
        ),
        if (showPanel) Positioned.fill(child: _scrim(context)),
        if (showPanel)
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            width: panelW,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(_slide),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border(left: BorderSide(color: c.border)),
                  boxShadow: PaperElevation.shadow3(
                    Theme.of(context).brightness,
                  ),
                ),
                child: RepaintBoundary(child: widget.panel),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSheet(BuildContext context, Size size) {
    final c = context.paper;
    final showPanel = widget.open || !_slide.isDismissed;
    final height = size.height * _sheetFraction;
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: ExcludeFocus(
            excluding: widget.open,
            child: AbsorbPointer(
              absorbing: widget.open,
              child: _viewport(size.width, size.height),
            ),
          ),
        ),
        if (showPanel) Positioned.fill(child: _scrim(context)),
        if (showPanel)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: height,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(_slide),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(PaperRadii.xxl),
                  ),
                  boxShadow: PaperElevation.shadow3(
                    Theme.of(context).brightness,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    GestureDetector(
                      key: const ValueKey<String>('panel-sheet-handle'),
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: (d) => setState(() {
                        _sheetFraction = (_sheetFraction -
                                d.delta.dy / size.height)
                            .clamp(0.1, 0.9);
                      }),
                      onVerticalDragEnd: (d) {
                        final v = d.primaryVelocity ?? 0;
                        if (_sheetFraction < 0.25 || v > 1200) {
                          widget.onClose();
                          return;
                        }
                        setState(() {
                          _sheetFraction = (_sheetFraction > 0.65 || v < -1200)
                              ? 0.9
                              : 0.4;
                        });
                      },
                      child: SizedBox(
                        height: 24,
                        width: double.infinity,
                        child: Center(
                          child: Container(
                            width: 32,
                            height: 4,
                            decoration: BoxDecoration(
                              color: c.outlineVariant,
                              borderRadius: PaperRadii.borderFull,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(child: RepaintBoundary(child: widget.panel)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// `SplitDragHandle`: 1dp divider + 24×48 grabber, 16 (pointer) / 24
/// (touch) dp hit area over the divider. Keyboard: ←/→ 16dp, Shift 64dp,
/// Home/End min/max; double-click resets. Semantics: slider.
class SplitDragHandle extends StatefulWidget {
  const SplitDragHandle({
    super.key,
    required this.hitWidth,
    required this.widthPercent,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onReset,
    required this.onKeyResize,
    required this.onKeyMin,
    required this.onKeyMax,
  });

  final double hitWidth;

  /// Panel width as a fraction of the window (semantics value).
  final double widthPercent;

  /// Pointer moved by dx (positive = right = panel narrower).
  final ValueChanged<double> onDragUpdate;
  final VoidCallback onDragEnd;
  final VoidCallback onReset;

  /// Positive = wider panel.
  final ValueChanged<double> onKeyResize;
  final VoidCallback onKeyMin;
  final VoidCallback onKeyMax;

  @override
  State<SplitDragHandle> createState() => _SplitDragHandleState();
}

class _SplitDragHandleState extends State<SplitDragHandle> {
  bool _hover = false;
  bool _dragging = false;
  bool _focused = false;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final step = shift ? PaperChrome.splitKeyStepLarge : PaperChrome.splitKeyStep;
    final key = event.logicalKey;
    // The panel is on the right: ← widens it, → narrows it.
    if (key == LogicalKeyboardKey.arrowLeft) {
      widget.onKeyResize(step);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      widget.onKeyResize(-step);
    } else if (key == LogicalKeyboardKey.home) {
      widget.onKeyMin();
    } else if (key == LogicalKeyboardKey.end) {
      widget.onKeyMax();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.paper;
    final l10n = AppLocalizations.of(context);
    final active = _hover || _dragging;
    return Semantics(
      slider: true,
      label: l10n.readerPanelResizeLabel,
      value: '${(widget.widthPercent * 100).round()}%',
      child: Focus(
        onKeyEvent: _onKey,
        onFocusChange: (f) => setState(() => _focused = f),
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeColumn,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            key: const ValueKey<String>('split-drag-handle'),
            behavior: HitTestBehavior.opaque,
            dragStartBehavior: DragStartBehavior.down,
            onHorizontalDragStart: (_) => setState(() => _dragging = true),
            onHorizontalDragUpdate: (d) => widget.onDragUpdate(d.delta.dx),
            onHorizontalDragEnd: (_) {
              setState(() => _dragging = false);
              widget.onDragEnd();
            },
            onHorizontalDragCancel: () {
              setState(() => _dragging = false);
              widget.onDragEnd();
            },
            onDoubleTap: widget.onReset,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Positioned(
                  top: 0,
                  bottom: 0,
                  width: active ? 2 : PaperChrome.splitDividerWidth,
                  child: ColoredBox(color: active ? c.primary : c.border),
                ),
                Container(
                  width: PaperChrome.splitGrabberWidth,
                  height: PaperChrome.splitGrabberHeight,
                  decoration: BoxDecoration(
                    color: active ? c.primarySoft : c.surfaceVariant,
                    borderRadius: PaperRadii.borderFull,
                    border: Border.all(
                      color: _focused
                          ? c.focusRing
                          : (active ? c.primary : c.outlineVariant),
                      width: _focused ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      for (var i = 0; i < 2; i++) ...<Widget>[
                        if (i == 1) const SizedBox(width: 6),
                        SizedBox(
                          width: 1.5,
                          height: 16,
                          child: ColoredBox(
                            color: active ? c.onPrimarySoft : c.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
