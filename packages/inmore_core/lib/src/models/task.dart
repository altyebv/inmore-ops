import '../enums/enums.dart';
import 'converters.dart';

/// A row of `v_task_summary`.
///
/// The executor is an employee **or** a partner, never both — a partner is
/// just another executor, which is what makes "how long did they take"
/// answerable from [startedAt] and [completedAt].
class TaskSummary {
  const TaskSummary({
    required this.id,
    required this.requestId,
    required this.requestNumber,
    required this.requestStatus,
    required this.customerName,
    required this.type,
    required this.title,
    required this.status,
    this.requestItemId,
    this.itemName,
    this.description,
    this.assigneeId,
    this.assigneeName,
    this.partnerId,
    this.partnerName,
    this.dueAt,
    this.startedAt,
    this.completedAt,
    this.isOverdue = false,
    this.isUnassigned = false,
  });

  factory TaskSummary.fromJson(Map<String, dynamic> j) => TaskSummary(
        id: j['id'] as String,
        requestId: j['request_id'] as String,
        requestNumber: parseInt(j['request_number']),
        requestStatus: RequestStatus.fromWire(j['request_status'] as String),
        customerName: j['customer_name'] as String,
        requestItemId: j['request_item_id'] as String?,
        itemName: str(j['item_name']),
        type: TaskType.fromWire(j['type'] as String),
        title: j['title'] as String,
        description: str(j['description']),
        status: TaskStatus.fromWire(j['status'] as String),
        assigneeId: j['assignee_id'] as String?,
        assigneeName: str(j['assignee_name']),
        partnerId: j['partner_id'] as String?,
        partnerName: str(j['partner_name']),
        dueAt: parseTimestampOrNull(j['due_at']),
        startedAt: parseTimestampOrNull(j['started_at']),
        completedAt: parseTimestampOrNull(j['completed_at']),
        isOverdue: parseBool(j['is_overdue']),
        isUnassigned: parseBool(j['is_unassigned']),
      );

  /// The inverse of [TaskSummary.fromJson]. See [RequestSummary.toJson].
  Map<String, dynamic> toJson() => {
        'id': id,
        'request_id': requestId,
        'request_number': requestNumber,
        'request_status': requestStatus.wire,
        'customer_name': customerName,
        'request_item_id': requestItemId,
        'item_name': itemName,
        'type': type.wire,
        'title': title,
        'description': description,
        'status': status.wire,
        'assignee_id': assigneeId,
        'assignee_name': assigneeName,
        'partner_id': partnerId,
        'partner_name': partnerName,
        'due_at': dueAt?.toUtc().toIso8601String(),
        'started_at': startedAt?.toUtc().toIso8601String(),
        'completed_at': completedAt?.toUtc().toIso8601String(),
        'is_overdue': isOverdue,
        'is_unassigned': isUnassigned,
      };

  final String id;
  final String requestId;
  final int requestNumber;
  final RequestStatus requestStatus;
  final String customerName;
  final String? requestItemId;
  final String? itemName;
  final TaskType type;
  final String title;
  final String? description;
  final TaskStatus status;
  final String? assigneeId;
  final String? assigneeName;
  final String? partnerId;
  final String? partnerName;
  final DateTime? dueAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final bool isOverdue;
  final bool isUnassigned;

  String get executorName => assigneeName ?? partnerName ?? 'Unassigned';

  bool get isExternal => partnerId != null;

  /// How long it actually took. For a partner this is the turnaround figure
  /// that tells you whether to keep using them.
  Duration? get duration => (startedAt != null && completedAt != null)
      ? completedAt!.difference(startedAt!)
      : null;
}
