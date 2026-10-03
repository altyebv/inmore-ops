import '../enums/enums.dart';
import 'converters.dart';

/// A stock item, from `v_inventory`. [onHand] is computed by the database from
/// the movement ledger — it is never written directly.
class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.name,
    required this.unit,
    required this.reorderLevel,
    required this.onHand,
    required this.isLow,
    required this.isActive,
    this.code,
    this.category,
    this.location,
    this.notes,
    this.lastMovedAt,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> j) => InventoryItem(
        id: j['id'] as String,
        name: j['name'] as String,
        code: str(j['code']),
        category: str(j['category']),
        unit: (j['unit'] as String?) ?? 'pcs',
        reorderLevel: parseNum(j['reorder_level']),
        location: str(j['location']),
        notes: str(j['notes']),
        isActive: parseBool(j['is_active'], fallback: true),
        onHand: parseNum(j['on_hand']),
        lastMovedAt: parseTimestampOrNull(j['last_moved_at']),
        isLow: parseBool(j['is_low']),
      );

  final String id;
  final String name;
  final String? code;
  final String? category;
  final String unit;
  final double reorderLevel;
  final String? location;
  final String? notes;
  final bool isActive;
  final double onHand;
  final DateTime? lastMovedAt;

  /// At or below its reorder level (and it has one).
  final bool isLow;

  bool get isOut => onHand <= 0;
}

class StockMovement {
  const StockMovement({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.unit,
    required this.kind,
    required this.quantity,
    required this.movedAt,
    this.note,
    this.recordedByName,
  });

  factory StockMovement.fromJson(Map<String, dynamic> j) => StockMovement(
        id: parseInt(j['id']),
        itemId: j['item_id'] as String,
        itemName: j['item_name'] as String,
        unit: (j['unit'] as String?) ?? 'pcs',
        kind: StockMovementKind.fromWire(j['kind'] as String),
        quantity: parseNum(j['quantity']),
        note: str(j['note']),
        movedAt: parseTimestamp(j['moved_at']),
        recordedByName: str(j['recorded_by_name']),
      );

  final int id;
  final String itemId;
  final String itemName;
  final String unit;
  final StockMovementKind kind;

  /// Signed: positive came in, negative went out.
  final double quantity;
  final String? note;
  final DateTime movedAt;
  final String? recordedByName;
}

/// Something the shop spent. Money — owner and supervisors only.
class Expense {
  const Expense({
    required this.id,
    required this.spentOn,
    required this.category,
    required this.amount,
    required this.method,
    required this.isMonthly,
    required this.createdAt,
    this.description,
    this.paidTo,
    this.reference,
    this.recordedBy,
    this.voidedAt,
    this.voidReason,
  });

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
        id: j['id'] as String,
        spentOn: parseDateOrNull(j['spent_on'])!,
        category: j['category'] as String,
        description: str(j['description']),
        paidTo: str(j['paid_to']),
        amount: parseNum(j['amount']),
        method: PaymentMethod.fromWire(j['method'] as String),
        isMonthly: parseBool(j['is_monthly']),
        reference: str(j['reference']),
        recordedBy: str(j['recorded_by']),
        createdAt: parseTimestamp(j['created_at']),
        voidedAt: parseTimestampOrNull(j['voided_at']),
        voidReason: str(j['void_reason']),
      );

  final String id;
  final DateTime spentOn;
  final String category;
  final String? description;
  final String? paidTo;
  final double amount;
  final PaymentMethod method;

  /// A monthly fixed cost (rent, salaries) rather than a day-to-day one.
  final bool isMonthly;
  final String? reference;
  final String? recordedBy;
  final DateTime createdAt;
  final DateTime? voidedAt;
  final String? voidReason;

  bool get isVoid => voidedAt != null;
}

/// A payment received, for the Payments report (`v_report_payments`).
class PaymentReportRow {
  const PaymentReportRow({
    required this.id,
    required this.paidAt,
    required this.amount,
    required this.method,
    required this.kind,
    required this.requestNumber,
    required this.customer,
    this.requestTitle,
    this.company,
    this.reference,
    this.notes,
    this.supervisor,
    this.supervisorId,
    this.recordedBy,
  });

  factory PaymentReportRow.fromJson(Map<String, dynamic> j) => PaymentReportRow(
        id: j['id'] as String,
        paidAt: parseTimestamp(j['paid_at']),
        amount: parseNum(j['amount']),
        method: PaymentMethod.fromWire(j['method'] as String),
        kind: PaymentKind.fromWire(j['kind'] as String),
        reference: str(j['reference']),
        notes: str(j['notes']),
        requestNumber: parseInt(j['request_number']),
        requestTitle: str(j['request_title']),
        customer: j['customer'] as String,
        company: str(j['company']),
        supervisor: str(j['supervisor']),
        supervisorId: str(j['supervisor_id']),
        recordedBy: str(j['recorded_by']),
      );

  final String id;
  final DateTime paidAt;
  final double amount;
  final PaymentMethod method;
  final PaymentKind kind;
  final String? reference;
  final String? notes;
  final int requestNumber;
  final String? requestTitle;
  final String customer;
  final String? company;
  final String? supervisor;
  final String? supervisorId;
  final String? recordedBy;
}

/// The letterhead on printed reports. One row.
class BusinessProfile {
  const BusinessProfile({
    required this.name,
    this.tagline,
    this.phone,
    this.email,
    this.address,
    this.crNumber,
    this.website,
  });

  factory BusinessProfile.fromJson(Map<String, dynamic> j) => BusinessProfile(
        name: str(j['name']) ?? 'Inmore',
        tagline: str(j['tagline']),
        phone: str(j['phone']),
        email: str(j['email']),
        address: str(j['address']),
        crNumber: str(j['cr_number']),
        website: str(j['website']),
      );

  static const fallback = BusinessProfile(
    name: 'Inmore',
    tagline: 'Branding · Advertising · Packaging',
  );

  final String name;
  final String? tagline;
  final String? phone;
  final String? email;
  final String? address;
  final String? crNumber;
  final String? website;

  Map<String, dynamic> toJson() => {
        'name': name.trim(),
        'tagline': tagline,
        'phone': phone,
        'email': email,
        'address': address,
        'cr_number': crNumber,
        'website': website,
      };

  /// Contact details on one line, for a page header.
  String get contactLine => [phone, email, website]
      .whereType<String>()
      .where((s) => s.isNotEmpty)
      .join('  ·  ');
}
