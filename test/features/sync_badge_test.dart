import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:paper/domain/domain.dart';
import 'package:paper/features/sync/sync_badge.dart';
import 'package:paper/sync/sync_providers.dart';
import 'package:paper/theme/motion_extras.dart';

import '../helpers.dart';
import 'feature_fakes.dart';

void main() {
  late FakeSyncService sync;

  setUp(() => sync = FakeSyncService());

  Future<void> pump(
    WidgetTester tester, {
    SyncBadgeForm form = SyncBadgeForm.long,
  }) async {
    setWindowSize(tester, const Size(700, 900));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [syncServiceProvider.overrideWithValue(sync)],
        child: testApp(
          Scaffold(
            body: Center(
              child: SizedBox(width: 320, child: SyncBadge(form: form)),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> show(WidgetTester tester, SyncStatus status) async {
    sync.emit(status);
    await tester.pump();
    await tester.pump(PaperMotionTest.crossfade);
  }

  testWidgets('every state has its own icon and long text', (tester) async {
    await pump(tester);
    expect(find.byIcon(Symbols.cloud_done_rounded), findsOneWidget);
    expect(find.text('Not synced yet'), findsOneWidget);

    await show(
      tester,
      const SyncStatus(phase: SyncPhase.pending, pendingCount: 3),
    );
    expect(find.byIcon(Symbols.cloud_upload_rounded), findsOneWidget);
    expect(find.text('3 changes waiting to sync'), findsOneWidget);

    await show(
      tester,
      const SyncStatus(phase: SyncPhase.offline, pendingCount: 1),
    );
    expect(find.byIcon(Symbols.cloud_off_rounded), findsOneWidget);
    expect(
      find.text('Offline · 1 change saved on this device'),
      findsOneWidget,
    );

    await show(tester, const SyncStatus(phase: SyncPhase.offline));
    expect(find.text('Offline · no changes waiting'), findsOneWidget);

    await show(
      tester,
      const SyncStatus(phase: SyncPhase.error, failedCount: 2),
    );
    expect(find.byIcon(Symbols.warning_rounded), findsOneWidget);
    expect(find.text('2 changes couldn’t sync'), findsOneWidget);

    await show(
      tester,
      const SyncStatus(phase: SyncPhase.error, authExpired: true),
    );
    expect(find.text('Sign in again to sync your changes.'), findsOneWidget);

    // Semantics carry the long text.
    expect(
      find.bySemanticsLabel(
        'Sync status: Sign in again to sync your changes.. Opens details.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('short syncs never flash the syncing state', (tester) async {
    await pump(tester);
    sync.emit(
      const SyncStatus(
        phase: SyncPhase.syncing,
        progressDone: 1,
        progressTotal: 4,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byIcon(Symbols.sync_rounded), findsNothing);

    // Finished before kSyncingMinVisible: straight to synced.
    await show(
      tester,
      SyncStatus(phase: SyncPhase.synced, lastSyncedAt: DateTime(2026)),
    );
    await tester.pump(kSyncingMinVisible);
    expect(find.byIcon(Symbols.sync_rounded), findsNothing);

    // A long sync shows the progress.
    sync.emit(
      const SyncStatus(
        phase: SyncPhase.syncing,
        progressDone: 2,
        progressTotal: 4,
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(kSyncingMinVisible + const Duration(milliseconds: 50));
    await tester.pump(PaperMotionTest.crossfade);
    expect(find.byIcon(Symbols.sync_rounded), findsOneWidget);
    expect(find.text('Syncing 2 of 4'), findsOneWidget);

    await show(
      tester,
      const SyncStatus(phase: SyncPhase.pending, pendingCount: 1),
    );
  });

  testWidgets('icon form shows a count dot; tap opens the sync sheet', (
    tester,
  ) async {
    sync.ops = <SyncOp>[
      SyncOp(
        id: 'o1',
        entity: SyncEntity.paper,
        entityId: 'p1',
        kind: SyncOpKind.update,
        createdAt: DateTime.utc(2026),
        localUpdatedAt: DateTime.utc(2026),
        deviceId: 'd',
        failed: true,
        lastError: 'notFound',
      ),
    ];
    sync.emit(const SyncStatus(phase: SyncPhase.error, failedCount: 1));
    await pump(tester, form: SyncBadgeForm.icon);
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('sync-badge')));
    await tester.pumpAndSettle();
    expect(
      find.text('The paper was deleted on another device.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Discard change'));
    await tester.pump();
    expect(sync.calls, contains('discard o1'));
    await tester.tap(find.byKey(const ValueKey<String>('sync-now')));
    await tester.pump();
    expect(sync.calls, contains('syncNow'));
  });
}

/// Crossfade duration used by the badge (motion #23).
abstract final class PaperMotionTest {
  static const Duration crossfade = Duration(milliseconds: 250);
}
