import '../enums/enums.dart';
import '../util/formatting.dart';
import 'converters.dart';

/// A row of `v_request_summary` — the shared read model.
///
/// Deliberately money-free: the view has no money columns, so no screen can
/// leak a price by forgetting to strip one. Financials come from
/// [RequestFinancials], which only a supervisor or the owner can read.
class RequestSummary {
  const RequestSummary({
    required this.id,
    required this.number,
    required this.status,
    required this.source,
    required this.createdAt,
    required this.customerId,
    required this.customerName,
    this.waitingOn,
    this.title,
    this.neededBy,
    this.completedAt,
    this.customerPhone,
    this.customerCompany,
    this.supervisorId,
    this.supervisorName,
    this.itemCount = 0,
    this.openTaskCount = 0,
  });

  factory RequestSummary.fromJson(Map<String, dynamic> j) => RequestSummary(
        id: j['id'] as String,
        number: parseInt(j['number']),
        status: RequestStatus.fromWire(j['status'] as String),
        waitingOn: j['waiting_on'] == null
            ? null
            : WaitingReason.fromWire(j['waiting_on'] as String),
        source: RequestSource.fromWire(j['source'] as String),
        title: str(j['title']),
        neededBy: parseDateOrNull(j['needed_by']),
        createdAt: parseTimestamp(j['created_at']),
        completedAt: parseTimestampOrNull(j['completed_at']),
        customerId: j['customer_id'] as String,
        customerName: j['customer_name'] as String,
        customerPhone: str(j['customer_phone']),
        customerCompany: str(j['customer_company']),
        supervisorId: j['supervisor_id'] as String?,
        supervisorName: str(j['supervisor_name']),
        itemCount: parseInt(j['item_count'] ?? 0),
        openTaskCount: parseInt(j['open_task_count'] ?? 0),
      );

  /// The inverse of [RequestSummary.fromJson], with the view's column names.
  ///
  /// Only the owner's phone uses it, to keep the last overview on disk. Any
  /// field added to fromJson must be added here too — the round-trip test in
  /// `test/model_json_test.dart` fails if the two drift apart.
  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'status': status.wire,
        'waiting_on': waitingOn?.wire,
        'source': source.wire,
        'title': title,
        'needed_by': dateToWire(neededBy),
        'created_at': createdAt.toUtc().toIso8601String(),
        'completed_at': completedAt?.toUtc().toIso8601String(),
        'customer_id': customerId,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'customer_company': customerCompany,
        'supervisor_id': supervisorId,
        'supervisor_name': supervisorName,
        'item_count': itemCount,
        'open_task_count': openTaskCount,
      };

  final String id;
  final int number;
  final RequestStatus status;

  /// Why it is not moving. Orthogonal to [status] — a job blocked on payment
  /// is still in PRODUCTION.
  final WaitingReason? waitingOn;
  final RequestSource source;
  final String? title;
  final DateTime? neededBy;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String customerId;
  final String customerName;
  final String? customerPhone;
  final String? customerCompany;
  final String? supervisorId;
  final String? supervisorName;
  final int itemCount;
  final int openTaskCount;

  String get reference => '#$number';

  bool get isBlocked => waitingOn != null;

  bool get isOverdue =>
      neededBy != null && status.isOpen && neededBy!.isBefore(DateTime.now());

  /// Nobody owns the customer relationship — usually a website request nobody
  /// has picked up.
  bool get needsSupervisor => supervisorId == null && status.isOpen;

  bool get needsAttention => isBlocked || isOverdue || needsSupervisor;
}

/// The raw `requests` row, as returned by the create_request RPC.
class Request {
  const Request({
    required this.id,
    required this.number,
    required this.customerId,
    required this.status,
    required this.source,
    required this.createdAt,
    this.supervisorId,
    this.waitingOn,
    this.title,
    this.notes,
    this.cancelReason,
    this.neededBy,
  });

  factory Request.fromJson(Map<String, dynamic> j) => Request(
        id: j['id'] as String,
        number: parseInt(j['number']),
        customerId: j['customer_id'] as String,
        supervisorId: j['supervisor_id'] as String?,
        status: RequestStatus.fromWire(j['status'] as String),
        waitingOn: j['waiting_on'] == null
            ? null
            : WaitingReason.fromWire(j['waiting_on'] as String),
        source: RequestSource.fromWire(j['source'] as String),
        title: str(j['title']),
        notes: str(j['notes']),
        cancelReason: str(j['cancel_reason']),
        neededBy: parseDateOrNull(j['needed_by']),
        createdAt: parseTimestamp(j['created_at']),
      );

  final String id;
  final int number;
  final String customerId;
  final String? supervisorId;
  final RequestStatus status;
  final WaitingReason? waitingOn;
  final RequestSource source;
  final String? title;
  final String? notes;
  final String? cancelReason;
  final DateTime? neededBy;
  final DateTime createdAt;
}

class RequestItem {
  const RequestItem({
    required this.id,
    required this.requestId,
    required this.name,
    required this.quantity,
    this.productId,
    this.unit,
    this.specs,
    this.notes,
    this.fulfillment = FulfillmentMode.undecided,
    this.status = ItemStatus.pending,
    this.position = 0,
  });

  factory RequestItem.fromJson(Map<String, dynamic> j) => RequestItem(
        id: j['id'] as String,
        requestId: j['request_id'] as String,
        productId: j['product_id'] as String?,
        name: j['name'] as String,
        quantity: parseNum(j['quantity']),
        unit: str(j['unit']),
        specs: str(j['specs']),
        notes: str(j['notes']),
        fulfillment: FulfillmentMode.fromWire(j['fulfillment'] as String),
        status: ItemStatus.fromWire(j['status'] as String),
        position: parseInt(j['position'] ?? 0),
      );

  final String id;
  final String requestId;
  final String? productId;

  /// A snapshot. Renaming or retiring the catalog product must never rewrite
  /// what the customer asked for.
  final String name;
  final double quantity;
  final String? unit;
  final String? specs;
  final String? notes;
  final FulfillmentMode fulfillment;
  final ItemStatus status;
  final int position;

  /// "5,000 pcs" — grouped, and no pointless `.0`.
  String get quantityLabel {
    final q = Fmt.qty(quantity);
    return (unit == null || unit!.isEmpty) ? q : '$q $unit';
  }
}

/// Money position for one request. OWNER and SUPERVISOR only — for anyone
/// else the view returns no rows at all.
class RequestFinancials {
  const RequestFinancials({
    required this.requestId,
    this.approvedTotal = 0,
    this.paidTotal = 0,
    this.balance = 0,
    this.approvedQuotationCount = 0,
  });

  factory RequestFinancials.fromJson(Map<String, dynamic> j) =>
      RequestFinancials(
        requestId: j['request_id'] as String,
        approvedTotal: parseNum(j['approved_total']),
        paidTotal: parseNum(j['paid_total']),
        balance: parseNum(j['balance']),
        approvedQuotationCount: parseInt(j['approved_quotation_count'] ?? 0),
      );

  final String requestId;
  final double approvedTotal;
  final double paidTotal;
  final double balance;
  final int approvedQuotationCount;

  /// With nothing approved, [balance] is just the negative of what was paid.
  /// Screens must say "paid X, nothing approved yet" rather than show a
  /// negative figure — a down payment before pricing is normal here.
  bool get hasApprovedQuotation => approvedQuotationCount > 0;
}
