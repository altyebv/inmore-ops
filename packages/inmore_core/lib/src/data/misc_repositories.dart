import 'package:supabase_flutter/supabase_flutter.dart';

import '../enums/enums.dart';
import '../models/activity.dart';
import '../models/back_office.dart';
import '../models/catalog.dart';
import '../models/employee.dart';
import '../models/export_row.dart';
import '../models/payment.dart';
import 'errors.dart';

class PaymentRepository {
  PaymentRepository(this._db);

  final SupabaseClient _db;

  Future<List<Payment>> forRequest(String requestId) async {
    final rows = await _db
        .from('payments')
        .select()
        .eq('request_id', requestId)
        .order('paid_at', ascending: false);
    return rows.map(Payment.fromJson).toList();
  }

  /// Insert only. There is no update or delete grant on payments for anyone,
  /// so a mistake is corrected by recording the opposite, not by editing.
  Future<Payment> record({
    required String requestId,
    required double amount,
    required PaymentMethod method,
    required PaymentKind kind,
    DateTime? paidAt,
    String? reference,
    String? notes,
  }) async {
    final rows = await _db.from('payments').insert({
      'request_id': requestId,
      'amount': amount,
      'method': method.wire,
      'kind': kind.wire,
      if (paidAt != null) 'paid_at': paidAt.toUtc().toIso8601String(),
      'reference': reference,
      'notes': notes,
    }).select();
    return Payment.fromJson(requireRow(rows, 'record a payment'));
  }
}

class CatalogRepository {
  CatalogRepository(this._db);

  final SupabaseClient _db;

  Future<List<Product>> products({bool activeOnly = true}) async {
    var q = _db.from('products').select();
    if (activeOnly) q = q.eq('is_active', true);
    final rows = await q
        .order('sort_order', ascending: true)
        .order('name', ascending: true);
    return rows.map(Product.fromJson).toList();
  }

  Future<Product> createProduct({
    required String name,
    String? category,
    String? defaultUnit,
  }) async {
    final rows = await _db.from('products').insert({
      'name': name.trim(),
      'category': category,
      'default_unit': defaultUnit,
    }).select();
    return Product.fromJson(requireRow(rows, 'add a product'));
  }

  Future<List<Partner>> partners({bool activeOnly = true}) async {
    var q = _db.from('partners').select();
    if (activeOnly) q = q.eq('is_active', true);
    final rows = await q.order('name', ascending: true);
    return rows.map(Partner.fromJson).toList();
  }

  Future<Partner> createPartner({
    required String name,
    String? contactName,
    String? phone,
    String? services,
  }) async {
    final rows = await _db.from('partners').insert({
      'name': name.trim(),
      'contact_name': contactName,
      'phone': phone,
      'services': services,
    }).select();
    return Partner.fromJson(requireRow(rows, 'add a partner'));
  }
}

class EmployeeRepository {
  EmployeeRepository(this._db);

  final SupabaseClient _db;

  Future<List<Employee>> active() async {
    final rows = await _db
        .from('employees')
        .select()
        .eq('is_active', true)
        .order('full_name', ascending: true);
    return rows.map(Employee.fromJson).toList();
  }
}

/// Feeds the two Excel sheets. Both views are money-bearing, so both return
/// nothing at all for a designer or production user.
class ExportRepository {
  ExportRepository(this._db);

  final SupabaseClient _db;

  Future<List<ExportItemRow>> items({
    DateTime? from,
    DateTime? to,
    String? supervisorId,
    RequestStatus? status,
  }) async {
    var q = _db.from('v_export_items').select();
    // NB: the Items view calls it request_status; the Requests view calls it
    // status. Passing the wrong one filters nothing out and the export looks
    // fine while being wrong.
    q = _applyFilters(
      q,
      from: from,
      to: to,
      status: status,
      statusColumn: 'request_status',
    );
    if (supervisorId != null) {
      // the view exposes the supervisor by name, so filter on the request side
      final ids = await _requestIdsForSupervisor(supervisorId);
      if (ids.isEmpty) return const [];
      q = q.inFilter('request_id', ids);
    }
    final rows = await q
        .order('request_number', ascending: true)
        .order('item_position', ascending: true);
    return rows.map(ExportItemRow.fromJson).toList();
  }

  Future<List<ExportRequestRow>> requests({
    DateTime? from,
    DateTime? to,
    String? supervisorId,
    RequestStatus? status,
  }) async {
    var q = _db.from('v_export_requests').select();
    q = _applyFilters(
      q,
      from: from,
      to: to,
      status: status,
      statusColumn: 'status',
    );
    if (supervisorId != null) {
      final ids = await _requestIdsForSupervisor(supervisorId);
      if (ids.isEmpty) return const [];
      q = q.inFilter('request_id', ids);
    }
    final rows = await q.order('request_number', ascending: true);
    return rows.map(ExportRequestRow.fromJson).toList();
  }

  /// Money received, by the date it was received (not the request's date).
  Future<List<PaymentReportRow>> payments({
    DateTime? from,
    DateTime? to,
    String? supervisorId,
  }) async {
    var q = _db.from('v_report_payments').select();
    if (from != null) q = q.gte('paid_at', from.toUtc().toIso8601String());
    if (to != null) q = q.lte('paid_at', to.toUtc().toIso8601String());
    if (supervisorId != null) q = q.eq('supervisor_id', supervisorId);
    final rows = await q.order('paid_at', ascending: true);
    return rows.map(PaymentReportRow.fromJson).toList();
  }

  PostgrestFilterBuilder<T> _applyFilters<T>(
    PostgrestFilterBuilder<T> q, {
    DateTime? from,
    DateTime? to,
    RequestStatus? status,
    required String statusColumn,
  }) {
    var out = q;
    if (from != null) {
      out = out.gte('request_date', from.toUtc().toIso8601String());
    }
    if (to != null) {
      out = out.lte('request_date', to.toUtc().toIso8601String());
    }
    if (status != null) out = out.eq(statusColumn, status.wire);
    return out;
  }

  Future<List<String>> _requestIdsForSupervisor(String supervisorId) async {
    final rows = await _db
        .from('requests')
        .select('id')
        .eq('supervisor_id', supervisorId);
    return rows.map((r) => r['id'] as String).toList();
  }
}

class ActivityRepository {
  ActivityRepository(this._db);

  final SupabaseClient _db;

  /// Ordered by **id**, not `occurred_at`.
  ///
  /// `now()` is the transaction timestamp, so every event written by one
  /// operation shares it — creating a request with three items writes four
  /// rows with identical timestamps. Only the monotonic id gives the real
  /// order.
  Future<List<ActivityEntry>> forRequest(
    String requestId, {
    int limit = 200,
  }) async {
    final rows = await _db
        .from('v_activity_feed')
        .select()
        .eq('request_id', requestId)
        .order('id', ascending: false)
        .limit(limit);
    return rows.map(ActivityEntry.fromJson).toList();
  }

  /// Everything that happened recently, across all requests. The owner's
  /// "what is going on" feed.
  Future<List<ActivityEntry>> recent({int limit = 100}) async {
    final rows = await _db
        .from('v_activity_feed')
        .select()
        .order('id', ascending: false)
        .limit(limit);
    return rows.map(ActivityEntry.fromJson).toList();
  }
}
