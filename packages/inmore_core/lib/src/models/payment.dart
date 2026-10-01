import '../enums/enums.dart';
import 'converters.dart';

/// Money received against a request. Recorded, never edited or deleted —
/// there is no UPDATE grant on the table for anyone.
class Payment {
  const Payment({
    required this.id,
    required this.requestId,
    required this.amount,
    required this.method,
    required this.kind,
    required this.paidAt,
    this.currency = 'QAR',
    this.reference,
    this.notes,
  });

  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
        id: j['id'] as String,
        requestId: j['request_id'] as String,
        amount: parseNum(j['amount']),
        currency: (j['currency'] as String?)?.trim() ?? 'QAR',
        method: PaymentMethod.fromWire(j['method'] as String),
        kind: PaymentKind.fromWire(j['kind'] as String),
        paidAt: parseTimestamp(j['paid_at']),
        reference: str(j['reference']),
        notes: str(j['notes']),
      );

  final String id;
  final String requestId;
  final double amount;
  final String currency;
  final PaymentMethod method;

  /// What it was *meant* to be. Whether the request is paid in full is derived
  /// from the sum against the approved total, never from this.
  final PaymentKind kind;
  final DateTime paidAt;
  final String? reference;
  final String? notes;
}
