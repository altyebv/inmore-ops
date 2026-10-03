/// Dart mirrors of the PostgreSQL enums.
///
/// The `wire` value must match the database exactly — it is what PostgREST
/// sends and accepts. `label` is what a human reads.
///
/// Every enum here parses unknown values by throwing rather than falling back
/// to a default: a value the client does not know about means the database
/// moved ahead of the app, and silently showing the wrong status is worse than
/// a visible failure.
library;

T _parse<T>(List<T> values, String Function(T) wire, String raw, String type) {
  for (final v in values) {
    if (wire(v) == raw) return v;
  }
  throw ArgumentError('Unknown $type from the database: "$raw"');
}

enum RequestStatus {
  isNew('NEW', 'New'),
  quotation('QUOTATION', 'Quotation'),
  design('DESIGN', 'Design'),
  customerApproval('CUSTOMER_APPROVAL', 'Customer approval'),
  production('PRODUCTION', 'Production'),
  delivery('DELIVERY', 'Delivery'),
  completed('COMPLETED', 'Completed'),
  cancelled('CANCELLED', 'Cancelled');

  const RequestStatus(this.wire, this.label);
  final String wire;
  final String label;

  static RequestStatus fromWire(String v) =>
      _parse(values, (e) => e.wire, v, 'request_status');

  bool get isTerminal => this == completed || this == cancelled;
  bool get isOpen => !isTerminal;

  /// The order the board columns appear in.
  static List<RequestStatus> get pipeline => const [
        isNew,
        quotation,
        design,
        customerApproval,
        production,
        delivery,
      ];
}

/// Why a request is not moving. Orthogonal to [RequestStatus] — a job blocked
/// on payment is still in PRODUCTION, and that is the whole point of keeping
/// these in two columns.
enum WaitingReason {
  customer('CUSTOMER', 'Waiting on customer'),
  payment('PAYMENT', 'Waiting on payment'),
  partner('PARTNER', 'Waiting on partner'),
  internal('INTERNAL', 'On hold');

  const WaitingReason(this.wire, this.label);
  final String wire;
  final String label;

  static WaitingReason fromWire(String v) =>
      _parse(values, (e) => e.wire, v, 'waiting_reason');
}

enum RequestSource {
  supervisor('SUPERVISOR', 'Supervisor'),
  designer('DESIGNER', 'Designer'),
  website('WEBSITE', 'Website'),
  other('OTHER', 'Other');

  const RequestSource(this.wire, this.label);
  final String wire;
  final String label;

  static RequestSource fromWire(String v) =>
      _parse(values, (e) => e.wire, v, 'request_source');
}

/// The customer's decision on one product. Not a progress pipeline — progress
/// lives in that item's tasks.
enum ItemStatus {
  pending('PENDING', 'Pending'),
  approved('APPROVED', 'Approved'),
  rejected('REJECTED', 'Rejected'),
  cancelled('CANCELLED', 'Cancelled');

  const ItemStatus(this.wire, this.label);
  final String wire;
  final String label;

  static ItemStatus fromWire(String v) =>
      _parse(values, (e) => e.wire, v, 'item_status');
}

enum FulfillmentMode {
  undecided('UNDECIDED', 'Undecided'),
  internal('INTERNAL', 'In-house'),
  external('EXTERNAL', 'External');

  const FulfillmentMode(this.wire, this.label);
  final String wire;
  final String label;

  static FulfillmentMode fromWire(String v) =>
      _parse(values, (e) => e.wire, v, 'fulfillment_mode');
}

enum QuotationStatus {
  draft('DRAFT', 'Draft'),

  /// Told to the customer, by any channel — spoken, phone, WhatsApp.
  /// Inmore's quotations are verbal; this records the fact, not a document.
  presented('PRESENTED', 'Presented'),
  approved('APPROVED', 'Approved'),
  rejected('REJECTED', 'Rejected'),
  superseded('SUPERSEDED', 'Superseded');

  const QuotationStatus(this.wire, this.label);
  final String wire;
  final String label;

  static QuotationStatus fromWire(String v) =>
      _parse(values, (e) => e.wire, v, 'quotation_status');

  bool get isEditable => this == draft;
  bool get isLive => this == draft || this == presented;
}

enum TaskType {
  design('DESIGN', 'Design'),
  prepress('PREPRESS', 'Prepress'),
  production('PRODUCTION', 'Production'),
  external('EXTERNAL', 'External'),
  delivery('DELIVERY', 'Delivery'),
  other('OTHER', 'Other');

  const TaskType(this.wire, this.label);
  final String wire;
  final String label;

  static TaskType fromWire(String v) =>
      _parse(values, (e) => e.wire, v, 'task_type');
}

enum TaskStatus {
  todo('TODO', 'To do'),
  inProgress('IN_PROGRESS', 'In progress'),
  blocked('BLOCKED', 'Blocked'),
  done('DONE', 'Done'),
  cancelled('CANCELLED', 'Cancelled');

  const TaskStatus(this.wire, this.label);
  final String wire;
  final String label;

  static TaskStatus fromWire(String v) =>
      _parse(values, (e) => e.wire, v, 'task_status');

  bool get isOpen => this == todo || this == inProgress || this == blocked;
}

enum PaymentMethod {
  cash('CASH', 'Cash'),
  online('ONLINE', 'Online'),
  bankTransfer('BANK_TRANSFER', 'Bank transfer'),
  cheque('CHEQUE', 'Cheque');

  const PaymentMethod(this.wire, this.label);
  final String wire;
  final String label;

  static PaymentMethod fromWire(String v) =>
      _parse(values, (e) => e.wire, v, 'payment_method');
}

/// What the payment was *meant* to be. Whether the request is actually paid in
/// full is derived from the sum against the approved total, never from this.
enum PaymentKind {
  downPayment('DOWN_PAYMENT', 'Down payment'),
  partial('PARTIAL', 'Partial'),
  settlement('FINAL', 'Final');

  const PaymentKind(this.wire, this.label);
  final String wire;
  final String label;

  static PaymentKind fromWire(String v) =>
      _parse(values, (e) => e.wire, v, 'payment_kind');
}

enum ActorKind {
  employee('EMPLOYEE', 'Employee'),
  system('SYSTEM', 'System'),
  customer('CUSTOMER', 'Customer');

  const ActorKind(this.wire, this.label);
  final String wire;
  final String label;

  static ActorKind fromWire(String v) =>
      _parse(values, (e) => e.wire, v, 'actor_kind');
}

/// One line in the stock ledger. The quantity is signed: IN adds, OUT takes
/// away, ADJUST (a stock count) moves it either way.
enum StockMovementKind {
  stockIn('IN', 'Received'),
  stockOut('OUT', 'Taken out'),
  adjust('ADJUST', 'Stock count');

  const StockMovementKind(this.wire, this.label);
  final String wire;
  final String label;

  static StockMovementKind fromWire(String v) =>
      _parse(values, (e) => e.wire, v, 'stock_movement_kind');
}
