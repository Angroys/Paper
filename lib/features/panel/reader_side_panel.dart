import 'package:flutter/widgets.dart';

/// Side panel tabs (Notes · Glossary · Explanation).
enum ReaderPanelTab { notes, glossary, explanation }

/// PLACEHOLDER (reader agent): ReaderSidePanel per
/// design/specs/screens/reader-side-panel.md. Must sit in its own
/// RepaintBoundary (motion.md §1.4, B6).
class ReaderSidePanel extends StatelessWidget {
  const ReaderSidePanel({
    super.key,
    required this.paperId,
    this.tab = ReaderPanelTab.notes,
  });

  final String paperId;
  final ReaderPanelTab tab;

  @override
  Widget build(BuildContext context) =>
      const RepaintBoundary(child: SizedBox.expand());
}
