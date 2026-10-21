/// Outbox sync engine: local-first writes are pushed to Supabase, then the
/// server state is pulled and merged into SQLite.
///
/// # What syncs (option A, design/specs/flows.md "Data-model gap")
///
/// | Data                          | Synced          | Conflict rule        |
/// | ----------------------------- | --------------- | -------------------- |
/// | paper create / rename / read / match-notice / delete | yes | local pending wins, see 2 |
/// | text highlight create/delete  | yes             | none possible (immutable rows) |
/// | figure highlight create/delete| yes             | none possible        |
/// | figure note                   | yes             | LWW on `updated_at`, see 3 |
/// | highlight colour, notes, reading position, last opened | never (device-only) | n/a |
///
/// Device-only data never enters the outbox and never counts as pending.
///
/// # Rules
///
/// 1. **Outbox.** Every synced local write stores the row in SQLite and
///    appends a `SyncOp` (client-generated UUID ids for rows and ops, so
///    replays are idempotent: creates are upserts / insert-or-ignore,
///    deletes of missing rows succeed). Ops push oldest first. An `update`
///    queued while an un-attempted `create`/`update` of the same row is
///    waiting is merged into it. Ops of a row with a queued `delete` are
///    held until the delete is due (a paper delete waits out the 10 s undo
///    window); a delete of a row whose `create` never reached the server
///    cancels both locally. Ops of a paper whose `create` is still queued
///    wait for it (foreign keys).
/// 2. **Papers** have no server `updated_at`, so per-row LWW by timestamp is
///    impossible: while a paper has queued ops the local row wins the pull
///    (the push then overwrites the server = last push wins); otherwise the
///    server row replaces the local server columns. A paper missing from
///    the server that is not pending locally was deleted elsewhere and is
///    removed from this device with its highlights, notes and cache. A
///    queued update for a paper the server no longer has fails
///    (`NotFoundException` -> SyncSheet "paper was deleted", Discard).
/// 3. **Figure notes: last write wins per row by `updated_at`.** The op
///    carries the server `updated_at` the edit was based on. At push time
///    the server row is read: if it has not changed since that base, the
///    local edit is pushed; if it has, the newer of (server `updated_at`,
///    local edit time) wins. When the server wins, the local value is
///    saved to `replaced_versions` (kept 30 days, "Restore mine" writes it
///    again as the newest edit) and the server row is applied. After a push
///    the server-assigned `updated_at` becomes the local clock, so final
///    ordering uses server time; device time only matters when both sides
///    changed (documented clock-skew limitation).
/// 4. **Server-deleted highlight with local notes**: the notes become free
///    page notes quoting the highlight text, and the highlight is recorded
///    in `replaced_versions` (Restore re-creates it).
/// 5. **Errors.** Offline / 5xx / timeouts: the op stays, `attempts` grows
///    and it waits `min(2 s * 2^attempts, 5 min)`; the round stops so order
///    is kept. 401 / expired session: the round stops, status is
///    `error + authExpired`, the outbox is kept for the same user. Other
///    4xx and missing rows: the op is marked failed (SyncSheet: Retry /
///    Discard) and the round continues.
/// 6. **Triggers**: `start()`, reconnect (connectivity + ping), every
///    5 min, app resume, 2 s after a local write, `syncNow()`.
/// 7. **Accounts**: sign-in is optional. Without an account, writes are
///    owned by the guest (`kGuestUserId`) and wait in the outbox; nothing
///    is pushed. Before every round with a signed-in user the DB is made
///    theirs (`GuestDataMerge`, lib/sync/guest_merge.dart): another
///    account's rows are removed, guest rows and queued payloads are
///    re-owned (`<user_id>/...` storage paths) and queued. The DB remembers
///    its last owner (`db_owner_user_id`).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../core/streams.dart';
import '../data/db/app_database.dart';
import '../data/db/converters.dart';
import '../data/local_store.dart';
import '../data/mappers.dart';
import '../data/remote/remote_data_source.dart';
import '../domain/domain.dart';
import '../domain/models/json.dart';
import 'guest_merge.dart';

class SyncEngine implements SyncService {
  SyncEngine({
    required this._store,
    required this._remote,
    required this._connectivity,
    required this._authStates,
    required this._currentAuth,
    this._resumeSignals,
    this.periodicInterval = const Duration(minutes: 5),
    this.writeDebounce = const Duration(seconds: 2),
    this.replacedRetention = const Duration(days: 30),
  });

  final LocalStore _store;
  final RemoteDataSource _remote;
  final ConnectivityService _connectivity;
  final Stream<AuthState> _authStates;
  final AuthState Function() _currentAuth;
  final Stream<void>? _resumeSignals;
  final Duration periodicInterval;
  final Duration writeDebounce;
  final Duration replacedRetention;

  AppDatabase get _db => _store.db;

  static const _lastSyncedKey = 'sync_last_synced_at';
  static const _ownerKey = 'db_owner_user_id';

  final _statusController = StreamController<SyncStatus>.broadcast();
  SyncStatus _status = SyncStatus.idle;
  final _subs = <StreamSubscription<Object?>>[];
  Timer? _periodic;
  Timer? _debounce;
  Future<void>? _running;
  bool _started = false;
  bool _online = true;
  bool _authExpired = false;
  int _progressDone = 0;
  int _progressTotal = 0;
  DateTime? _lastSyncedAt;

  // ------------------------------------------------------------------
  // SyncService

  @override
  SyncStatus get status => _status;

  @override
  Stream<SyncStatus> watchStatus() =>
      currentThenChanges(() => _status, _statusController.stream);

  @override
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _online = _connectivity.isOnline;
    final last = await _db.readKv(_lastSyncedKey);
    _lastSyncedAt = parseDateOrNull(last);
    await _onAuth(_currentAuth());
    _subs
      ..add(
        _connectivity.watchOnline().listen((online) {
          final was = _online;
          _online = online;
          unawaited(_publish());
          if (online && !was) unawaited(syncNow());
        }),
      )
      ..add(_authStates.listen((s) => unawaited(_onAuth(s))))
      ..add(
        _db.select(_db.syncOutbox).watch().listen((_) {
          unawaited(_publish());
          _scheduleDebounced();
        }),
      );
    final resume = _resumeSignals;
    if (resume != null) {
      _subs.add(resume.listen((_) => unawaited(syncNow())));
    }
    _periodic = Timer.periodic(periodicInterval, (_) => unawaited(syncNow()));
    await _publish();
    unawaited(syncNow());
  }

  @override
  Future<void> stop() async {
    _started = false;
    _periodic?.cancel();
    _debounce?.cancel();
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    await _running;
  }

  /// Releases the status stream (provider dispose).
  Future<void> dispose() async {
    await stop();
    await _statusController.close();
  }

  @override
  Future<void> syncNow() {
    final running = _running;
    if (running != null) return running;
    final run = _sync().whenComplete(() => _running = null);
    _running = run;
    return run;
  }

  @override
  Stream<List<SyncOp>> watchPendingOps() =>
      (_db.select(_db.syncOutbox)..orderBy([
            (t) => OrderingTerm.asc(t.createdAt),
            (t) => OrderingTerm.asc(insertionOrder),
          ]))
          .watch()
          .map((rows) => rows.map(syncOpFromRow).toList());

  @override
  Future<void> retryOp(String opId) async {
    await (_db.update(_db.syncOutbox)..where((t) => t.id.equals(opId))).write(
      const SyncOutboxCompanion(
        failed: Value(false),
        attempts: Value(0),
        notBefore: Value(null),
        lastError: Value(null),
      ),
    );
    unawaited(syncNow());
  }

  @override
  Future<void> discardOp(String opId) async {
    final op = await (_db.select(
      _db.syncOutbox,
    )..where((t) => t.id.equals(opId))).getSingleOrNull();
    if (op == null) return;
    final entity = SyncEntity.values.byName(op.entity);
    final kind = SyncOpKind.values.byName(op.kind);
    await _store.removeOp(opId);
    switch ((entity, kind)) {
      case (SyncEntity.paper, SyncOpKind.create):
        await _store.purgePaperLocally(op.entityId);
      case (SyncEntity.paper, SyncOpKind.delete):
        await (_db.update(
          _db.papers,
        )..where((t) => t.id.equals(op.entityId))).write(
          PapersCompanion(
            deletedAt: const Value(null),
            syncState: Value(SyncState.synced.name),
          ),
        );
        await (_db.update(_db.notes)
              ..where((t) => t.paperId.equals(op.entityId)))
            .write(const NotesCompanion(deletedAt: Value(null)));
      case (SyncEntity.paper, SyncOpKind.update):
        await _markSynced(SyncEntity.paper, op.entityId);
      case (SyncEntity.highlight, SyncOpKind.create):
        await (_db.delete(
          _db.highlights,
        )..where((t) => t.id.equals(op.entityId))).go();
      case (SyncEntity.figureHighlight, SyncOpKind.create):
        await _deleteFigureLocally(op.entityId);
      case (SyncEntity.highlight, _) || (SyncEntity.figureHighlight, _):
        await _markSynced(entity, op.entityId);
    }
    // Pull restores server values for reverted updates / deletes.
    unawaited(syncNow());
  }

  @override
  Stream<List<ReplacedVersion>> watchReplacedVersions() =>
      (_db.select(_db.replacedVersions)
            ..orderBy([(t) => OrderingTerm.desc(t.replacedAt)]))
          .watch()
          .map((rows) => rows.map(replacedFromRow).toList());

  @override
  Future<void> restoreReplaced(String replacedVersionId) async {
    final row = await (_db.select(
      _db.replacedVersions,
    )..where((t) => t.id.equals(replacedVersionId))).getSingleOrNull();
    if (row == null) return;
    final mine = asJsonMap(jsonDecode(row.mine));
    switch (SyncEntity.values.byName(row.entity)) {
      case SyncEntity.figureHighlight:
        await _store.writeFigureNote(row.entityId, mine['note'] as String?);
      case SyncEntity.highlight:
        await _store.insertHighlightPendingCreate(Highlight.fromJson(mine));
      case SyncEntity.paper:
        final title = mine['title'] as String?;
        if (title != null) {
          await (_db.update(
            _db.papers,
          )..where((t) => t.id.equals(row.entityId))).write(
            PapersCompanion(
              title: Value(title),
              syncState: Value(SyncState.pendingUpdate.name),
            ),
          );
          await _store.enqueue(
            entity: SyncEntity.paper,
            entityId: row.entityId,
            kind: SyncOpKind.update,
            payload: {'title': title},
            paperId: row.entityId,
          );
        }
    }
    await dismissReplaced(replacedVersionId);
  }

  @override
  Future<void> dismissReplaced(String replacedVersionId) => (_db.delete(
    _db.replacedVersions,
  )..where((t) => t.id.equals(replacedVersionId))).go();

  // ------------------------------------------------------------------
  // Triggers

  void _scheduleDebounced() {
    if (!_started) return;
    _debounce?.cancel();
    _debounce = Timer(writeDebounce, () => unawaited(syncNow()));
  }

  Future<void> _onAuth(AuthState state) async {
    final user = state.user;
    if (!state.isSignedIn || user == null) {
      await _publish();
      return;
    }
    _authExpired = false;
    await _prepareOwner(user.id);
    await _publish();
    if (_started) unawaited(syncNow());
  }

  /// Serialises [_adopt] (auth events and sync rounds may overlap).
  Future<void> _ownerWork = Future<void>.value();

  /// Makes the local DB [userId]'s before anything is pushed (rule 7).
  /// Idempotent and cheap when there is nothing to merge.
  Future<void> _prepareOwner(String userId) {
    final run = _ownerWork.then((_) => _adopt(userId));
    _ownerWork = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  Future<void> _adopt(String userId) async {
    if (isGuestUserId(userId)) return;
    final owner = await _db.readKv(_ownerKey);
    await GuestDataMerge(_store).prepareFor(userId, previousOwner: owner);
    if (owner != null && owner != userId && !isGuestUserId(owner)) {
      _lastSyncedAt = null;
    }
    await _db.writeKv(_ownerKey, userId);
  }

  // ------------------------------------------------------------------
  // Sync round

  Future<void> _sync() async {
    final auth = _currentAuth();
    final user = auth.user;
    if (!auth.isSignedIn || user == null) return;
    // Guest rows are re-owned before the first push (rule 7).
    await _prepareOwner(user.id);
    _online = await _connectivity.check();
    if (!_online) {
      await _publish();
      return;
    }
    _progressDone = 0;
    _progressTotal = 0;
    try {
      await _push();
      await _pull();
      _authExpired = false;
      _lastSyncedAt = _store.now();
      await _db.writeKv(_lastSyncedKey, dateToJson(_lastSyncedAt)!);
      await _purgeOldReplaced();
    } on OfflineException {
      _online = false;
    } on AuthExpiredException {
      _authExpired = true;
    } on ServerException {
      // Transient server error: ops already rescheduled with backoff.
    } finally {
      _progressDone = 0;
      _progressTotal = 0;
      await _publish(running: false);
    }
  }

  /// Pull only (library refresh). Throws `OfflineException` offline.
  Future<void> pull() async {
    final auth = _currentAuth();
    final user = auth.user;
    if (!auth.isSignedIn || user == null) return;
    await _prepareOwner(user.id);
    await _pull();
  }

  Future<void> _push() async {
    final now = _store.now();
    final all =
        await (_db.select(_db.syncOutbox)
              ..where((t) => t.failed.equals(false))
              ..orderBy([
                (t) => OrderingTerm.asc(t.createdAt),
                (t) => OrderingTerm.asc(insertionOrder),
              ]))
            .get();
    final due = all
        .where((o) => o.notBefore == null || !o.notBefore!.isAfter(now))
        .toList();
    if (due.isEmpty) return;
    _progressTotal = due.length;
    await _publish(running: true);

    for (final op in due) {
      // Re-read: earlier ops in this round may have removed it.
      final current = await (_db.select(
        _db.syncOutbox,
      )..where((t) => t.id.equals(op.id))).getSingleOrNull();
      if (current == null || current.failed) continue;
      if (await _isHeld(current)) continue;
      // Written by the guest after this round's merge (e.g. a highlight on
      // a paper opened before sign-in): the next round re-owns it first.
      if (current.payload.contains(kGuestUserId)) continue;
      try {
        await _pushOp(current);
        await _store.removeOp(current.id);
        await _settle(current);
      } on OfflineException catch (e) {
        await _backoff(current, e);
        rethrow;
      } on AuthExpiredException {
        rethrow;
      } on ServerException catch (e) {
        if (_isTransient(e.statusCode)) {
          await _backoff(current, e);
          rethrow;
        }
        await _fail(current, e);
      } on NotFoundException catch (e) {
        await _fail(current, e);
      } on PaperException catch (e) {
        await _fail(current, e);
      }
      _progressDone++;
      await _publish(running: true);
    }
  }

  static bool _isTransient(int status) =>
      status >= 500 || status == 408 || status == 429;

  /// Rule 1 holds.
  Future<bool> _isHeld(SyncOpRow op) async {
    final entity = SyncEntity.values.byName(op.entity);
    final siblings = await _store.opsFor(entity, op.entityId);
    if (op.kind != SyncOpKind.delete.name &&
        siblings.any((o) => o.kind == SyncOpKind.delete.name)) {
      return true;
    }
    if (entity != SyncEntity.paper && op.paperId != null) {
      final paperOps = await _store.opsFor(SyncEntity.paper, op.paperId!);
      if (paperOps.any((o) => o.kind == SyncOpKind.create.name)) return true;
      // Children of a paper being deleted are dropped with it.
      if (paperOps.any((o) => o.kind == SyncOpKind.delete.name)) return true;
    }
    return false;
  }

  Future<void> _backoff(SyncOpRow op, Object error) async {
    final attempts = op.attempts + 1;
    final delay = Duration(
      milliseconds: math.min(
        2000 * math.pow(2, attempts - 1).toInt(),
        const Duration(minutes: 5).inMilliseconds,
      ),
    );
    await (_db.update(_db.syncOutbox)..where((t) => t.id.equals(op.id))).write(
      SyncOutboxCompanion(
        attempts: Value(attempts),
        lastError: Value(error.toString()),
        notBefore: Value(_store.now().add(delay)),
      ),
    );
  }

  Future<void> _fail(SyncOpRow op, PaperException error) async {
    final reason = error is NotFoundException ? 'notFound' : error.toString();
    await (_db.update(_db.syncOutbox)..where((t) => t.id.equals(op.id))).write(
      SyncOutboxCompanion(
        failed: const Value(true),
        attempts: Value(op.attempts + 1),
        lastError: Value(reason),
      ),
    );
    final entity = SyncEntity.values.byName(op.entity);
    await _setState(entity, op.entityId, SyncState.failed);
  }

  /// After a successful push: the row is synced unless more ops wait.
  Future<void> _settle(SyncOpRow op) async {
    final entity = SyncEntity.values.byName(op.entity);
    if (op.kind == SyncOpKind.delete.name) return;
    final rest = await _store.opsFor(entity, op.entityId);
    if (rest.isEmpty) await _markSynced(entity, op.entityId);
  }

  Future<void> _markSynced(SyncEntity entity, String id) =>
      _setState(entity, id, SyncState.synced);

  Future<void> _setState(SyncEntity entity, String id, SyncState state) {
    switch (entity) {
      case SyncEntity.paper:
        return (_db.update(_db.papers)..where((t) => t.id.equals(id))).write(
          PapersCompanion(syncState: Value(state.name)),
        );
      case SyncEntity.highlight:
        return (_db.update(_db.highlights)..where((t) => t.id.equals(id)))
            .write(HighlightsCompanion(syncState: Value(state.name)));
      case SyncEntity.figureHighlight:
        return (_db.update(_db.figureHighlights)..where((t) => t.id.equals(id)))
            .write(FigureHighlightsCompanion(syncState: Value(state.name)));
    }
  }

  Future<void> _pushOp(SyncOpRow op) async {
    final entity = SyncEntity.values.byName(op.entity);
    final kind = SyncOpKind.values.byName(op.kind);
    final payload = asJsonMap(jsonDecode(op.payload));

    if (kind == SyncOpKind.delete) {
      final siblings = await _store.opsFor(entity, op.entityId);
      final neverPushed = siblings.any(
        (o) => o.kind == SyncOpKind.create.name && o.attempts == 0,
      );
      if (neverPushed) {
        // Create + delete cancel out; nothing reaches the server.
        await _store.removeOpsFor(entity, op.entityId);
        await _removeLocally(entity, op.entityId);
        return;
      }
    }

    switch ((entity, kind)) {
      case (SyncEntity.paper, SyncOpKind.create):
        final row = await (_db.select(
          _db.papers,
        )..where((t) => t.id.equals(op.entityId))).getSingleOrNull();
        if (row == null) return;
        final local = row.localFilePath;
        if (row.storagePath != null && local != null) {
          final file = File(local);
          if (file.existsSync()) {
            await _remote.uploadObject(
              papersBucket,
              row.storagePath!,
              await file.readAsBytes(),
              contentType: 'application/pdf',
            );
          }
        }
        await _remote.upsertPaper(paperRowToSupabase(row));
      case (SyncEntity.paper, SyncOpKind.update):
        await _remote.updatePaper(op.entityId, serverPayload(payload));
      case (SyncEntity.paper, SyncOpKind.delete):
        await _remote.deletePaper(op.entityId);
        await _store.purgePaperLocally(op.entityId);
      case (SyncEntity.highlight, SyncOpKind.create):
        await _remote.insertHighlight(serverPayload(payload));
      case (SyncEntity.highlight, SyncOpKind.update):
        // Highlights are immutable on the server; nothing to send.
        break;
      case (SyncEntity.highlight, SyncOpKind.delete):
        await _remote.deleteHighlight(op.entityId);
        await _removeLocally(entity, op.entityId);
      case (SyncEntity.figureHighlight, SyncOpKind.create):
        final row = await (_db.select(
          _db.figureHighlights,
        )..where((t) => t.id.equals(op.entityId))).getSingleOrNull();
        if (row == null) return;
        final image = row.localImagePath;
        if (image != null && File(image).existsSync()) {
          await _remote.uploadObject(
            figuresBucket,
            row.storagePath,
            Uint8List.fromList(await File(image).readAsBytes()),
            contentType: 'image/png',
          );
        }
        final serverRow = await _remote.upsertFigureHighlight(
          figureFromRow(row).toSupabaseRow(),
        );
        await _applyServerFigure(serverRow);
      case (SyncEntity.figureHighlight, SyncOpKind.update):
        await _pushFigureNote(op, payload);
      case (SyncEntity.figureHighlight, SyncOpKind.delete):
        await _remote.deleteFigureHighlight(op.entityId);
        await _removeLocally(entity, op.entityId);
    }
  }

  /// Rule 3.
  Future<void> _pushFigureNote(
    SyncOpRow op,
    Map<String, Object?> payload,
  ) async {
    final server = await _remote.fetchFigureHighlight(op.entityId);
    if (server == null) throw NotFoundException('figure ${op.entityId}');
    final serverUpdated = parseDate(server['updated_at']);
    final base = parseDateOrNull(payload[baseUpdatedAtKey]);
    final serverChanged = base == null || serverUpdated.isAfter(base);
    final localWins =
        !serverChanged || !serverUpdated.isAfter(op.localUpdatedAt);
    final note = payload['note'] as String?;
    if (localWins) {
      final updated = await _remote.updateFigureNote(op.entityId, note);
      await _applyServerFigure(updated);
      return;
    }
    // Server wins: keep ours as a replaced version unless identical.
    final local = await (_db.select(
      _db.figureHighlights,
    )..where((t) => t.id.equals(op.entityId))).getSingleOrNull();
    if (local != null && server['note'] != note) {
      await _recordReplaced(
        SyncEntity.figureHighlight,
        op.entityId,
        mine: figureFromRow(local).toJson(),
        mineUpdatedAt: op.localUpdatedAt,
        theirsUpdatedAt: serverUpdated,
      );
    }
    await _applyServerFigure(server);
  }

  Future<void> _applyServerFigure(Map<String, Object?> row) async {
    await (_db.update(
      _db.figureHighlights,
    )..where((t) => t.id.equals(row['id']! as String))).write(
      figureServerColumns(row)
          .copyWith(syncState: Value(SyncState.synced.name)),
    );
  }

  Future<void> _recordReplaced(
    SyncEntity entity,
    String entityId, {
    required Map<String, Object?> mine,
    required DateTime mineUpdatedAt,
    required DateTime theirsUpdatedAt,
  }) => _db
      .into(_db.replacedVersions)
      .insert(
        ReplacedVersionsCompanion.insert(
          id: _store.newId(),
          entity: entity.name,
          entityId: entityId,
          mine: jsonEncode(mine),
          mineUpdatedAt: mineUpdatedAt,
          theirsUpdatedAt: theirsUpdatedAt,
          replacedAt: _store.now(),
        ),
      );

  Future<void> _removeLocally(SyncEntity entity, String id) async {
    switch (entity) {
      case SyncEntity.paper:
        await _store.purgePaperLocally(id);
      case SyncEntity.highlight:
        await (_db.delete(_db.highlights)..where((t) => t.id.equals(id))).go();
      case SyncEntity.figureHighlight:
        await _deleteFigureLocally(id);
    }
  }

  Future<void> _deleteFigureLocally(String id) async {
    final row = await (_db.select(
      _db.figureHighlights,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    await (_db.delete(
      _db.figureHighlights,
    )..where((t) => t.id.equals(id))).go();
    await _store.files.deleteQuietly(row?.localImagePath);
  }

  // ------------------------------------------------------------------
  // Pull + merge

  Future<void> _pull() async {
    final papers = await _remote.fetchPapers();
    final highlights = await _remote.fetchHighlights();
    final figures = await _remote.fetchFigureHighlights();
    final pendingIds = <String>{
      for (final o in await _db.select(_db.syncOutbox).get())
        '${o.entity}:${o.entityId}',
    };
    bool pending(SyncEntity e, String id) =>
        pendingIds.contains('${e.name}:$id');

    final purge = <String>[];
    await _db.transaction(() async {
      // Papers (rule 2).
      final localPapers = {
        for (final p in await _db.select(_db.papers).get()) p.id: p,
      };
      final serverPaperIds = <String>{};
      for (final row in papers) {
        final id = row['id']! as String;
        serverPaperIds.add(id);
        final local = localPapers[id];
        if (local == null) {
          await _db.into(_db.papers).insert(paperServerColumns(row));
        } else if (!pending(SyncEntity.paper, id) &&
            local.syncState != SyncState.failed.name) {
          await (_db.update(_db.papers)..where((t) => t.id.equals(id))).write(
            paperServerColumns(row)
                .copyWith(syncState: Value(SyncState.synced.name)),
          );
        }
      }
      for (final local in localPapers.values) {
        if (serverPaperIds.contains(local.id)) continue;
        if (pending(SyncEntity.paper, local.id)) continue;
        if (local.syncState != SyncState.synced.name) continue;
        purge.add(local.id);
      }

      // Text highlights (rule 4).
      final localHighlights = {
        for (final h in await _db.select(_db.highlights).get()) h.id: h,
      };
      final serverHighlightIds = <String>{};
      for (final row in highlights) {
        final id = row['id']! as String;
        serverHighlightIds.add(id);
        if (!localHighlights.containsKey(id)) {
          await _db.into(_db.highlights).insert(highlightFromSupabase(row));
        }
      }
      for (final local in localHighlights.values) {
        if (serverHighlightIds.contains(local.id)) continue;
        if (pending(SyncEntity.highlight, local.id)) continue;
        if (local.syncState != SyncState.synced.name) continue;
        await _serverDeletedHighlight(local);
      }

      // Figure highlights (rule 3 at push time; here: plain mirror).
      final localFigures = {
        for (final f in await _db.select(_db.figureHighlights).get()) f.id: f,
      };
      final serverFigureIds = <String>{};
      for (final row in figures) {
        final id = row['id']! as String;
        serverFigureIds.add(id);
        final local = localFigures[id];
        if (local == null) {
          await _db
              .into(_db.figureHighlights)
              .insert(
                figureServerColumns(row)
                    .copyWith(syncState: Value(SyncState.synced.name)),
              );
        } else if (!pending(SyncEntity.figureHighlight, id) &&
            local.syncState != SyncState.failed.name) {
          await _applyServerFigure(row);
        }
      }
      for (final local in localFigures.values) {
        if (serverFigureIds.contains(local.id)) continue;
        if (pending(SyncEntity.figureHighlight, local.id)) continue;
        if (local.syncState != SyncState.synced.name) continue;
        await (_db.delete(
          _db.figureHighlights,
        )..where((t) => t.id.equals(local.id))).go();
        await _store.files.deleteQuietly(local.localImagePath);
      }
    });
    for (final id in purge) {
      await _store.purgePaperLocally(id);
    }
  }

  Future<void> _serverDeletedHighlight(HighlightRow local) async {
    final notes = await (_db.select(
      _db.notes,
    )..where((t) => t.highlightId.equals(local.id))).get();
    if (notes.isNotEmpty) {
      final now = _store.now();
      for (final n in notes) {
        await (_db.update(_db.notes)..where((t) => t.id.equals(n.id))).write(
          NotesCompanion(
            highlightId: const Value(null),
            pageNumber: Value(n.pageNumber ?? local.pageNumber),
            quotedExcerpt: Value(n.quotedExcerpt ?? local.selectedText),
            updatedAt: Value(now),
          ),
        );
      }
      await _recordReplaced(
        SyncEntity.highlight,
        local.id,
        mine: highlightFromRow(local).toJson(),
        mineUpdatedAt: local.localUpdatedAt ?? local.createdAt,
        theirsUpdatedAt: now,
      );
    }
    await (_db.delete(
      _db.highlights,
    )..where((t) => t.id.equals(local.id))).go();
  }

  Future<void> _purgeOldReplaced() async {
    final cutoff = _store.now().subtract(replacedRetention);
    await (_db.delete(_db.replacedVersions)..where(
          (t) => t.replacedAt.isSmallerThanValue(
            const UtcMicrosConverter().toSql(cutoff),
          ),
        ))
        .go();
  }

  // ------------------------------------------------------------------
  // Status

  Future<void> _publish({bool? running}) async {
    if (_statusController.isClosed) return;
    final ops = await _db.select(_db.syncOutbox).get();
    final failed = ops.where((o) => o.failed).length;
    final pendingCount = ops.length - failed;
    final isRunning = running ?? (_running != null && _progressTotal > 0);
    final SyncPhase phase;
    if (failed > 0 || _authExpired) {
      phase = SyncPhase.error;
    } else if (!_online) {
      phase = SyncPhase.offline;
    } else if (isRunning) {
      phase = SyncPhase.syncing;
    } else if (pendingCount > 0) {
      phase = SyncPhase.pending;
    } else {
      phase = SyncPhase.synced;
    }
    final next = SyncStatus(
      phase: phase,
      pendingCount: pendingCount,
      failedCount: failed,
      progressDone: isRunning ? _progressDone : 0,
      progressTotal: isRunning ? _progressTotal : 0,
      lastSyncedAt: _lastSyncedAt,
      authExpired: _authExpired,
    );
    if (next == _status) return;
    _status = next;
    _statusController.add(next);
  }
}
