import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:committee_ledger_mobile/core/api/api_client.dart';
import 'package:committee_ledger_mobile/core/sync/sync_outbox_item.dart';
import 'package:committee_ledger_mobile/core/sync/offline_cache_store.dart';
import 'package:committee_ledger_mobile/core/sync/sync_engine.dart';
import 'package:committee_ledger_mobile/core/widgets/sync_status_banner.dart';
import 'package:committee_ledger_mobile/core/theme/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late OfflineCacheStore cacheStore;
  late SyncEngine syncEngine;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    cacheStore = OfflineCacheStore(prefs: prefs);
    syncEngine = SyncEngine(
      apiClient: ApiClient(baseUrl: 'http://localhost:4000/api/v1'),
      cacheStore: cacheStore,
    );
  });

  group('SyncOutboxItem Serialization & Lifecycle', () {
    test('serializes and deserializes outbox item cleanly', () {
      final now = DateTime.now().toUtc();
      final item = SyncOutboxItem(
        id: 'mutation-123',
        mutationType: SyncMutationType.recordCollection,
        endpoint: '/committees/c-1/collections',
        httpMethod: 'POST',
        payload: {
          'memberId': 'm-1',
          'amountMinor': 100000,
          'receivedAt': now.toIso8601String(),
        },
        idempotencyKey: 'idem-uuid-456',
        createdAt: now,
        status: SyncItemStatus.pending,
      );

      final json = item.toJson();
      final reconstructed = SyncOutboxItem.fromJson(json);

      expect(reconstructed.id, equals('mutation-123'));
      expect(reconstructed.mutationType, equals(SyncMutationType.recordCollection));
      expect(reconstructed.endpoint, equals('/committees/c-1/collections'));
      expect(reconstructed.idempotencyKey, equals('idem-uuid-456'));
      expect(reconstructed.status, equals(SyncItemStatus.pending));
      expect(reconstructed.payload['amountMinor'], equals(100000));
    });

    test('serializes and deserializes list of outbox items', () {
      final now = DateTime.now().toUtc();
      final items = [
        SyncOutboxItem(
          id: 'item-1',
          mutationType: SyncMutationType.recordCollection,
          endpoint: '/collections',
          payload: {'amount': 100},
          idempotencyKey: 'idem-1',
          createdAt: now,
        ),
        SyncOutboxItem(
          id: 'item-2',
          mutationType: SyncMutationType.addMember,
          endpoint: '/members',
          payload: {'name': 'Ramesh'},
          idempotencyKey: 'idem-2',
          createdAt: now,
        ),
      ];

      final serialized = SyncOutboxItem.serializeList(items);
      final deserialized = SyncOutboxItem.deserializeList(serialized);

      expect(deserialized, hasLength(2));
      expect(deserialized[0].id, equals('item-1'));
      expect(deserialized[1].id, equals('item-2'));
    });

    test('handles empty or corrupted json string safely', () {
      expect(SyncOutboxItem.deserializeList(''), isEmpty);
      expect(SyncOutboxItem.deserializeList('  '), isEmpty);
      expect(SyncOutboxItem.deserializeList('{invalid-json}'), isEmpty);
    });
  });

  group('OfflineCacheStore Operations', () {
    test('enqueues and updates outbox items in persistent storage', () async {
      final item = SyncOutboxItem(
        id: 'outbox-1',
        mutationType: SyncMutationType.recordCollection,
        endpoint: '/committees/c-1/collections',
        payload: {'amountMinor': 50000},
        idempotencyKey: 'idem-abc',
        createdAt: DateTime.now().toUtc(),
      );

      await cacheStore.enqueue(item);
      var outbox = cacheStore.getOutbox();
      expect(outbox, hasLength(1));
      expect(outbox[0].id, equals('outbox-1'));
      expect(outbox[0].status, equals(SyncItemStatus.pending));

      // Mark synced
      await cacheStore.updateItem(item.copyWith(status: SyncItemStatus.synced));
      outbox = cacheStore.getOutbox();
      expect(outbox[0].status, equals(SyncItemStatus.synced));

      // Clean synced
      await cacheStore.removeSynced();
      outbox = cacheStore.getOutbox();
      expect(outbox, isEmpty);
    });

    test('caches and retrieves committee rosters and members', () async {
      final members = [
        {'id': 'm-1', 'displayName': 'Sita Sharma', 'totalOutstandingMinor': 200000},
        {'id': 'm-2', 'displayName': 'Hari Thapa', 'totalOutstandingMinor': 0},
      ];

      await cacheStore.cacheMembers('c-100', members);
      final cached = cacheStore.getCachedMembers('c-100');

      expect(cached, hasLength(2));
      expect(cached[0]['displayName'], equals('Sita Sharma'));
      expect(cached[1]['displayName'], equals('Hari Thapa'));
    });

    test('applies optimistic collection update to cached obligations', () async {
      final obligations = [
        {
          'id': 'ob-1',
          'dueAmountMinor': '200000',
          'alreadyAllocatedMinor': '0',
          'remainingAmountMinor': '200000',
          'status': 'UNPAID_OVERDUE',
        },
      ];

      await cacheStore.cacheObligations('c-100', obligations);

      await cacheStore.applyOptimisticCollection(
        committeeId: 'c-100',
        collection: {
          'id': 'col-temp-1',
          'amountMinor': '200000',
          'receivedAt': DateTime.now().toIso8601String(),
        },
        allocations: [
          {'obligationId': 'ob-1', 'amountMinor': 200000},
        ],
      );

      final updatedObs = cacheStore.getCachedObligations('c-100');
      expect(updatedObs[0]['alreadyAllocatedMinor'], equals('200000'));
      expect(updatedObs[0]['remainingAmountMinor'], equals('0'));
      expect(updatedObs[0]['status'], equals('PAID_LATE'));
    });
  });

  group('SyncEngine State Machine', () {
    test('enqueues mutations and increments pending count when offline', () async {
      syncEngine.setOnlineStatusForTesting(false);
      expect(syncEngine.isOnline, isFalse);
      expect(syncEngine.state, equals(SyncEngineState.offline));

      await syncEngine.enqueueMutation(
        mutationType: SyncMutationType.recordCollection,
        endpoint: '/committees/c-1/collections',
        payload: {'amountMinor': 100000},
        customIdempotencyKey: 'idem-test-1',
      );

      expect(syncEngine.pendingCount, equals(1));
      expect(syncEngine.outboxItems[0].idempotencyKey, equals('idem-test-1'));
    });
  });

  group('SyncStatusBanner Widget Tests', () {
    testWidgets('hides banner when online with 0 pending changes', (tester) async {
      syncEngine.setOnlineStatusForTesting(true);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
            ChangeNotifierProvider<SyncEngine>.value(value: syncEngine),
          ],
          child: const MaterialApp(
            home: Scaffold(body: SyncStatusBanner()),
          ),
        ),
      );

      expect(find.byType(SyncStatusBanner), findsOneWidget);
      expect(find.byType(SizedBox), findsOneWidget); // shrink
    });

    testWidgets('displays amber banner when offline with queued changes', (tester) async {
      syncEngine.setOnlineStatusForTesting(false);
      await syncEngine.enqueueMutation(
        mutationType: SyncMutationType.recordCollection,
        endpoint: '/committees/c-1/collections',
        payload: {'amountMinor': 100000},
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
            ChangeNotifierProvider<SyncEngine>.value(value: syncEngine),
          ],
          child: const MaterialApp(
            home: Scaffold(body: SyncStatusBanner()),
          ),
        ),
      );

      expect(find.textContaining('Offline — 1 change queued'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    });
  });
}
