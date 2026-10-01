import '../enums/enums.dart';
import 'converters.dart';

/// A row of `v_activity_feed`.
///
/// Money-bearing events are filtered out by RLS for designers and production,
/// so this is safe to render for any role — their timeline simply has no
/// quotation or payment entries in it.
class ActivityEntry {
  const ActivityEntry({
    required this.id,
    required this.occurredAt,
    required this.entityType,
    required this.entityId,
    required this.eventType,
    required this.actorKind,
    required this.actorName,
    this.requestId,
    this.requestNumber,
    this.fromValue,
    this.toValue,
    this.metadata = const <String, dynamic>{},
  });

  factory ActivityEntry.fromJson(Map<String, dynamic> j) => ActivityEntry(
        id: parseInt(j['id']),
        occurredAt: parseTimestamp(j['occurred_at']),
        requestId: j['request_id'] as String?,
        requestNumber: parseIntOrNull(j['request_number']),
        entityType: j['entity_type'] as String,
        entityId: j['entity_id'] as String,
        eventType: j['event_type'] as String,
        fromValue: str(j['from_value']),
        toValue: str(j['to_value']),
        metadata: asMap(j['metadata']),
        actorKind: ActorKind.fromWire(j['actor_kind'] as String),
        actorName: j['actor_name'] as String,
      );

  /// Monotonic. This — not [occurredAt] — is the order things happened in:
  /// `now()` is the transaction timestamp, so every event written by one
  /// operation shares a timestamp.
  final int id;
  final DateTime occurredAt;
  final String? requestId;
  final int? requestNumber;
  final String entityType;
  final String entityId;
  final String eventType;
  final String? fromValue;
  final String? toValue;
  final Map<String, dynamic> metadata;
  final ActorKind actorKind;
  final String actorName;

  bool get isMoney =>
      entityType == 'quotation' ||
      entityType == 'payment' ||
      entityType == 'task_cost';
}
