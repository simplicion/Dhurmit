import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'sync_outbox_item.dart';

class OfflineCacheStore {
  static const String _outboxKey = 'offline_sync_outbox';
  static const String _committeesKeyPrefix = 'cache_committees_';
  static const String _obligationsKeyPrefix = 'cache_obligations_';
  static const String _membersKeyPrefix = 'cache_members_';
  static const String _collectionsKeyPrefix = 'cache_collections_';

  final SharedPreferences? prefs;
  final Map<String, String> _memoryFallback = {};

  OfflineCacheStore({this.prefs});

  static Future<OfflineCacheStore> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 2),
      );
      return OfflineCacheStore(prefs: prefs);
    } catch (_) {
      return OfflineCacheStore(prefs: null);
    }
  }

  factory OfflineCacheStore.fallback() => OfflineCacheStore(prefs: null);

  String? _getString(String key) {
    try {
      return prefs?.getString(key) ?? _memoryFallback[key];
    } catch (_) {
      return _memoryFallback[key];
    }
  }

  Future<void> _setString(String key, String value) async {
    _memoryFallback[key] = value;
    try {
      await prefs?.setString(key, value);
    } catch (_) {}
  }

  // --- OUTBOX QUEUE ---

  List<SyncOutboxItem> getOutbox() {
    final raw = _getString(_outboxKey);
    if (raw == null) return [];
    return SyncOutboxItem.deserializeList(raw);
  }

  Future<void> saveOutbox(List<SyncOutboxItem> items) async {
    final serialized = SyncOutboxItem.serializeList(items);
    await _setString(_outboxKey, serialized);
  }

  Future<void> enqueue(SyncOutboxItem item) async {
    final current = getOutbox();
    current.add(item);
    await saveOutbox(current);
  }

  Future<void> updateItem(SyncOutboxItem updated) async {
    final current = getOutbox();
    final index = current.indexWhere((i) => i.id == updated.id);
    if (index != -1) {
      current[index] = updated;
      await saveOutbox(current);
    }
  }

  Future<void> removeSynced() async {
    final current = getOutbox();
    final remaining = current.where((i) => i.status != SyncItemStatus.synced).toList();
    await saveOutbox(remaining);
  }

  // --- ENTITY CACHES ---

  List<Map<String, dynamic>> getCachedCommittees(String workspaceId) {
    final raw = _getString('$_committeesKeyPrefix$workspaceId');
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> cacheCommittees(String workspaceId, List<Map<String, dynamic>> committees) async {
    await _setString('$_committeesKeyPrefix$workspaceId', jsonEncode(committees));
  }

  List<Map<String, dynamic>> getCachedMembers(String committeeId) {
    final raw = _getString('$_membersKeyPrefix$committeeId');
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> cacheMembers(String committeeId, List<Map<String, dynamic>> members) async {
    await _setString('$_membersKeyPrefix$committeeId', jsonEncode(members));
  }

  List<Map<String, dynamic>> getCachedObligations(String committeeId) {
    final raw = _getString('$_obligationsKeyPrefix$committeeId');
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> cacheObligations(String committeeId, List<Map<String, dynamic>> obligations) async {
    await _setString('$_obligationsKeyPrefix$committeeId', jsonEncode(obligations));
  }

  List<Map<String, dynamic>> getCachedCollections(String committeeId) {
    final raw = _getString('$_collectionsKeyPrefix$committeeId');
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> cacheCollections(String committeeId, List<Map<String, dynamic>> collections) async {
    await _setString('$_collectionsKeyPrefix$committeeId', jsonEncode(collections));
  }

  // --- OPTIMISTIC RECORDING ---

  Future<void> applyOptimisticCollection({
    required String committeeId,
    required Map<String, dynamic> collection,
    required List<Map<String, dynamic>> allocations,
  }) async {
    // 1. Add to cached collections
    final collections = getCachedCollections(committeeId);
    collections.insert(0, collection);
    await cacheCollections(committeeId, collections);

    // 2. Update cached obligations with new allocations
    final obligations = getCachedObligations(committeeId);
    for (final alloc in allocations) {
      final obId = alloc['obligationId'] as String;
      final amount = BigInt.parse(alloc['amountMinor'].toString());
      final index = obligations.indexWhere((o) => o['id'] == obId);
      if (index != -1) {
        final existingAlloc = BigInt.parse((obligations[index]['alreadyAllocatedMinor'] ?? '0').toString());
        final newAlloc = existingAlloc + amount;
        final due = BigInt.parse((obligations[index]['dueAmountMinor'] ?? '0').toString());
        final remaining = due > newAlloc ? due - newAlloc : BigInt.zero;

        obligations[index]['alreadyAllocatedMinor'] = newAlloc.toString();
        obligations[index]['remainingAmountMinor'] = remaining.toString();

        if (newAlloc >= due) {
          obligations[index]['status'] = 'PAID_LATE'; // Conservatively marked or check date
        } else if (newAlloc > BigInt.zero) {
          obligations[index]['status'] = 'PARTIALLY_PAID';
        }
      }
    }
    await cacheObligations(committeeId, obligations);
  }
}
