import '../enums/enums.dart';
import 'converters.dart';

/// One row of the Excel **Items** sheet — the shape Inmore's current report
/// already uses (customer, item, price), widened.
///
/// [unitPrice] and [lineTotal] are null until an approved quotation covers the
/// item. That is the honest state; writing zero would make the column sum to
/// something untrue.
class ExportItemRow {
  const ExportItemRow({
    required this.requestNumber,
    required this.requestDate,
    required this.customer,
    required this.item,
    required this.qty,
    required this.itemStatus,
    required this.requestStatus,
    this.company,
    this.phone,
    this.unit,
    this.spec,
    this.unitPrice,
    this.lineTotal,
    this.waitingOn,
    this.supervisor,
    this.neededBy,
    this.completed,
  });

  factory ExportItemRow.fromJson(Map<String, dynamic> j) => ExportItemRow(
        requestNumber: parseInt(j['request_number']),
        requestDate: parseTimestamp(j['request_date']),
        customer: j['customer'] as String,
        company: str(j['company']),
        phone: str(j['phone']),
        item: j['item'] as String,
        qty: parseNum(j['qty']),
        unit: str(j['unit']),
        spec: str(j['spec']),
        unitPrice: parseNumOrNull(j['unit_price']),
        lineTotal: parseNumOrNull(j['line_total']),
        itemStatus: ItemStatus.fromWire(j['item_status'] as String),
        requestStatus: RequestStatus.fromWire(j['request_status'] as String),
        waitingOn: j['waiting_on'] == null
            ? null
            : WaitingReason.fromWire(j['waiting_on'] as String),
        supervisor: str(j['supervisor']),
        neededBy: parseDateOrNull(j['needed_by']),
        completed: parseTimestampOrNull(j['completed']),
      );

  final int requestNumber;
  final DateTime requestDate;
  final String customer;
  final String? company;
  final String? phone;
  final String item;
  final double qty;
  final String? unit;
  final String? spec;
  final double? unitPrice;
  final double? lineTotal;
  final ItemStatus itemStatus;
  final RequestStatus requestStatus;
  final WaitingReason? waitingOn;
  final String? supervisor;
  final DateTime? neededBy;
  final DateTime? completed;
}

/// One row of the Excel **Requests** sheet.
///
/// Request-level money lives here and is never repeated onto item rows:
/// three items each carrying the request total means anyone who sums that
/// column gets triple the real figure.
class ExportRequestRow {
  const ExportRequestRow({
    required this.requestNumber,
    required this.requestDate,
    required this.customer,
    required this.status,
    this.supervisor,
    this.waitingOn,
    this.items = 0,
    this.approvedTotal = 0,
    this.paid = 0,
    this.balance = 0,
    this.approvedQuotationCount = 0,
    this.neededBy,
    this.completed,
  });

  factory ExportRequestRow.fromJson(Map<String, dynamic> j) => ExportRequestRow(
        requestNumber: parseInt(j['request_number']),
        requestDate: parseTimestamp(j['request_date']),
        customer: j['customer'] as String,
        supervisor: str(j['supervisor']),
        status: RequestStatus.fromWire(j['status'] as String),
        waitingOn: j['waiting_on'] == null
            ? null
            : WaitingReason.fromWire(j['waiting_on'] as String),
        items: parseInt(j['items'] ?? 0),
        approvedTotal: parseNum(j['approved_total']),
        paid: parseNum(j['paid']),
        balance: parseNum(j['balance']),
        approvedQuotationCount: parseInt(j['approved_quotation_count'] ?? 0),
        neededBy: parseDateOrNull(j['needed_by']),
        completed: parseTimestampOrNull(j['completed']),
      );

  final int requestNumber;
  final DateTime requestDate;
  final String customer;
  final String? supervisor;
  final RequestStatus status;
  final WaitingReason? waitingOn;
  final int items;
  final double approvedTotal;
  final double paid;
  final double balance;
  final int approvedQuotationCount;
  final DateTime? neededBy;
  final DateTime? completed;
}
