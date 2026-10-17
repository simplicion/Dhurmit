import 'dart:convert';

enum SyncMutationType {
  recordCollection,
  createCommittee,
  addMember,
  reverseCollection,
}

enum SyncItemStatus {
  pending,
  syncing,
  synced,
  failed,
}

class SyncOutboxItem {
  final String id; // Client UUID
  final SyncMutationType mutationType;
  final String endpoint; // e.g. /committees/123/collections
  final String httpMethod; // POST, PATCH, DELETE
  final Map<String, dynamic> payload;
  final String idempotencyKey;
  final DateTime createdAt;
  final int retryCount;
  final SyncItemStatus status;
  final String? lastError;

  const SyncOutboxItem({
    required this.id,
    required this.mutationType,
    required this.endpoint,
    this.httpMethod = 'POST',
    required this.payload,
    required this.idempotencyKey,
    required this.createdAt,
    this.retryCount = 0,
    this.status = SyncItemStatus.pending,
    this.lastError,
  });

  SyncOutboxItem copyWith({
    SyncItemStatus? status,
    int? retryCount,
    String? lastError,
  }) {
    return SyncOutboxItem(
      id: id,
      mutationType: mutationType,
      endpoint: endpoint,
      httpMethod: httpMethod,
      payload: payload,
      idempotencyKey: idempotencyKey,
      createdAt: createdAt,
      retryCount: retryCount ?? this.retryCount,
      status: status ?? this.status,
      lastError: lastError ?? this.lastError,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mutationType': mutationType.name,
      'endpoint': endpoint,
      'httpMethod': httpMethod,
      'payload': payload,
      'idempotencyKey': idempotencyKey,
      'createdAt': createdAt.toIso8601String(),
      'retryCount': retryCount,
      'status': status.name,
      'lastError': lastError,
    };
  }

  factory SyncOutboxItem.fromJson(Map<String, dynamic> json) {
    return SyncOutboxItem(
      id: json['id'] as String,
      mutationType: SyncMutationType.values.firstWhere(
        (e) => e.name == json['mutationType'],
        orElse: () => SyncMutationType.recordCollection,
      ),
      endpoint: json['endpoint'] as String,
      httpMethod: json['httpMethod'] as String? ?? 'POST',
      payload: (json['payload'] as Map<String, dynamic>?) ?? {},
      idempotencyKey: json['idempotencyKey'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      retryCount: json['retryCount'] as int? ?? 0,
      status: SyncItemStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => SyncItemStatus.pending,
      ),
      lastError: json['lastError'] as String?,
    );
  }

  static String serializeList(List<SyncOutboxItem> items) {
    return jsonEncode(items.map((i) => i.toJson()).toList());
  }

  static List<SyncOutboxItem> deserializeList(String jsonString) {
    if (jsonString.trim().isEmpty) return [];
    try {
      final List<dynamic> raw = jsonDecode(jsonString) as List<dynamic>;
      return raw.map((item) => SyncOutboxItem.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }
}
