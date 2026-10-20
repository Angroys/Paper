import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/build_flags.dart';
import '../../../core/core_providers.dart';
import '../../../data/data_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/paper_tokens.dart';
import '../../../theme/theme_x.dart';
import '../reader_controller.dart';
import 'popover.dart';

enum _ImportState { idle, importing, imported, failed }

/// `CitationPopover` (components.md): marker, parsed reference text, actions
/// (Add to library / Open link when the PDF links out and we're online) and
/// "Go to reference". Loading -> content swaps instantly (motion #10).
class CitationPopover extends ConsumerStatefulWidget {
  const CitationPopover({
    super.key,
    required this.paperId,
    required this.target,
  });

  final String paperId;
  final ReaderCitationTarget target;

  @override
  ConsumerState<CitationPopover> createState() => _CitationPopoverState();
}

class _CitationPopoverState extends ConsumerState<CitationPopover> {
  _ImportState _import = _ImportState.idle;

  Future<void> _importPaper(Uri url) async {
    setState(() => _import = _ImportState.importing);
    try {
      await ref.read(paperRepositoryProvider).importFromUrl(url);
      if (mounted) setState(() => _import = _ImportState.imported);
    } on Object {
      if (mounted) setState(() => _import = _ImportState.failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.paper;
    final t = Theme.of(context).textTheme;
    final target = widget.target;
    final online = ref.watch(isOnlineProvider).value ?? true;
    // Offline-only builds: no "Import" (it fetches the paper by URL).
    final canImport = !ref.watch(offlineOnlyProvider);
    final ctrl = ref.read(readerControllerProvider(widget.paperId).notifier);
    final url = target.url;

    final children = <Widget>[
      Semantics(
        header: true,
        child: Text(
          target.label.toUpperCase(),
          style: PaperTypography.popoverTitle(c),
        ),
      ),
      const SizedBox(height: PaperSpacing.xs),
    ];
    if (target.resolving) {
      children.add(
        Semantics(
          label: l10n.citationLoading,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final w in <double>[1, 0.9, 0.6])
                Padding(
                  padding: const EdgeInsets.only(top: PaperSpacing.xs),
                  child: FractionallySizedBox(
                    widthFactor: w,
                    child: SizedBox(
                      height: 10,
                      child: ColoredBox(color: c.surfaceVariant),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    } else {
      final text = target.referenceText;
      if (text != null) {
        children.add(
          Text(
            text,
            style: t.bodySmall?.copyWith(color: c.textPrimary),
            maxLines: 8,
            overflow: TextOverflow.ellipsis,
          ),
        );
      } else {
        children.add(
          Text(
            l10n.citationNotFound,
            style: t.bodySmall?.copyWith(color: c.textMuted),
          ),
        );
      }
      if (!online) {
        children.addAll(<Widget>[
          const SizedBox(height: PaperSpacing.sm),
          Row(
            children: <Widget>[
              Icon(Symbols.cloud_off_rounded, size: 16, color: c.textMuted),
              const SizedBox(width: PaperSpacing.xs),
              Expanded(
                child: Text(
                  l10n.citationOfflineHint,
                  style: t.labelSmall?.copyWith(color: c.textMuted),
                ),
              ),
            ],
          ),
        ]);
      } else if (url != null) {
        children.addAll(<Widget>[
          const SizedBox(height: PaperSpacing.sm),
          if (_import == _ImportState.imported)
            _status(
              context,
              Symbols.check_circle_rounded,
              c.success,
              l10n.citationImported,
            ),
          if (_import == _ImportState.failed)
            _status(
              context,
              Symbols.error_rounded,
              c.error,
              l10n.citationImportFailed,
            ),
          Wrap(
            spacing: PaperSpacing.sm,
            runSpacing: PaperSpacing.xs,
            children: <Widget>[
              if (canImport && _import != _ImportState.imported)
                FilledButton(
                  onPressed: _import == _ImportState.importing
                      ? null
                      : () => unawaited(_importPaper(url)),
                  child: Text(
                    _import == _ImportState.failed
                        ? l10n.commonRetry
                        : l10n.citationImport,
                  ),
                ),
              OutlinedButton.icon(
                onPressed: () => unawaited(
                  launchUrl(url, mode: LaunchMode.externalApplication),
                ),
                icon: const Icon(Symbols.open_in_new_rounded, size: 16),
                label: Text(l10n.citationOpenLink),
              ),
            ],
          ),
        ]);
      }
      final page = target.targetPage;
      if (page != null) {
        children.addAll(<Widget>[
          const SizedBox(height: PaperSpacing.sm),
          Divider(height: 1, color: c.divider),
          InkWell(
            onTap: () => ctrl.goToReference(page),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: PaperSpacing.sm),
              child: Row(
                children: <Widget>[
                  Icon(Symbols.south_rounded, size: 16, color: c.primary),
                  const SizedBox(width: PaperSpacing.xs),
                  Expanded(
                    child: Text(
                      l10n.citationGoToReference,
                      style: t.labelLarge?.copyWith(color: c.primary),
                    ),
                  ),
                  Text(
                    '$page',
                    style: PaperTypography.pageIndicator(c)
                        .copyWith(color: c.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ]);
      }
    }

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      label: target.label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: PopoverSurface(
          accentBar: true,
          padding: const EdgeInsets.fromLTRB(18, 12, 14, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _status(
    BuildContext context,
    IconData icon,
    Color color,
    String text,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: PaperSpacing.xs),
    child: Row(
      children: <Widget>[
        Icon(icon, size: 16, color: color),
        const SizedBox(width: PaperSpacing.xs),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: color),
          ),
        ),
      ],
    ),
  );
}
