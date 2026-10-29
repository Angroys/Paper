import 'package:flutter/material.dart';

import '../theme/paper_tokens.dart';
import 'paper_card.dart';

/// Shows [builder] (normally a [PaperDialog]) over the web dialog backdrop
/// (#0A0A0A @ 60%, no blur). It mounts instantly like the web dialog;
/// Escape / barrier tap dismiss; focus is trapped by the route.
Future<T?> showPaperDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  String? barrierLabel,
  bool useRootNavigator = true,
}) => showGeneralDialog<T>(
  context: context,
  barrierDismissible: barrierDismissible,
  barrierLabel:
      barrierLabel ??
      MaterialLocalizations.of(context).modalBarrierDismissLabel,
  barrierColor: PaperWeb.dialogBackdrop,
  useRootNavigator: useRootNavigator,
  transitionDuration: Duration.zero,
  pageBuilder: (context, _, _) => builder(context),
);

/// The web dialog card (components.md §14): `.card` + shadow-xl, max 448
/// wide, `p-5`; title `cardTitle`, body `mt-2 sm gray-400`, extra content
/// `mt-4`, actions `mt-5 flex justify-end gap-3` (md buttons, pass
/// `focusGap: PaperWeb.gray900`).
class PaperDialog extends StatelessWidget {
  const PaperDialog({
    super.key,
    required this.title,
    this.body,
    this.content,
    this.actions = const <Widget>[],
    this.maxWidth = PaperBreakpoints.maxWMd,
  });

  final String title;

  /// Plain body text (`sm gray-400`).
  final String? body;

  /// Fields, checkbox rows, errors… below the body (`mt-4`).
  final Widget? content;
  final List<Widget> actions;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final pad = MediaQuery.viewPaddingOf(context);
    final ime = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24 + pad.left,
        24 + pad.top,
        24 + pad.right,
        24 + (ime > pad.bottom ? ime : pad.bottom),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Material(
            type: MaterialType.transparency,
            child: Semantics(
              scopesRoute: true,
              namesRoute: true,
              explicitChildNodes: true,
              label: title,
              child: PaperCard(
                kind: PaperSurfaceKind.dialog,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        title,
                        style: PaperTypography.cardTitle(PaperColors.dark),
                      ),
                      if (body != null) ...<Widget>[
                        const SizedBox(height: PaperSpacing.tw2),
                        Text(
                          body!,
                          style: t.bodyMedium?.copyWith(
                            color: PaperWeb.gray400,
                          ),
                        ),
                      ],
                      if (content != null) ...<Widget>[
                        const SizedBox(height: PaperSpacing.tw4),
                        content!,
                      ],
                      if (actions.isNotEmpty) ...<Widget>[
                        const SizedBox(height: PaperSpacing.tw5),
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: PaperSpacing.tw3,
                          runSpacing: PaperSpacing.tw2,
                          children: actions,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
