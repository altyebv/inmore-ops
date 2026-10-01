import 'package:supabase_flutter/supabase_flutter.dart';

import '../enums/enums.dart';
import '../models/request.dart';
import 'errors.dart';

/// A draft line on the new-request form, before anything is saved.
class NewRequestItem {
  const NewRequestItem({
    required this.name,
    required this.quantity,
    this.productId,
    this.unit,
    this.specs,
    this.notes,
  });

  final String name;
  final double quantity;
  final String? productId;
  final String? unit;
  final String? specs;
  final String? notes;

  Map<String, dynamic> toJson() => {
        if (productId != null) 'product_id': productId,
        'name': name.trim(),
        'quantity': quantity,
        if (unit != null && unit!.isNotEmpty) 'unit': unit,
        if (specs != null && specs!.isNotEmpty) 'specs': specs,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
      };
}

class RequestRepository {
  RequestRepository(this._db);

  final SupabaseClient _db;

  /// The work board. Reads `v_request_summary`, which has no money columns in
  /// it at all — so this is safe for every role by construction rather than by
  /// remembering to strip something.
  Future<List<RequestSummary>> board({
    bool openOnly = true,
    String? supervisorId,
    RequestStatus? status,
    String? search,
    int limit = 200,
  }) async {
    var q = _db.from('v_request_summary').select();

    if (openOnly) {
      q = q.not('status', 'in', '(COMPLETED,CANCELLED)');
    }
    if (status != null) q = q.eq('status', status.wire);
    if (supervisorId != null) q = q.eq('supervisor_id', supervisorId);
    if (search != null && search.trim().isNotEmpty) {
      final s = search.trim();
      final asNumber = int.tryParse(s.replaceAll('#', ''));
      q = asNumber != null
          ? q.eq('number', asNumber)
          : q.or('customer_name.ilike.%$s%,title.ilike.%$s%');
    }

    final rows = await q.order('created_at', ascending: false).limit(limit);
    return rows.map(RequestSummary.fromJson).toList();
  }

  Future<RequestSummary> summary(String id) async {
    final row =
        await _db.from('v_request_summary').select().eq('id', id).maybeSingle();
    if (row == null) throw const NotFoundException('That request');
    return RequestSummary.fromJson(row);
  }

  /// Creates the request and its items in one database call, so a failure
  /// cannot leave an empty request behind.
  Future<Request> create({
    required String customerId,
    String? title,
    String? notes,
    DateTime? neededBy,
    String? supervisorId,
    List<NewRequestItem> items = const [],
  }) async {
    final row = await _db.rpc<Map<String, dynamic>>(
      'create_request',
      params: {
        'p_customer_id': customerId,
        'p_title': title,
        'p_notes': notes,
        'p_needed_by': neededBy?.toIso8601String().split('T').first,
        'p_supervisor_id': supervisorId,
        'p_items': items.map((i) => i.toJson()).toList(),
      },
    );
    return Request.fromJson(row);
  }

  Future<List<RequestItem>> items(String requestId) async {
    final rows = await _db
        .from('request_items')
        .select()
        .eq('request_id', requestId)
        .order('position', ascending: true);
    return rows.map(RequestItem.fromJson).toList();
  }

  Future<RequestItem> addItem(String requestId, NewRequestItem item) async {
    final existing = await items(requestId);
    final rows = await _db.from('request_items').insert({
      'request_id': requestId,
      ...item.toJson(),
      'position': existing.length + 1,
    }).select();
    return RequestItem.fromJson(requireRow(rows, 'add an item'));
  }

  Future<void> removeItem(String itemId) async {
    final rows =
        await _db.from('request_items').delete().eq('id', itemId).select();
    requireRow(rows, 'remove this item');
  }

  /// Stage only. `waitingOn` is a separate column on purpose: a job blocked on
  /// payment is still in PRODUCTION, and clearing the block must return it to
  /// the stage it never left.
  Future<void> setStatus(String id, RequestStatus status) async {
    final rows = await _db
        .from('requests')
        .update({'status': status.wire})
        .eq('id', id)
        .select();
    requireRow(rows, 'change the status of this request');
  }

  Future<void> setWaiting(String id, WaitingReason? reason) async {
    final rows = await _db
        .from('requests')
        .update({'waiting_on': reason?.wire})
        .eq('id', id)
        .select();
    requireRow(rows, 'change the waiting state of this request');
  }

  /// Status and reason go in one statement — the check constraint requires a
  /// reason the moment the status becomes CANCELLED.
  Future<void> cancel(String id, String reason) async {
    final rows = await _db
        .from('requests')
        .update(
            {'status': RequestStatus.cancelled.wire, 'cancel_reason': reason})
        .eq('id', id)
        .select();
    requireRow(rows, 'cancel this request');
  }

  Future<void> setSupervisor(String id, String? supervisorId) async {
    final rows = await _db
        .from('requests')
        .update({'supervisor_id': supervisorId})
        .eq('id', id)
        .select();
    requireRow(rows, 'change the supervisor');
  }

  Future<void> updateDetails(
    String id, {
    String? title,
    String? notes,
    DateTime? neededBy,
  }) async {
    final rows = await _db
        .from('requests')
        .update({
          'title': title,
          'notes': notes,
          'needed_by': neededBy?.toIso8601String().split('T').first,
        })
        .eq('id', id)
        .select();
    requireRow(rows, 'edit this request');
  }

  /// Money for one request. Returns null for a designer or production user:
  /// the view yields no rows for them, which is the correct answer, not an
  /// error to surface.
  Future<RequestFinancials?> financials(String requestId) async {
    final row = await _db
        .from('v_request_financials')
        .select()
        .eq('request_id', requestId)
        .maybeSingle();
    return row == null ? null : RequestFinancials.fromJson(row);
  }
}
