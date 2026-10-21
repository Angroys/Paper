import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/build_flags.dart';
import '../../core/format.dart';
import '../../core/immersive.dart';
import '../../data/data_providers.dart';
import '../../domain/domain.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/paper_tokens.dart';
import '../../theme/theme_x.dart';
import '../../ui/ui.dart';
import '../reader/reader_controller.dart';
import 'ai_states.dart';
import 'panel_session.dart';
import 'reader_side_panel.dart';

/// Autosave debounce for inline note editing (components.md NoteCard).
const Duration kNoteAutosaveDebounce = Duration(seconds: 1);

/// Notes of a paper (device-local in v1, option A).
final paperNotesProvider = StreamProvider.autoDispose
    .family<List<Note>, String>(
      (ref, paperId) => ref.watch(noteRepositoryProvider).watchNotes(paperId),
    );

/// New note ids (overridable in tests).
final noteIdFactoryProvider = Provider<String Function()>(
  (ref) => const Uuid().v4,
);

enum NotesSort { pageOrder, recent }

/// Notes tab: notes on highlights and free page notes, inline autosave,
/// delete with undo, a page-note composer, and the `NoteRequestedEvent`
/// draft.
class NotesTab extends ConsumerStatefulWidget {
  const NotesTab({super.key, required this.panel});

  final ReaderPanelContext panel;

  @override
  ConsumerState<NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends ConsumerState<NotesTab> {
  final TextEditingController _composer = TextEditingController();
  NotesSort _sort = NotesSort.pageOrder;

  /// Draft for a `NoteRequestedEvent` (a new note on that highlight). It
  /// stays pinned at the top while focused so autosave doesn't move it.
  Note? _draft;

  /// Existing note to focus for a request on an already-noted highlight.
  String? _focusNoteId;

  String get _paperId => widget.panel.paperId;

  @override
  void initState() {
    super.initState();
    ref.listenManual<Highlight?>(noteRequestProvider(_paperId), (_, next) {
      if (next != null) _consumeRequest();
    }, fireImmediately: true);
  }

  void _consumeRequest() {
    // Not during build: defer the state change.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final h = ref.read(noteRequestProvider(_paperId).notifier).take();
      if (h == null) return;
      final notes =
          ref.read(paperNotesProvider(_paperId)).value ?? const <Note>[];
      final existing = notes.where((n) => n.highlightId == h.id).firstOrNull;
      setState(() {
        if (existing != null) {
          _draft = null;
          _focusNoteId = existing.id;
        } else {
          final now = DateTime.now();
          _focusNoteId = null;
          _draft = Note(
            id: ref.read(noteIdFactoryProvider)(),
            paperId: _paperId,
            highlightId: h.id,
            pageNumber: h.position?.pageNumber ?? h.pageNumber,
            body: '',
            createdAt: now,
            updatedAt: now,
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _toast?.dismiss();
    _composer.dispose();
    super.dispose();
  }

  Future<void> _addPageNote() async {
    final body = _composer.text.trim();
    if (body.isEmpty) return;
    final now = DateTime.now();
    _composer.clear();
    await ref
        .read(noteRepositoryProvider)
        .upsertNote(
          Note(
            id: ref.read(noteIdFactoryProvider)(),
            paperId: _paperId,
            pageNumber: widget.panel.currentPage,
            body: body,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  PaperToastHandle? _toast;

  Future<void> _delete(Note note) async {
    final repo = ref.read(noteRepositoryProvider);
    final l10n = AppLocalizations.of(context);
    if (_draft?.id == note.id) setState(() => _draft = null);
    await repo.deleteNote(note.id);
    if (!mounted) return;
    _toast = showPaperToast(
      context,
      message: l10n.noteDeletedUndo,
      dismissTooltip: l10n.commonDismiss,
      actionLabel: l10n.undo,
      onAction: () => unawaited(repo.restoreNote(note)),
      duration: const Duration(seconds: 5),
    );
  }

  List<Note> _sorted(List<Note> notes) {
    final list = notes.toList();
    switch (_sort) {
      case NotesSort.pageOrder:
        list.sort((a, b) {
          final p = (a.pageNumber ?? 0).compareTo(b.pageNumber ?? 0);
          return p != 0 ? p : a.createdAt.compareTo(b.createdAt);
        });
      case NotesSort.recent:
        list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(paperNotesProvider(_paperId));
    final highlights = {
      for (final h
          in ref.watch(readerHighlightsProvider(_paperId)).value ??
              const <Highlight>[])
        h.id: h,
    };
    final offlineOnly = ref.watch(offlineOnlyProvider);

    // Toolbar: the sort as a small segmented control (replaces the popup).
    final toolbar = Align(
      alignment: AlignmentDirectional.centerStart,
      child: PaperSegmented<NotesSort>(
        size: PaperSegmentedSize.sm,
        selected: _sort,
        onChanged: (s) => setState(() => _sort = s),
        segments: <PaperSegment<NotesSort>>[
          PaperSegment(
            key: const ValueKey<String>('notes-sort-page'),
            value: NotesSort.pageOrder,
            label: l10n.notesSortPageOrder,
          ),
          PaperSegment(
            key: const ValueKey<String>('notes-sort-recent'),
            value: NotesSort.recent,
            label: l10n.notesSortRecent,
          ),
        ],
      ),
    );

    final composer = PaperCard(
      padding: const EdgeInsets.all(PaperSpacing.tw4),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _composer,
        builder: (context, value, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            PaperTextField(
              fieldKey: const ValueKey<String>('notes-composer'),
              controller: _composer,
              minLines: 1,
              maxLines: 6,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => unawaited(_addPageNote()),
              hintText: l10n.notesComposerPlaceholder(widget.panel.currentPage),
            ),
            const SizedBox(height: PaperSpacing.tw2),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: PaperButton.primary(
                key: const ValueKey<String>('notes-composer-save'),
                label: l10n.commonSave,
                size: PaperButtonSize.xs,
                focusGap: PaperWeb.gray900,
                onPressed: value.text.trim().isEmpty
                    ? null
                    : () => unawaited(_addPageNote()),
              ),
            ),
          ],
        ),
      ),
    );

    final draft = _draft;
    final children = <Widget>[
      toolbar,
      const SizedBox(height: PaperSpacing.tw3),
    ];
    if (async.hasError && !async.hasValue) {
      children.add(
        InlineError(
          message: l10n.notesLoadFailed,
          onRetry: () => ref.invalidate(paperNotesProvider(_paperId)),
        ),
      );
    } else if (async.hasValue) {
      final notes = _sorted(
        async.value!.where((n) => n.id != draft?.id).toList(),
      );
      children.add(composer);
      if (notes.isEmpty && draft == null) {
        children.add(
          PanelEmptyState(
            title: l10n.notesEmptyTitle,
            body: l10n.notesEmptyBody,
            scrollable: false,
          ),
        );
      } else {
        final cards = <Note>[?draft, ...notes];
        for (final note in cards) {
          final isDraft = identical(note, draft);
          children
            ..add(const SizedBox(height: PaperSpacing.tw3))
            ..add(
              NoteCard(
                key: ValueKey<String>('note-${note.id}'),
                note: note,
                highlight: highlights[note.highlightId],
                autofocus: isDraft || note.id == _focusNoteId,
                onJumpToHighlight: widget.panel.onJumpToHighlight,
                onDelete: () => unawaited(_delete(note)),
                onEditingDone: isDraft
                    ? () => setState(() {
                        if (_draft?.id == note.id) _draft = null;
                      })
                    : null,
              ),
            );
        }
        final anyLocal =
            !offlineOnly &&
            cards.any((n) => n.syncState == SyncState.localOnly);
        if (anyLocal) {
          children
            ..add(const SizedBox(height: PaperSpacing.tw3))
            ..add(
              Text(
                l10n.syncLocalOnlyExplainer,
                textAlign: TextAlign.center,
                style: PaperTypography.caption(context.paper),
              ),
            );
        }
      }
    }

    return ListView(
      key: const PageStorageKey<String>('panel-notes'),
      padding: SafeViewPadding.resolve(
        context,
        base: const EdgeInsets.all(PaperSpacing.tw4),
        left: false,
        top: false,
      ),
      children: children,
    );
  }
}

/// `NoteCard`: page label + overflow, quote anchor (tap = jump), inline
/// editable body (autosave, 1 s debounce), status footer. Device-local
/// notes carry `syncLocalOnlyBadge` (option A).
class NoteCard extends ConsumerStatefulWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.onJumpToHighlight,
    required this.onDelete,
    this.highlight,
    this.autofocus = false,
    this.onEditingDone,
  });

  final Note note;
  final Highlight? highlight;
  final bool autofocus;
  final ValueChanged<Highlight> onJumpToHighlight;
  final VoidCallback onDelete;

  /// Called when the editor loses focus (unpins a draft).
  final VoidCallback? onEditingDone;

  @override
  ConsumerState<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends ConsumerState<NoteCard> {
  late final TextEditingController _text = TextEditingController(
    text: widget.note.body,
  );
  final FocusNode _focus = FocusNode();
  Timer? _debounce;
  Note? _saved;
  bool _justSaved = false;

  /// Read once: the card may flush its last edit from [dispose], where
  /// `ref` must not be used.
  late final NoteRepository _repo;

  @override
  void initState() {
    super.initState();
    _repo = ref.read(noteRepositoryProvider);
    _focus.addListener(_onFocus);
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(NoteCard old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && widget.note.body != _text.text) {
      _text.text = widget.note.body;
    }
    if (widget.autofocus && !old.autofocus) _focus.requestFocus();
  }

  void _onFocus() {
    if (_focus.hasFocus) return;
    _flush();
    widget.onEditingDone?.call();
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(kNoteAutosaveDebounce, _flush);
    if (_justSaved) setState(() => _justSaved = false);
  }

  void _flush() {
    _debounce?.cancel();
    _debounce = null;
    final body = _text.text;
    final base = _saved ?? widget.note;
    if (body == base.body) return;
    // Never persist an empty draft.
    if (body.trim().isEmpty && base.body.isEmpty) return;
    final next = base.copyWith(body: body);
    _saved = next;
    unawaited(
      _repo.upsertNote(next).then((saved) {
        _saved = saved;
        if (mounted) setState(() => _justSaved = true);
      }),
    );
  }

  @override
  void dispose() {
    if (_debounce?.isActive ?? false) _flush();
    _debounce?.cancel();
    _focus
      ..removeListener(_onFocus)
      ..dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.paper;
    final l10n = AppLocalizations.of(context);
    final note = widget.note;
    final h = widget.highlight;
    final page = note.pageNumber ?? h?.position?.pageNumber ?? h?.pageNumber;
    final quote = h?.selectedText ?? note.quotedExcerpt;
    final hue = PaperHighlightColor.values.byName(
      (h?.color ?? HighlightColor.defaultColor).name,
    );

    // Offline-only builds: no sync wording, just "Saved" / "Edited …".
    final syncState = ref.watch(offlineOnlyProvider)
        ? SyncState.synced
        : note.syncState;
    final edited = _justSaved
        ? l10n.noteSaved
        : l10n.notesEditedAgo(formatWhen(context, note.updatedAt));
    final Widget? chip = switch (syncState) {
      SyncState.localOnly => Tooltip(
        message: l10n.syncLocalOnlyExplainer,
        child: PaperBadge(
          label: l10n.syncLocalOnlyBadge,
          tone: PaperBadgeTone.neutral,
        ),
      ),
      SyncState.pendingCreate ||
      SyncState.pendingUpdate ||
      SyncState.pendingDelete => PaperBadge(
        label: l10n.notesPendingSync,
        tone: PaperBadgeTone.neutral,
      ),
      SyncState.failed => PaperBadge(
        label: l10n.notesSyncFailed,
        tone: PaperBadgeTone.error,
      ),
      SyncState.synced => null,
    };

    return PaperCard(
      padding: const EdgeInsets.all(PaperSpacing.tw4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (quote != null && quote.isNotEmpty) ...<Widget>[
            Semantics(
              button: h != null,
              hint: h != null ? l10n.noteJumpToHighlight : null,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: h == null ? null : () => widget.onJumpToHighlight(h),
                child: Container(
                  padding: const EdgeInsets.only(left: PaperSpacing.tw2),
                  decoration: BoxDecoration(
                    border: Border(left: BorderSide(color: hue.ring, width: 2)),
                  ),
                  child: Text(
                    quote,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: PaperTypography.caption(c)
                        .copyWith(height: PaperTypography.relaxed),
                  ),
                ),
              ),
            ),
            const SizedBox(height: PaperSpacing.tw2),
          ],
          TextField(
            key: ValueKey<String>('note-body-${note.id}'),
            controller: _text,
            focusNode: _focus,
            maxLines: null,
            onChanged: _onChanged,
            style: PaperTypography.noteBody(c),
            cursorColor: PaperWeb.accent,
            decoration: InputDecoration(
              isDense: true,
              hintText: l10n.noteInlinePlaceholder,
              hintStyle: PaperTypography.noteBody(c)
                  .copyWith(color: PaperWeb.gray500),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: PaperSpacing.tw3),
          Row(
            children: <Widget>[
              Expanded(
                child: Wrap(
                  spacing: PaperSpacing.tw2,
                  runSpacing: PaperSpacing.tw1,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(
                      page == null
                          ? edited
                          : '${l10n.highlightPageLabel(page)} · $edited',
                      style: PaperTypography.caption(c),
                    ),
                    ?chip,
                  ],
                ),
              ),
              MenuAnchor(
                alignmentOffset: const Offset(0, 4),
                menuChildren: <Widget>[
                  if (h != null)
                    PaperMenuItem(
                      label: l10n.noteJumpToHighlight,
                      onPressed: () => widget.onJumpToHighlight(h),
                    ),
                  PaperMenuItem(
                    label: l10n.noteDelete,
                    destructive: true,
                    onPressed: widget.onDelete,
                  ),
                ],
                builder: (context, menu, _) => PaperButton.ghost(
                  label: '···',
                  size: PaperButtonSize.xs,
                  tooltip: l10n.commonMore,
                  open: menu.isOpen,
                  focusGap: PaperWeb.gray900,
                  onPressed: () => menu.isOpen ? menu.close() : menu.open(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
