import 'package:supabase_flutter/supabase_flutter.dart';

import '../enums/enums.dart';
import '../models/quotation.dart';
import 'errors.dart';

/// A price the supervisor is about to put on one request item.
class NewQuotationLine {
  const NewQuotationLine({
    required this.requestItemId,
    required this.unitPrice,
    this.quantity,
    this.description,
  });

  final String requestItemId;
  final double unitPrice;

  /// Null means "use the quantity already on the request item", which is the
  /// default — retyping it is how the two drift apart.
  final double? quantity;
  final String? description;

  Map<String, dynamic> toJson() => {
        'request_item_id': requestItemId,
        'unit_price': unitPrice,
        if (quantity != null) 'quantity': quantity,
        if (description != null && description!.isNotEmpty)
          'description': description,
      };
}

class QuotationRepository {
  QuotationRepository(this._db);

  final SupabaseClient _db;

  Future<List<QuotationWithLines>> forRequest(String requestId) async {
    final quotes = await _db
        .from('quotations')
        .select()
        .eq('request_id', requestId)
        .order('version', ascending: false);
    if (quotes.isEmpty) return const [];

    final lines = await _db.from('quotation_lines').select().inFilter(
        'quotation_id', quotes.map((q) => q['id'] as String).toList());

    final byQuotation = <String, List<QuotationLine>>{};
    for (final raw in lines) {
      final line = QuotationLine.fromJson(raw);
      byQuotation.putIfAbsent(line.quotationId, () => []).add(line);
    }

    return quotes
        .map(
          (q) => QuotationWithLines(
            Quotation.fromJson(q),
            byQuotation[q['id'] as String] ?? const [],
          ),
        )
        .toList();
  }

  /// Totals are computed server-side from the lines — no client ever does
  /// money arithmetic.
  Future<Quotation> create({
    required String requestId,
    required List<NewQuotationLine> lines,
    double discount = 0,
    DateTime? validUntil,
    String? notes,
  }) async {
    final row = await _db.rpc<Map<String, dynamic>>(
      'create_quotation',
      params: {
        'p_request_id': requestId,
        'p_lines': lines.map((l) => l.toJson()).toList(),
        'p_discount': discount,
        'p_valid_until': validUntil?.toIso8601String().split('T').first,
        'p_notes': notes,
      },
    );
    return Quotation.fromJson(row);
  }

  /// Supersedes the current version and issues the next one. Passing null
  /// lines copies the existing ones, for when only the discount changes.
  Future<Quotation> revise({
    required String quotationId,
    List<NewQuotationLine>? lines,
    double? discount,
    DateTime? validUntil,
    String? notes,
  }) async {
    final row = await _db.rpc<Map<String, dynamic>>(
      'revise_quotation',
      params: {
        'p_quotation_id': quotationId,
        'p_lines': lines?.map((l) => l.toJson()).toList(),
        'p_discount': discount,
        'p_valid_until': validUntil?.toIso8601String().split('T').first,
        'p_notes': notes,
      },
    );
    return Quotation.fromJson(row);
  }

  /// Approval may have happened on WhatsApp or across the counter. This
  /// records the operational fact, not the channel.
  ///
  /// Approving is refused by the database if any of this quotation's items is
  /// already covered by another approved quotation — supersede or reject that
  /// one first, or the request total would double-count.
  Future<void> setStatus(String quotationId, QuotationStatus status) async {
    final rows = await _db
        .from('quotations')
        .update({'status': status.wire})
        .eq('id', quotationId)
        .select();
    requireRow(rows, 'change this quotation');
  }
}
