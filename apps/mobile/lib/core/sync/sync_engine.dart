import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../api/api_client.dart';
import 'sync_outbox_item.dart';
import 'offline_cache_store.dart';

enum SyncEngineState {
  idle,
  syncing,
  synced,
  offline,
  error,
}

class SyncEngine extends ChangeNotifier {
  final ApiClient apiClient;
  final OfflineCacheStore cacheStore;
  final Connectivity _connectivity;

  SyncEngineState _state = SyncEngineState.idle;
  bool _isOnline = true;
  String? _lastError;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  SyncEngineState get state => _state;
  bool get isOnline => _isOnline;
  String? get lastError => _lastError;
  int get pendingCount => cacheStore.getOutbox().where((i) => i.status != SyncItemStatus.synced).length;
  List<SyncOutboxItem> get outboxItems => cacheStore.getOutbox();

  SyncEngine({
    required this.apiClient,
    required this.cacheStore,
    Connectivity? connectivity,
  }) : _connectivity = connectivity ?? Connectivity() {
    _initConnectivity();
  }

  void _initConnectivity() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      final wasOffline = !_isOnline;
      _isOnline = hasConnection;

      if (_isOnline) {
        if (wasOffline && pendingCount > 0) {
          syncNow();
        } else {
          _state = SyncEngineState.idle;
          notifyListeners();
        }
      } else {
        _state = SyncEngineState.offline;
        notifyListeners();
      }
    });
  }

  void setOnlineStatusForTesting(bool online) {
    _isOnline = online;
    _state = online ? SyncEngineState.idle : SyncEngineState.offline;
    notifyListeners();
  }

  Future<void> enqueueMutation({
    required SyncMutationType mutationType,
    required String endpoint,
    required Map<String, dynamic> payload,
    String httpMethod = 'POST',
    String? customIdempotencyKey,
  }) async {
    final item = SyncOutboxItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      mutationType: mutationType,
      endpoint: endpoint,
      httpMethod: httpMethod,
      payload: payload,
      idempotencyKey: customIdempotencyKey ?? 'idem_${DateTime.now().microsecondsSinceEpoch}',
      createdAt: DateTime.now().toUtc(),
      status: SyncItemStatus.pending,
    );

    await cacheStore.enqueue(item);
    notifyListeners();

    if (_isOnline) {
      unawaited(syncNow());
    } else {
      _state = SyncEngineState.offline;
      notifyListeners();
    }
  }

  Future<void> syncNow() async {
    if (_state == SyncEngineState.syncing) return;
    if (!_isOnline) {
      _state = SyncEngineState.offline;
      notifyListeners();
      return;
    }

    final pending = cacheStore.getOutbox().where((i) => i.status != SyncItemStatus.synced).toList();
    if (pending.isEmpty) {
      _state = SyncEngineState.synced;
      notifyListeners();
      return;
    }

    _state = SyncEngineState.syncing;
    _lastError = null;
    notifyListeners();

    for (final item in pending) {
      try {
        await cacheStore.updateItem(item.copyWith(status: SyncItemStatus.syncing));
        notifyListeners();

        // Send HTTP request with preserved Idempotency-Key
        if (item.httpMethod == 'POST') {
          await apiClient.post(item.endpoint, body: item.payload, idempotencyKey: item.idempotencyKey);
        } else if (item.httpMethod == 'PATCH') {
          await apiClient.patch(item.endpoint, body: item.payload);
        } else if (item.httpMethod == 'DELETE') {
          await apiClient.delete(item.endpoint, idempotencyKey: item.idempotencyKey);
        }

        // Successfully synced
        await cacheStore.updateItem(item.copyWith(status: SyncItemStatus.synced));
      } catch (e) {
        // Network or server error
        _lastError = e.toString();
        await cacheStore.updateItem(item.copyWith(
          status: SyncItemStatus.failed,
          retryCount: item.retryCount + 1,
          lastError: e.toString(),
        ));
        _state = SyncEngineState.error;
        notifyListeners();
        return; // Halt sequential replay on network interruption
      }
    }

    // Clean up synced items from store
    await cacheStore.removeSynced();
    _state = SyncEngineState.synced;
    notifyListeners();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
