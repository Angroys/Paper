import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app/routes.dart';
import '../../l10n/app_localizations.dart';

/// PLACEHOLDER (reader agent): pdfrx reader per
/// design/specs/screens/reader.md and the motion.md §1 perf contract.
class ReaderScreen extends StatelessWidget {
  const ReaderScreen({super.key, required this.paperId});

  final String paperId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.readerBack,
          icon: const Icon(Symbols.arrow_back_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.library),
        ),
        title: Text(paperId, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: const SizedBox.expand(),
    );
  }
}
