import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/customer.dart';
import 'errors.dart';

class CustomerRepository {
  CustomerRepository(this._db);

  final SupabaseClient _db;

  /// Name, company and phone in one call, ranked by trigram similarity.
  ///
  /// Phone matching is on the normalized column, so "+974 5555 1234",
  /// "97455551234" and "5555-1234" all find the same records.
  Future<List<Customer>> search(String query, {int limit = 25}) async {
    final rows = await _db.rpc<List<dynamic>>(
      'search_customers',
      params: {'p_query': query, 'p_limit': limit},
    );
    return rows
        .map((r) => Customer.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Customers already using this number. Drives the duplicate warning shown
  /// *as the supervisor types*, before a second record exists.
  Future<List<Customer>> sharingPhone(String phone, {String? excludeId}) async {
    if (phone.trim().isEmpty) return const [];
    final rows = await _db.rpc<List<dynamic>>(
      'customers_sharing_phone',
      params: {'p_phone': phone, 'p_exclude_id': excludeId},
    );
    return rows
        .map((r) => Customer.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<Customer> byId(String id) async {
    final row = await _db.from('customers').select().eq('id', id).maybeSingle();
    if (row == null) throw const NotFoundException('That customer');
    return Customer.fromJson(row);
  }

  Future<Customer> create({
    required String name,
    String? phone,
    String? company,
    String? email,
    String? notes,
  }) async {
    final rows = await _db.from('customers').insert({
      'name': name.trim(),
      'phone': _blankToNull(phone),
      'company': _blankToNull(company),
      'email': _blankToNull(email),
      'notes': _blankToNull(notes),
    }).select();
    return Customer.fromJson(requireRow(rows, 'add a customer'));
  }

  Future<Customer> update(
    String id, {
    required String name,
    String? phone,
    String? company,
    String? email,
    String? notes,
  }) async {
    final rows = await _db
        .from('customers')
        .update({
          'name': name.trim(),
          'phone': _blankToNull(phone),
          'company': _blankToNull(company),
          'email': _blankToNull(email),
          'notes': _blankToNull(notes),
        })
        .eq('id', id)
        .select();
    return Customer.fromJson(requireRow(rows, 'edit this customer'));
  }

  /// Customers are archived, never deleted — their requests outlive them.
  Future<void> setArchived(String id, {required bool archived}) async {
    final rows = await _db
        .from('customers')
        .update({'is_archived': archived})
        .eq('id', id)
        .select();
    requireRow(rows, 'archive this customer');
  }

  static String? _blankToNull(String? v) {
    final t = v?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }
}
