import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/back_office.dart';
import '../models/employee.dart';
import 'auth_providers.dart';
import 'repository_providers.dart';

/// Stock items. Archived ones are included only when asked for.
final inventoryProvider = FutureProvider.family<List<InventoryItem>, bool>(
    (ref, includeArchived) async {
  ref.watch(currentUserIdProvider);
  return ref
      .watch(inventoryRepositoryProvider)
      .items(includeArchived: includeArchived);
});

/// Unit cost by item id — empty for anyone who can't see money.
final inventoryCostsProvider = FutureProvider<Map<String, double>>((ref) async {
  ref.watch(currentUserIdProvider);
  return ref.watch(inventoryRepositoryProvider).costs();
});

/// The movement ledger: one item's, or everything recent for a null id.
final stockMovementsProvider =
    FutureProvider.family<List<StockMovement>, String?>((ref, itemId) async {
  ref.watch(currentUserIdProvider);
  return ref.watch(inventoryRepositoryProvider).movements(itemId: itemId);
});

/// A calendar month of expenses, keyed by its first day. Voided ones included
/// — screens decide whether to show them; totals always leave them out.
final expensesForMonthProvider =
    FutureProvider.family<List<Expense>, DateTime>((ref, month) async {
  ref.watch(currentUserIdProvider);
  final from = DateTime(month.year, month.month);
  final to = DateTime(month.year, month.month + 1, 0);
  return ref
      .watch(expenseRepositoryProvider)
      .between(from, to, includeVoid: true);
});

final expenseCategoriesProvider = FutureProvider<List<String>>((ref) async {
  ref.watch(currentUserIdProvider);
  return ref.watch(expenseRepositoryProvider).categories();
});

/// Everyone, active first — the staff screen.
final allStaffProvider = FutureProvider<List<Employee>>((ref) async {
  ref.watch(currentUserIdProvider);
  return ref.watch(staffRepositoryProvider).all();
});

final businessProfileProvider = FutureProvider<BusinessProfile>((ref) async {
  ref.watch(currentUserIdProvider);
  return ref.watch(businessProfileRepositoryProvider).get();
});

/// Payments received in a calendar month, keyed by its first day — the
/// "money in" beside a month's expenses.
final paymentsForMonthProvider =
    FutureProvider.family<List<PaymentReportRow>, DateTime>((ref, month) async {
  ref.watch(currentUserIdProvider);
  return ref.watch(exportRepositoryProvider).payments(
        from: DateTime(month.year, month.month),
        to: DateTime(month.year, month.month + 1, 1)
            .subtract(const Duration(milliseconds: 1)),
      );
});
