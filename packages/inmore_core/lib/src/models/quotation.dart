import '../enums/enums.dart';
import 'converters.dart';

/// A priced offer against a request.
///
/// Versioned and never edited once presented: a revision is a new row and the
/// old one becomes SUPERSEDED, so "the price changed twice before they agreed"
/// stays answerable.
class Quotation {
  const Quotation({
    required this.id,
    required this.requestId,
    required this.version,
    required this.status,
    required this.createdAt,
    this.currency = 'QAR',
    this.subtotal = 0,
    this.discount = 0,
    this.total = 0,
    this.validUntil,
    this.notes,
    this.presentedAt,
    this.decidedAt,
  });

  factory Quotation.fromJson(Map<String, dynamic> j) => Quotation(
        id: j['id'] as String,
        requestId: j['request_id'] as String,
        version: parseInt(j['version']),
        status: QuotationStatus.fromWire(j['status'] as String),
        currency: (j['currency'] as String?)?.trim() ?? 'QAR',
        subtotal: parseNum(j['subtotal']),
        discount: parseNum(j['discount']),
        total: parseNum(j['total']),
        validUntil: parseDateOrNull(j['valid_until']),
        notes: str(j['notes']),
        presentedAt: parseTimestampOrNull(j['presented_at']),
        decidedAt: parseTimestampOrNull(j['decided_at']),
        createdAt: parseTimestamp(j['created_at']),
      );

  final String id;
  final String requestId;
  final int version;
  final QuotationStatus status;
  final String currency;
  final double subtotal;
  final double discount;
  final double total;
  final DateTime? validUntil;
  final String? notes;

  /// When it was told to the customer — spoken, phone, WhatsApp. There is no
  /// document; this records the operational fact.
  final DateTime? presentedAt;
  final DateTime? decidedAt;
  final DateTime createdAt;

  String get versionLabel => 'v$version';
}

class QuotationLine {
  const QuotationLine({
    required this.id,
    required this.quotationId,
    required this.requestItemId,
    required this.quantity,
    required this.unitPrice,
    this.description,
    this.lineTotal = 0,
  });

  factory QuotationLine.fromJson(Map<String, dynamic> j) => QuotationLine(
        id: j['id'] as String,
        quotationId: j['quotation_id'] as String,
        requestItemId: j['request_item_id'] as String,
        description: str(j['description']),
        quantity: parseNum(j['quantity']),
        unitPrice: parseNum(j['unit_price']),
        lineTotal: parseNum(j['line_total']),
      );

  final String id;
  final String quotationId;
  final String requestItemId;
  final String? description;
  final double quantity;
  final double unitPrice;
  final double lineTotal;
}

/// A quotation with its lines, which is how every screen actually uses it.
class QuotationWithLines {
  const QuotationWithLines(this.quotation, this.lines);

  final Quotation quotation;
  final List<QuotationLine> lines;

  QuotationLine? lineFor(String requestItemId) {
    for (final l in lines) {
      if (l.requestItemId == requestItemId) return l;
    }
    return null;
  }
}
