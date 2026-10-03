import 'package:supabase_flutter/supabase_flutter.dart';

import '../enums/employee_role.dart';
import '../enums/enums.dart';
import '../models/back_office.dart';
import '../models/converters.dart';
import '../models/employee.dart';
import 'errors.dart';

/// Stock: items, what they cost (managers only), and the movement ledger the
/// quantity on hand is computed from.
class InventoryRepository {
  InventoryRepository(this._db);

  final SupabaseClient _db;

  Future<List<InventoryItem>> items({bool includeArchived = false}) async {
    var q = _db.from('v_inventory').select();
    if (!includeArchived) q = q.eq('is_active', true);
    final rows = await q.order('name', ascending: true);
    return rows.map(InventoryItem.fromJson).toList();
  }

  /// Unit cost by item id. Empty for anyone who can't see money — RLS returns
  /// no rows rather than an error.
  Future<Map<String, double>> costs() async {
    final rows =
        await _db.from('inventory_item_costs').select('item_id, unit_cost');
    return {
      for (final r in rows) r['item_id'] as String: parseNum(r['unit_cost']),
    };
  }

  Future<List<StockMovement>> movements(
      {String? itemId, int limit = 200}) async {
    var q = _db.from('v_stock_movements').select();
    if (itemId != null) q = q.eq('item_id', itemId);
    final rows = await q.order('moved_at', ascending: false).limit(limit);
    return rows.map(StockMovement.fromJson).toList();
  }

  Future<String> createItem({
    required String name,
    required String unit,
    String? code,
    String? category,
    double reorderLevel = 0,
    String? location,
    String? notes,
  }) async {
    final rows = await _db.from('inventory_items').insert({
      'name': name.trim(),
      'unit': unit.trim().isEmpty ? 'pcs' : unit.trim(),
      'code': _blank(code),
      'category': _blank(category),
      'reorder_level': reorderLevel,
      'location': _blank(location),
      'notes': _blank(notes),
    }).select('id');
    return requireRow(rows, 'add a stock item')['id'] as String;
  }

  Future<void> updateItem(
    String id, {
    required String name,
    required String unit,
    String? code,
    String? category,
    double reorderLevel = 0,
    String? location,
    String? notes,
  }) async {
    final rows = await _db
        .from('inventory_items')
        .update({
          'name': name.trim(),
          'unit': unit.trim().isEmpty ? 'pcs' : unit.trim(),
          'code': _blank(code),
          'category': _blank(category),
          'reorder_level': reorderLevel,
          'location': _blank(location),
          'notes': _blank(notes),
        })
        .eq('id', id)
        .select('id');
    requireRow(rows, 'change this stock item');
  }

  Future<void> setActive(String id, bool active) async {
    final rows = await _db
        .from('inventory_items')
        .update({'is_active': active})
        .eq('id', id)
        .select('id');
    requireRow(rows, active ? 'restore this item' : 'archive this item');
  }

  Future<void> setCost(String itemId, double? unitCost) async {
    if (unitCost == null) {
      await _db.from('inventory_item_costs').delete().eq('item_id', itemId);
      return;
    }
    final rows = await _db
        .from('inventory_item_costs')
        .upsert({'item_id': itemId, 'unit_cost': unitCost}).select('item_id');
    requireRow(rows, 'set the cost');
  }

  /// [quantity] is the amount moved, always positive; the sign comes from
  /// [kind]. For a stock count, pass [countedOnHand] instead and the
  /// difference from [currentOnHand] is recorded.
  Future<void> record({
    required String itemId,
    required StockMovementKind kind,
    double? quantity,
    double? countedOnHand,
    double currentOnHand = 0,
    String? note,
    DateTime? movedAt,
  }) async {
    final double delta = switch (kind) {
      StockMovementKind.stockIn => quantity!.abs(),
      StockMovementKind.stockOut => -quantity!.abs(),
      StockMovementKind.adjust => countedOnHand! - currentOnHand,
    };
    if (delta == 0) return; // the count matched: nothing to record
    final rows = await _db.from('stock_movements').insert({
      'item_id': itemId,
      'kind': kind.wire,
      'quantity': delta,
      'note': _blank(note),
      if (movedAt != null) 'moved_at': movedAt.toUtc().toIso8601String(),
    }).select('id');
    requireRow(rows, 'record stock');
  }
}

/// The shop's own spending. Corrected by editing or voiding — never deleted;
/// the database logs each step.
class ExpenseRepository {
  ExpenseRepository(this._db);

  final SupabaseClient _db;

  Future<List<Expense>> between(
    DateTime from,
    DateTime to, {
    bool includeVoid = false,
  }) async {
    var q = _db
        .from('expenses')
        .select()
        .gte('spent_on', dateToWire(from)!)
        .lte('spent_on', dateToWire(to)!);
    if (!includeVoid) q = q.isFilter('voided_at', null);
    final rows = await q
        .order('spent_on', ascending: false)
        .order('created_at', ascending: false);
    return rows.map(Expense.fromJson).toList();
  }

  /// Categories already used, most used first — the suggestions list.
  Future<List<String>> categories() async {
    final rows = await _db.from('expenses').select('category').limit(1000);
    final counts = <String, int>{};
    for (final r in rows) {
      final c = (r['category'] as String).trim();
      counts[c] = (counts[c] ?? 0) + 1;
    }
    return counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
  }

  Future<void> record({
    required DateTime spentOn,
    required String category,
    required double amount,
    required PaymentMethod method,
    bool isMonthly = false,
    String? description,
    String? paidTo,
    String? reference,
  }) async {
    final rows = await _db.from('expenses').insert({
      'spent_on': dateToWire(spentOn),
      'category': category.trim(),
      'amount': amount,
      'method': method.wire,
      'is_monthly': isMonthly,
      'description': _blank(description),
      'paid_to': _blank(paidTo),
      'reference': _blank(reference),
    }).select('id');
    requireRow(rows, 'record an expense');
  }

  Future<void> update(
    String id, {
    required DateTime spentOn,
    required String category,
    required double amount,
    required PaymentMethod method,
    required bool isMonthly,
    String? description,
    String? paidTo,
    String? reference,
  }) async {
    final rows = await _db
        .from('expenses')
        .update({
          'spent_on': dateToWire(spentOn),
          'category': category.trim(),
          'amount': amount,
          'method': method.wire,
          'is_monthly': isMonthly,
          'description': _blank(description),
          'paid_to': _blank(paidTo),
          'reference': _blank(reference),
        })
        .eq('id', id)
        .select('id');
    requireRow(rows, 'change this expense');
  }

  Future<void> voidExpense(String id, String reason) async {
    final rows = await _db
        .from('expenses')
        .update({
          'voided_at': DateTime.now().toUtc().toIso8601String(),
          'void_reason': reason.trim(),
        })
        .eq('id', id)
        .select('id');
    requireRow(rows, 'void this expense');
  }
}

/// The letterhead on printed reports.
class BusinessProfileRepository {
  BusinessProfileRepository(this._db);

  final SupabaseClient _db;

  Future<BusinessProfile> get() async {
    final row = await _db.from('business_profile').select().maybeSingle();
    return row == null
        ? BusinessProfile.fallback
        : BusinessProfile.fromJson(row);
  }

  Future<void> save(BusinessProfile p) async {
    final rows = await _db
        .from('business_profile')
        .update(p.toJson())
        .eq('id', true)
        .select('id');
    requireRow(rows, 'change the business details');
  }
}

/// Refused by the staff-admin function, with a message meant for a person.
class StaffAdminException implements Exception {
  const StaffAdminException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

/// Staff accounts. Name, phone, role and access are ordinary updates the
/// database polices (trg_employees_restrict_role); creating, deleting and
/// passwords go through the staff-admin Edge Function, which holds the Auth
/// admin key no client may have.
class StaffRepository {
  StaffRepository(this._db);

  final SupabaseClient _db;

  Future<List<Employee>> all() async {
    final rows = await _db
        .from('employees')
        .select()
        .order('is_active', ascending: false)
        .order('full_name', ascending: true);
    return rows.map(Employee.fromJson).toList();
  }

  /// Creates the sign-in, then gives it a name, role and access — as the
  /// caller, so the history says who did it.
  Future<String> create({
    required String email,
    required String password,
    required String fullName,
    required EmployeeRole role,
    String? phone,
  }) async {
    final res = await _invoke({
      'action': 'create',
      'email': email.trim(),
      'password': password,
      'full_name': fullName.trim(),
    });
    final id = res['id'] as String;
    final rows = await _db
        .from('employees')
        .update({
          'full_name': fullName.trim(),
          'phone': _blank(phone),
          'role': role.wire,
          'is_active': true,
        })
        .eq('id', id)
        .select('id');
    requireRow(rows, 'set up this account');
    return id;
  }

  Future<void> updateProfile(
    String id, {
    required String fullName,
    String? phone,
    EmployeeRole? role,
  }) async {
    final rows = await _db
        .from('employees')
        .update({
          'full_name': fullName.trim(),
          'phone': _blank(phone),
          if (role != null) 'role': role.wire,
        })
        .eq('id', id)
        .select('id');
    requireRow(rows, 'change this account');
  }

  Future<void> setActive(String id, bool active) async {
    final rows = await _db
        .from('employees')
        .update({'is_active': active})
        .eq('id', id)
        .select('id');
    requireRow(rows, active ? 'restore access' : 'remove access');
  }

  Future<void> setPassword(String id, String password) =>
      _invoke({'action': 'set_password', 'user_id': id, 'password': password});

  /// Only an account that never did anything; anyone in the history is
  /// refused with code `has_history` — switch them off instead.
  Future<void> delete(String id) =>
      _invoke({'action': 'delete', 'user_id': id});

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    try {
      final res = await _db.functions.invoke('staff-admin', body: body);
      return asMap(res.data);
    } on FunctionException catch (e) {
      final d = e.details;
      if (d is Map && d['message'] is String) {
        throw StaffAdminException(
            (d['error'] as String?) ?? 'error', d['message'] as String);
      }
      throw StaffAdminException(
          'unavailable',
          e.status == 404
              ? 'Staff management isn’t set up on the server yet.'
              : 'The server couldn’t do that (${e.status}).');
    }
  }
}

String? _blank(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
