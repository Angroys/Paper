import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../auth/auth_providers.dart';
import '../../../core/build_flags.dart';
import '../../../core/core_providers.dart';
import '../../../data/data_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/paper_tokens.dart';
import '../../../theme/theme_x.dart';
import '../../../ui/ui.dart';
import '../../auth/sign_in_prompt.dart';
import '../reader_controller.dart';

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
    // Guests: importing fetches the paper on the server; ask to sign in.
    if (ref.read(isGuestProvider)) {
      return showSignInPromptDialog(context, GuestFeature.importLink);
    }
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
    final target = widget.target;
    final online = ref.watch(isOnlineProvider).value ?? true;
    // Offline-only builds: no "Import" (it fetches the paper by URL).
    final canImport = !ref.watch(offlineOnlyProvider);
    final ctrl = ref.read(readerControllerProvider(widget.paperId).notifier);
    final url = target.url;

    final children = <Widget>[
      // Header: `mb-2 flex items-start justify-between gap-2`.
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Semantics(
              header: true,
              child: Text(target.label, style: PaperTypography.cardTitle(c)),
            ),
          ),
          const SizedBox(width: PaperSpacing.tw2),
          Transform.translate(
            offset: const Offset(4, -4),
            child: PaperIconButton(
              size: PaperIconButtonSize.s24,
              tooltip: l10n.commonClose,
              icon: const PaperCloseGlyph(),
              onPressed: ctrl.dismissCitation,
            ),
          ),
        ],
      ),
      const SizedBox(height: PaperSpacing.tw2),
    ];
    if (target.resolving) {
      children.add(
        Text(
          l10n.citationLoading,
          style: _sm.copyWith(
            fontStyle: FontStyle.italic,
            color: PaperWeb.gray400,
          ),
        ),
      );
    } else {
      final text = target.referenceText;
      children.add(
        text != null
            ? Text(text, style: PaperTypography.explanationBodyCompact(c))
            : Text(
                l10n.citationNotFound,
                style: _sm.copyWith(
                  fontStyle: FontStyle.italic,
                  color: PaperWeb.gray400,
                ),
              ),
      );
      final actions = <Widget>[];
      if (!online) {
        actions.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const PaperIcon(PaperIcons.infoSmall, color: PaperWeb.gray400),
              const SizedBox(width: PaperSpacing.tw1),
              Expanded(child: Text(l10n.citationOfflineHint, style: _xs)),
            ],
          ),
        );
      } else if (url != null) {
        if (_import == _ImportState.imported) {
          actions.add(
            Text(
              l10n.citationImported,
              style: _xs.copyWith(
                fontWeight: FontWeight.w500,
                color: PaperWeb.green400,
              ),
            ),
          );
        }
        if (_import == _ImportState.failed) {
          actions.add(
            Text(
              l10n.citationImportFailed,
              style: _xs.copyWith(color: PaperWeb.red400),
            ),
          );
        }
        if (_import == _ImportState.importing) {
          actions.add(
            Row(
              children: <Widget>[
                const PaperSpinner(),
                const SizedBox(width: PaperSpacing.tw2),
                Text(l10n.commonLoading, style: _xs),
              ],
            ),
          );
        }
        actions.add(
          Wrap(
            spacing: PaperSpacing.tw3,
            runSpacing: PaperSpacing.tw2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              if (canImport && _import != _ImportState.imported)
                _CiteAddButton(
                  label: _import == _ImportState.failed
                      ? l10n.commonRetry
                      : l10n.citationImport,
                  onPressed: _import == _ImportState.importing
                      ? null
                      : () => unawaited(_importPaper(url)),
                ),
              _TextLink(
                label: '${l10n.citationOpenLink} ↗',
                onPressed: () => unawaited(
                  launchUrl(url, mode: LaunchMode.externalApplication),
                ),
              ),
            ],
          ),
        );
      }
      final page = target.targetPage;
      if (page != null) {
        actions.add(
          _TextLink(
            label: '${l10n.citationGoToReference} ↓',
            onPressed: () => ctrl.goToReference(page),
          ),
        );
      }
      for (final w in actions) {
        children
          ..add(const SizedBox(height: PaperSpacing.tw2))
          ..add(w);
      }
    }

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      label: target.label,
      child: Container(
        width: 320,
        constraints: const BoxConstraints(maxHeight: 320),
        decoration: BoxDecoration(
          color: PaperWeb.gray900,
          border: Border.all(color: PaperWeb.gray700),
          borderRadius: PaperRadii.borderLg,
          boxShadow: PaperElevation.shadowXl,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(PaperSpacing.tw4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ),
    );
  }
}

const TextStyle _sm = TextStyle(
  fontFamily: PaperTypography.sans,
  fontFamilyFallback: PaperTypography.sansFallback,
  fontSize: 14,
  height: 20 / 14,
);

const TextStyle _xs = TextStyle(
  fontFamily: PaperTypography.sans,
  fontFamilyFallback: PaperTypography.sansFallback,
  fontSize: 12,
  height: 16 / 12,
  color: PaperWeb.gray400,
);

/// `CITE_ADD_BUTTON_CLASS`: accent fill (hover accent-hover), `px-2.5
/// py-1 xs 500` indigo-950, radius 6, shadow-sm, 24 tall; disabled @ .6.
class _CiteAddButton extends StatelessWidget {
  const _CiteAddButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => PaperPressable(
    onPressed: onPressed,
    semanticLabel: label,
    excludeSemantics: true,
    builder: (context, states) {
      final active =
          states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.pressed);
      final disabled = states.contains(WidgetState.disabled);
      final fill = active ? PaperWeb.accentHover : PaperWeb.accent;
      return PaperFocusRing(
        show: states.contains(WidgetState.focused),
        radius: PaperRadii.borderMd,
        gap: PaperWeb.gray900,
        child: PaperColorBox(
          color: disabled ? fill.withValues(alpha: 0.6) : fill,
          radius: PaperRadii.borderMd,
          boxShadow: PaperElevation.shadowSm,
          constraints: const BoxConstraints.tightFor(height: 24),
          padding: const EdgeInsets.symmetric(horizontal: PaperSpacing.tw2_5),
          alignment: Alignment.center,
          child: Text(
            label,
            style: _xs.copyWith(
              fontWeight: FontWeight.w500,
              color: PaperWeb.indigo950.withValues(alpha: disabled ? 0.6 : 1),
            ),
          ),
        ),
      );
    },
  );
}

/// Link-out / jump (`xs 500 accent`, hover underline, focus ring 2).
class _TextLink extends StatelessWidget {
  const _TextLink({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => PaperPressable(
    onPressed: onPressed,
    semanticLabel: label,
    excludeSemantics: true,
    builder: (context, states) {
      final hover =
          states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.pressed);
      return PaperFocusRing(
        show: states.contains(WidgetState.focused),
        radius: PaperRadii.borderMd,
        gap: PaperWeb.gray900,
        child: Text(
          label,
          style: _xs.copyWith(
            fontWeight: FontWeight.w500,
            color: hover ? PaperWeb.accentHover : PaperWeb.accent,
            decoration: hover ? TextDecoration.underline : null,
            decorationColor: PaperWeb.accentHover,
          ),
        ),
      );
    },
  );
}
