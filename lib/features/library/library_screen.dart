import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/paper_tokens.dart';
import '../../theme/theme_x.dart';

/// PLACEHOLDER (feature-screens agent): library per
/// design/specs/screens/library.md. Shows the empty state for now.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final windowClass = PaperWindowClass.ofContext(context);
    final margin = PaperSpacing.margin(windowClass);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: margin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: PaperSpacing.xl),
          Semantics(
            header: true,
            child: Text(
              l10n.libraryTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Symbols.description_rounded,
                    size: 48,
                    color: context.paper.textMuted,
                  ),
                  const SizedBox(height: PaperSpacing.lg),
                  Text(
                    l10n.libraryEmptyTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: PaperSpacing.sm),
                  Text(l10n.libraryEmptyBody, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
