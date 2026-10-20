import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:uuid/uuid.dart';

import '../../core/build_flags.dart';
import '../../core/format.dart';
import '../../data/data_providers.dart';
import '../../domain/domain.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/paper_tokens.dart';
import '../../theme/theme_x.dart';
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

  Future<void> _delete(Note note) async {
    final repo = ref.read(noteRepositoryProvider);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = AppLocalizations.of(context);
    if (_draft?.id == note.id) setState(() => _draft = null);
    await repo.deleteNote(note.id);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.noteDeletedUndo),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () => unawaited(repo.restoreNote(note)),
          ),
        ),
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
    final c = context.paper;
    final t = Theme.of(context).textTheme;
    final async = ref.watch(paperNotesProvider(_paperId));
    final highlights = {
      for (final h
          in ref.watch(readerHighlightsProvider(_paperId)).value ??
              const <Highlight>[])
        h.id: h,
    };

    final draft = _draft;
    final Widget body;
    if (async.hasError && !async.hasValue) {
      body = Padding(
        padding: const EdgeInsets.all(PaperSpacing.panePadding),
        child: Align(
          alignment: Alignment.topCenter,
          child: InlineError(
            message: l10n.notesLoadFailed,
            onRetry: () => ref.invalidate(paperNotesProvider(_paperId)),
          ),
        ),
      );
    } else if (!async.hasValue) {
      body = const SizedBox.shrink();
    } else {
      final notes = _sorted(
        async.value!.where((n) => n.id != draft?.id).toList(),
      );
      if (notes.isEmpty && draft == null) {
        body = PanelEmptyState(
          icon: Symbols.sticky_note_2_rounded,
          title: l10n.notesEmptyTitle,
          body: l10n.notesEmptyBody,
        );
      } else {
        final cards = <Note>[?draft, ...notes];
        body = ListView.separated(
          key: const PageStorageKey<String>('panel-notes'),
          padding: const EdgeInsets.all(PaperSpacing.panePadding),
          itemCount: cards.length,
          separatorBuilder: (_, _) => const SizedBox(height: PaperSpacing.md),
          itemBuilder: (context, i) {
            final note = cards[i];
            final isDraft = identical(note, draft);
            return NoteCard(
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
            );
          },
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            PaperSpacing.panePadding,
            PaperSpacing.sm,
            PaperSpacing.sm,
            0,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${l10n.librarySortLabel}: ${_sort == NotesSort.pageOrder ? l10n.notesSortPageOrder : l10n.notesSortRecent}',
                  style: t.bodySmall?.copyWith(color: c.textMuted),
                ),
              ),
              PopupMenuButton<NotesSort>(
                tooltip: l10n.librarySortLabel,
                icon: const Icon(Symbols.sort_rounded, size: 20),
                initialValue: _sort,
                onSelected: (s) => setState(() => _sort = s),
                itemBuilder: (context) => <PopupMenuEntry<NotesSort>>[
                  PopupMenuItem(
                    value: NotesSort.pageOrder,
                    child: Text(l10n.notesSortPageOrder),
                  ),
                  PopupMenuItem(
                    value: NotesSort.recent,
                    child: Text(l10n.notesSortRecent),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(child: body),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: c.border)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(PaperSpacing.md),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    key: const ValueKey<String>('notes-composer'),
                    controller: _composer,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => unawaited(_addPageNote()),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: l10n.notesComposerPlaceholder(
                        widget.panel.currentPage,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: PaperSpacing.sm),
                IconButton.filled(
                  tooltip: l10n.commonSave,
                  onPressed: () => unawaited(_addPageNote()),
                  icon: const Icon(Symbols.add_rounded, size: 20),
                ),
              ],
            ),
          ),
        ),
      ],
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
    final t = Theme.of(context).textTheme;
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
    final Widget status = switch (syncState) {
      SyncState.localOnly => Tooltip(
        message: l10n.syncLocalOnlyExplainer,
        child: _Footer(
          icon: Symbols.devices_rounded,
          color: c.textMuted,
          text: _justSaved
              ? '${l10n.noteSaved} · ${l10n.syncLocalOnlyBadge}'
              : l10n.syncLocalOnlyBadge,
        ),
      ),
      SyncState.pendingCreate ||
      SyncState.pendingUpdate ||
      SyncState.pendingDelete => _Footer(
        icon: Symbols.cloud_upload_rounded,
        color: c.statusSyncPending,
        text: l10n.notesPendingSync,
      ),
      SyncState.failed => _Footer(
        icon: Symbols.warning_rounded,
        color: c.error,
        text: l10n.notesSyncFailed,
      ),
      SyncState.synced => _Footer(
        icon: Symbols.check_rounded,
        color: c.textMuted,
        text: _justSaved
            ? l10n.noteSaved
            : l10n.notesEditedAgo(formatWhen(context, note.updatedAt)),
      ),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: PaperRadii.borderLg,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          PaperSpacing.lg,
          PaperSpacing.sm,
          PaperSpacing.xs,
          PaperSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    page == null ? '' : 'p. $page',
                    style: PaperTypography.pageIndicator(c)
                        .copyWith(color: c.textMuted),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: l10n.commonMore,
                  icon: const Icon(Symbols.more_vert_rounded, size: 18),
                  onSelected: (v) {
                    if (v == 'jump' && h != null) widget.onJumpToHighlight(h);
                    if (v == 'delete') widget.onDelete();
                  },
                  itemBuilder: (context) => <PopupMenuEntry<String>>[
                    if (h != null)
                      PopupMenuItem(
                        value: 'jump',
                        child: Text(l10n.noteJumpToHighlight),
                      ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        l10n.noteDelete,
                        style: TextStyle(color: c.error),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (quote != null && quote.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(
                  right: PaperSpacing.md,
                  bottom: PaperSpacing.sm,
                ),
                child: Semantics(
                  button: h != null,
                  hint: h != null ? l10n.noteJumpToHighlight : null,
                  child: InkWell(
                    onTap: h == null ? null : () => widget.onJumpToHighlight(h),
                    child: Container(
                      padding: const EdgeInsets.only(left: PaperSpacing.sm),
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(color: hue.wash, width: 3),
                        ),
                      ),
                      child: Text(
                        quote,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodyMedium?.copyWith(
                          fontSize: 13,
                          color: c.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(right: PaperSpacing.md),
              child: TextField(
                key: ValueKey<String>('note-body-${note.id}'),
                controller: _text,
                focusNode: _focus,
                maxLines: null,
                onChanged: _onChanged,
                style: PaperTypography.noteBody(c),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: l10n.noteInlinePlaceholder,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            const SizedBox(height: PaperSpacing.sm),
            status,
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Icon(icon, size: 16, color: color),
      const SizedBox(width: PaperSpacing.xs),
      Flexible(
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: context.paper.textMuted),
        ),
      ),
    ],
  );
}
