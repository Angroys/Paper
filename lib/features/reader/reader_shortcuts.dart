import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/domain.dart';
import 'reader_controller.dart';

// Reader keyboard shortcuts (layout-system.md §9) as Intents + Actions.
//
// Single-key shortcuts (H, E, N, 1–6, V/P/F, page keys) and Mod+C are
// disabled while a text input has focus (the action reports
// `isEnabled == false`, so the key event falls through to the field) and
// when the user turned them off (Settings › Reader › "Single-key
// shortcuts", WCAG 2.1.4). Esc and the Mod chords listed as global keep
// working.

/// V / H (no selection) / P / F.
class ReaderToolIntent extends Intent {
  const ReaderToolIntent(this.tool);
  final ReaderTool tool;
}

/// H: highlight the selection in the last colour; with no selection it
/// selects the Highlight tool.
class HighlightSelectionIntent extends Intent {
  const HighlightSelectionIntent();
}

/// 1–6: colour for the selection / the open HighlightPicker.
class HighlightColorIntent extends Intent {
  const HighlightColorIntent(this.color);
  final HighlightColor color;
}

class ExplainSelectionIntent extends Intent {
  const ExplainSelectionIntent();
}

class AddNoteIntent extends Intent {
  const AddNoteIntent();
}

class CopySelectionIntent extends Intent {
  const CopySelectionIntent();
}

enum ReaderZoomCommand { zoomIn, zoomOut, actualSize, fitWidth, fitPage }

class ReaderZoomIntent extends Intent {
  const ReaderZoomIntent(this.command);
  final ReaderZoomCommand command;
}

enum ReaderPageCommand { next, previous, first, last }

class ReaderPageIntent extends Intent {
  const ReaderPageIntent(this.command);
  final ReaderPageCommand command;
}

class GoToPageIntent extends Intent {
  const GoToPageIntent();
}

class FindInPaperIntent extends Intent {
  const FindInPaperIntent();
}

class FindMatchIntent extends Intent {
  const FindMatchIntent({required this.forward});
  final bool forward;
}

class TogglePanelIntent extends Intent {
  const TogglePanelIntent();
}

class PanelTabIntent extends Intent {
  const PanelTabIntent(this.tab);
  final ReaderPanelTab tab;
}

class ReaderEscapeIntent extends Intent {
  const ReaderEscapeIntent();
}

class CloseReaderIntent extends Intent {
  const CloseReaderIntent();
}

/// Intents that are single-key (or would steal a text field's own keys) and
/// therefore never fire while a text input has focus.
bool isTextSensitiveIntent(Intent intent) =>
    intent is ReaderToolIntent ||
    intent is HighlightSelectionIntent ||
    intent is HighlightColorIntent ||
    intent is ExplainSelectionIntent ||
    intent is AddNoteIntent ||
    intent is CopySelectionIntent ||
    intent is ReaderPageIntent;

/// True when the primary focus is inside an editable text field.
bool textInputHasFocus() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return false;
  return context.widget is EditableText ||
      context.findAncestorStateOfType<EditableTextState>() != null;
}

/// True on macOS / iOS (Cmd is the modifier).
bool isApplePlatform(TargetPlatform p) =>
    p == TargetPlatform.macOS || p == TargetPlatform.iOS;

/// The reader shortcut table for [platform].
Map<ShortcutActivator, Intent> readerShortcuts(TargetPlatform platform) {
  final mac = isApplePlatform(platform);
  SingleActivator mod(
    LogicalKeyboardKey key, {
    bool shift = false,
    bool alt = false,
  }) => SingleActivator(key, meta: mac, control: !mac, shift: shift, alt: alt);
  final digits = <LogicalKeyboardKey>[
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
  ];
  return <ShortcutActivator, Intent>{
    // Tools + selection actions (single key).
    const SingleActivator(LogicalKeyboardKey.keyV): const ReaderToolIntent(
      ReaderTool.select,
    ),
    const SingleActivator(LogicalKeyboardKey.keyP): const ReaderToolIntent(
      ReaderTool.pen,
    ),
    const SingleActivator(LogicalKeyboardKey.keyF): const ReaderToolIntent(
      ReaderTool.figure,
    ),
    const SingleActivator(LogicalKeyboardKey.keyH):
        const HighlightSelectionIntent(),
    const SingleActivator(LogicalKeyboardKey.keyE):
        const ExplainSelectionIntent(),
    const SingleActivator(LogicalKeyboardKey.keyN): const AddNoteIntent(),
    for (var i = 0; i < 6; i++)
      SingleActivator(digits[i]): HighlightColorIntent(
        HighlightColor.values[i],
      ),
    mod(LogicalKeyboardKey.keyC): const CopySelectionIntent(),
    // Pages.
    const SingleActivator(LogicalKeyboardKey.pageDown): const ReaderPageIntent(
      ReaderPageCommand.next,
    ),
    const SingleActivator(LogicalKeyboardKey.pageUp): const ReaderPageIntent(
      ReaderPageCommand.previous,
    ),
    const SingleActivator(LogicalKeyboardKey.arrowRight):
        const ReaderPageIntent(ReaderPageCommand.next),
    const SingleActivator(LogicalKeyboardKey.arrowLeft): const ReaderPageIntent(
      ReaderPageCommand.previous,
    ),
    const SingleActivator(LogicalKeyboardKey.home): const ReaderPageIntent(
      ReaderPageCommand.first,
    ),
    const SingleActivator(LogicalKeyboardKey.end): const ReaderPageIntent(
      ReaderPageCommand.last,
    ),
    if (mac) ...<ShortcutActivator, Intent>{
      const SingleActivator(LogicalKeyboardKey.arrowUp, meta: true):
          const ReaderPageIntent(ReaderPageCommand.first),
      const SingleActivator(LogicalKeyboardKey.arrowDown, meta: true):
          const ReaderPageIntent(ReaderPageCommand.last),
    },
    // Go to page: Ctrl+G / Cmd+Option+G (Cmd+G is find-next on macOS).
    if (mac)
      const SingleActivator(LogicalKeyboardKey.keyG, meta: true, alt: true):
          const GoToPageIntent()
    else
      const SingleActivator(LogicalKeyboardKey.keyG, control: true):
          const GoToPageIntent(),
    // Zoom.
    mod(LogicalKeyboardKey.equal): const ReaderZoomIntent(
      ReaderZoomCommand.zoomIn,
    ),
    mod(LogicalKeyboardKey.equal, shift: true): const ReaderZoomIntent(
      ReaderZoomCommand.zoomIn,
    ),
    mod(LogicalKeyboardKey.numpadAdd): const ReaderZoomIntent(
      ReaderZoomCommand.zoomIn,
    ),
    mod(LogicalKeyboardKey.minus): const ReaderZoomIntent(
      ReaderZoomCommand.zoomOut,
    ),
    mod(LogicalKeyboardKey.numpadSubtract): const ReaderZoomIntent(
      ReaderZoomCommand.zoomOut,
    ),
    mod(LogicalKeyboardKey.digit0): const ReaderZoomIntent(
      ReaderZoomCommand.actualSize,
    ),
    mod(LogicalKeyboardKey.digit1): const ReaderZoomIntent(
      ReaderZoomCommand.fitWidth,
    ),
    mod(LogicalKeyboardKey.digit2): const ReaderZoomIntent(
      ReaderZoomCommand.fitPage,
    ),
    // Find.
    mod(LogicalKeyboardKey.keyF): const FindInPaperIntent(),
    if (mac) ...<ShortcutActivator, Intent>{
      const SingleActivator(LogicalKeyboardKey.keyG, meta: true):
          const FindMatchIntent(forward: true),
      const SingleActivator(LogicalKeyboardKey.keyG, meta: true, shift: true):
          const FindMatchIntent(forward: false),
    } else ...<ShortcutActivator, Intent>{
      const SingleActivator(LogicalKeyboardKey.f3): const FindMatchIntent(
        forward: true,
      ),
      const SingleActivator(LogicalKeyboardKey.f3, shift: true):
          const FindMatchIntent(forward: false),
    },
    // Side panel.
    mod(LogicalKeyboardKey.backslash): const TogglePanelIntent(),
    for (var i = 0; i < ReaderPanelTab.values.length; i++)
      mod(digits[i], alt: true): PanelTabIntent(ReaderPanelTab.values[i]),
    // Escape + close.
    const SingleActivator(LogicalKeyboardKey.escape):
        const ReaderEscapeIntent(),
    mod(LogicalKeyboardKey.keyW): const CloseReaderIntent(),
    if (mac)
      const SingleActivator(LogicalKeyboardKey.bracketLeft, meta: true):
          const CloseReaderIntent()
    else
      const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true):
          const CloseReaderIntent(),
  };
}

/// An action that is disabled for text-sensitive intents while a text
/// field has focus or single-key shortcuts are off.
class _ReaderAction<T extends Intent> extends Action<T> {
  _ReaderAction(this._invoke, this._singleKeyEnabled);

  final void Function(T intent) _invoke;
  final bool Function() _singleKeyEnabled;

  @override
  bool isEnabled(T intent) {
    if (!isTextSensitiveIntent(intent)) return true;
    return _singleKeyEnabled() && !textInputHasFocus();
  }

  @override
  bool consumesKey(T intent) => isEnabled(intent);

  @override
  Object? invoke(T intent) {
    _invoke(intent);
    return null;
  }
}

/// Installs the reader shortcuts around [child] and dispatches them to the
/// [ReaderController] of [paperId].
class ReaderShortcuts extends ConsumerWidget {
  const ReaderShortcuts({
    super.key,
    required this.paperId,
    required this.child,
    this.singleKeyShortcuts = true,
    this.panelIsOverlay = false,
    this.onClose,
    this.onGoToPage,
    this.onCopySelection,
    this.focusNode,
  });

  final String paperId;
  final Widget child;
  final bool singleKeyShortcuts;
  final bool panelIsOverlay;

  /// Close the reader (Mod+W, Cmd+[ / Alt+←, Esc with nothing open).
  final VoidCallback? onClose;

  /// Open the `PageJumpDialog`.
  final VoidCallback? onGoToPage;
  final VoidCallback? onCopySelection;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = readerControllerProvider(paperId);
    // Keep the (auto-dispose) controller alive while shortcuts are mounted.
    ref.listen<ReaderState>(provider, (_, _) {});
    ReaderController ctrl() => ref.read(provider.notifier);
    ReaderState state() => ref.read(provider);
    bool singleKey() => singleKeyShortcuts;

    return Shortcuts(
      shortcuts: readerShortcuts(Theme.of(context).platform),
      child: Actions(
        actions: <Type, Action<Intent>>{
          ReaderToolIntent: _ReaderAction<ReaderToolIntent>(
            (i) => ctrl().setTool(i.tool),
            singleKey,
          ),
          HighlightSelectionIntent: _ReaderAction<HighlightSelectionIntent>((
            _,
          ) {
            if (state().selection != null) {
              unawaited(ctrl().highlightSelection());
            } else {
              ctrl().setTool(ReaderTool.highlight);
            }
          }, singleKey),
          HighlightColorIntent: _ReaderAction<HighlightColorIntent>((i) {
            final s = state();
            final picked = s.selectedHighlightId;
            if (s.selection != null) {
              unawaited(ctrl().highlightSelection(i.color));
            } else if (picked != null) {
              unawaited(ctrl().changeHighlightColor(picked, i.color));
            } else {
              ctrl().setHighlightColor(i.color);
            }
          }, singleKey),
          ExplainSelectionIntent: _ReaderAction<ExplainSelectionIntent>(
            (_) => unawaited(ctrl().explainSelection()),
            singleKey,
          ),
          AddNoteIntent: _ReaderAction<AddNoteIntent>(
            (_) => unawaited(ctrl().noteForSelection()),
            singleKey,
          ),
          CopySelectionIntent: _ReaderAction<CopySelectionIntent>(
            (_) => onCopySelection?.call(),
            singleKey,
          ),
          ReaderPageIntent: _ReaderAction<ReaderPageIntent>(
            (i) => switch (i.command) {
              ReaderPageCommand.next => ctrl().nextPage(),
              ReaderPageCommand.previous => ctrl().previousPage(),
              ReaderPageCommand.first => ctrl().firstPage(),
              ReaderPageCommand.last => ctrl().lastPage(),
            },
            singleKey,
          ),
          GoToPageIntent: _ReaderAction<GoToPageIntent>(
            (_) => onGoToPage?.call(),
            singleKey,
          ),
          ReaderZoomIntent: _ReaderAction<ReaderZoomIntent>(
            (i) => switch (i.command) {
              ReaderZoomCommand.zoomIn => ctrl().zoomIn(),
              ReaderZoomCommand.zoomOut => ctrl().zoomOut(),
              ReaderZoomCommand.actualSize => ctrl().resetZoom(),
              ReaderZoomCommand.fitWidth => ctrl().fitWidth(),
              ReaderZoomCommand.fitPage => ctrl().fitPage(),
            },
            singleKey,
          ),
          FindInPaperIntent: _ReaderAction<FindInPaperIntent>(
            (_) => ctrl().openSearch(),
            singleKey,
          ),
          FindMatchIntent: _ReaderAction<FindMatchIntent>(
            (i) => i.forward ? ctrl().searchNext() : ctrl().searchPrevious(),
            singleKey,
          ),
          TogglePanelIntent: _ReaderAction<TogglePanelIntent>(
            (_) => ctrl().togglePanel(),
            singleKey,
          ),
          PanelTabIntent: _ReaderAction<PanelTabIntent>(
            (i) => ctrl().setPanelTab(i.tab),
            singleKey,
          ),
          ReaderEscapeIntent: _ReaderAction<ReaderEscapeIntent>((_) {
            final handled = ctrl().escape(panelIsOverlay: panelIsOverlay);
            if (!handled && !textInputHasFocus()) onClose?.call();
          }, singleKey),
          CloseReaderIntent: _ReaderAction<CloseReaderIntent>(
            (_) => onClose?.call(),
            singleKey,
          ),
        },
        child: _ReaderFocus(focusNode: focusNode, child: child),
      ),
    );
  }
}

/// The reader's key-event focus. `autofocus` alone is not enough when the
/// reader is pushed over the library: the fade-through transition hides the
/// reader with `Visibility` (which excludes focus) for its first 40%, so
/// the route's scope ends up as primary focus and key events never reach
/// these shortcuts. This claims focus after mounting and again when the
/// route transition completes, whenever nothing inside the route is
/// focused yet.
class _ReaderFocus extends StatefulWidget {
  const _ReaderFocus({required this.child, this.focusNode});

  final Widget child;
  final FocusNode? focusNode;

  @override
  State<_ReaderFocus> createState() => _ReaderFocusState();
}

class _ReaderFocusState extends State<_ReaderFocus> {
  FocusNode? _own;

  FocusNode get _node => widget.focusNode ?? (_own ??= FocusNode());

  Animation<double>? _routeAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _claim());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.animation;
    if (identical(animation, _routeAnimation)) return;
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _routeAnimation = animation?..addStatusListener(_onRouteStatus);
  }

  void _onRouteStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _claim());
    }
  }

  void _claim() {
    if (!mounted || _node.hasFocus) return;
    final primary = FocusManager.instance.primaryFocus;
    // Only take focus from an enclosing scope, never from a real control
    // (text field, button) the user focused.
    if (primary == null ||
        (primary is FocusScopeNode && _node.ancestors.contains(primary))) {
      _node.requestFocus();
    }
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Focus(focusNode: _node, autofocus: true, child: widget.child);
}
