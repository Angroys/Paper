import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/paper_tokens.dart';
import 'paper_button.dart';
import 'paper_card.dart';
import 'paper_icon.dart';
import 'paper_icon_button.dart';
import 'paper_progress.dart';

/// Toast status icon (components.md §15).
enum PaperToastTone {
  /// No icon; `xs gray-400` message ("Added to your library.").
  plain,

  /// `toast-check.svg` green-400 + headline.
  success,

  /// `toast-error.svg` red-400 + headline.
  error,

  /// Spinner, body row only, never auto-dismissed.
  loading,
}

/// Handle returned by [showPaperToast].
class PaperToastHandle {
  PaperToastHandle._(this._entry);

  final OverlayEntry _entry;
  Timer? _timer;
  bool _closed = false;

  bool get isOpen => !_closed;

  void dismiss() {
    if (_closed) return;
    _closed = true;
    _timer?.cancel();
    _entry.remove();
    if (identical(_current, this)) _current = null;
  }
}

PaperToastHandle? _current;

/// Shows the web toast (`CiteAddToast` box) bottom-right, 24 from the
/// inset edges. One at a time: the newest replaces the current one.
///
/// Success / plain toasts without an action auto-dismiss after 2 s; with
/// an action pass the undo window as [duration]. Hovering pauses the timer.
/// [message] is the headline for success/error and the whole text for
/// plain; [detail] is an optional `xs gray-400` line.
PaperToastHandle showPaperToast(
  BuildContext context, {
  required String message,
  required String dismissTooltip,
  String? detail,
  PaperToastTone tone = PaperToastTone.plain,
  String? actionLabel,
  VoidCallback? onAction,
  Duration? duration,
}) {
  _current?.dismiss();
  final overlay = Overlay.of(context, rootOverlay: true);
  late final PaperToastHandle handle;
  final effective =
      duration ??
      (tone == PaperToastTone.loading ? null : const Duration(seconds: 2));
  void arm() {
    handle._timer?.cancel();
    if (effective != null) handle._timer = Timer(effective, handle.dismiss);
  }

  final entry = OverlayEntry(
    builder: (context) {
      final inset = MediaQuery.viewPaddingOf(context);
      return Positioned(
        right: 24 + inset.right,
        bottom: 24 + inset.bottom,
        child: MouseRegion(
          onEnter: (_) => handle._timer?.cancel(),
          onExit: (_) => arm(),
          child: PaperToast(
            message: message,
            detail: detail,
            tone: tone,
            actionLabel: actionLabel,
            dismissTooltip: dismissTooltip,
            onAction: onAction == null
                ? null
                : () {
                    handle.dismiss();
                    onAction();
                  },
            onDismiss: handle.dismiss,
          ),
        ),
      );
    },
  );
  handle = PaperToastHandle._(entry);
  _current = handle;
  overlay.insert(entry);
  arm();
  return handle;
}

/// The toast box itself (for custom placement and tests).
class PaperToast extends StatelessWidget {
  const PaperToast({
    super.key,
    required this.message,
    required this.dismissTooltip,
    this.detail,
    this.tone = PaperToastTone.plain,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
  });

  final String message;
  final String? detail;
  final PaperToastTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;
  final String dismissTooltip;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final Widget? icon = switch (tone) {
      PaperToastTone.plain => null,
      PaperToastTone.success => const PaperIcon(
        PaperIcons.toastCheck,
        color: PaperWeb.green400,
      ),
      PaperToastTone.error => const PaperIcon(
        PaperIcons.toastError,
        color: PaperWeb.red400,
      ),
      PaperToastTone.loading => const PaperSpinner(),
    };
    final headline = tone == PaperToastTone.plain
        ? t.bodySmall?.copyWith(color: PaperWeb.gray400)
        : t.titleSmall?.copyWith(color: PaperWeb.gray100);
    final body = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Padding(padding: const EdgeInsets.only(top: 2), child: icon),
          const SizedBox(width: PaperSpacing.tw2),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(message, style: headline),
              if (detail != null)
                Text(
                  detail!,
                  style: t.bodySmall?.copyWith(
                    color: tone == PaperToastTone.error
                        ? PaperWeb.red400
                        : PaperWeb.gray400,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
    return Semantics(
      liveRegion: true,
      container: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 240, maxWidth: 320),
        child: PaperCard(
          kind: PaperSurfaceKind.toast,
          padding: const EdgeInsets.all(PaperSpacing.tw3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              body,
              if (tone != PaperToastTone.loading) ...<Widget>[
                const SizedBox(height: PaperSpacing.tw3),
                Row(
                  children: <Widget>[
                    if (actionLabel != null)
                      PaperButton.primary(
                        label: actionLabel!,
                        size: PaperButtonSize.sm,
                        focusGap: PaperWeb.gray900,
                        onPressed: onAction,
                      ),
                    const Spacer(),
                    PaperIconButton(
                      tooltip: dismissTooltip,
                      icon: const PaperCloseGlyph(),
                      onPressed: onDismiss,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
