import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../enums/enums.dart';
import '../models/activity.dart';
import '../models/catalog.dart';
import '../models/customer.dart';
import '../models/employee.dart';
import '../models/payment.dart';
import '../models/quotation.dart';
import '../models/request.dart';
import '../models/task.dart';
import 'auth_providers.dart';
import 'repository_providers.dart';

/// Filters for the work board, kept as one value object so the board provider
/// has a single family key.
class BoardFilter {
  const BoardFilter({
    this.openOnly = true,
    this.status,
    this.supervisorId,
    this.search,
  });

  final bool openOnly;
  final RequestStatus? status;
  final String? supervisorId;
  final String? search;

  BoardFilter copyWith({
    bool? openOnly,
    RequestStatus? status,
    String? supervisorId,
    String? search,
    bool clearStatus = false,
    bool clearSupervisor = false,
  }) =>
      BoardFilter(
        openOnly: openOnly ?? this.openOnly,
        status: clearStatus ? null : (status ?? this.status),
        supervisorId:
            clearSupervisor ? null : (supervisorId ?? this.supervisorId),
        search: search ?? this.search,
      );

  @override
  bool operator ==(Object other) =>
      other is BoardFilter &&
      other.openOnly == openOnly &&
      other.status == status &&
      other.supervisorId == supervisorId &&
      other.search == search;

  @override
  int get hashCode => Object.hash(openOnly, status, supervisorId, search);
}

final boardFilterProvider =
    StateProvider<BoardFilter>((ref) => const BoardFilter());

final boardProvider = FutureProvider<List<RequestSummary>>((ref) async {
  final f = ref.watch(boardFilterProvider);
  return ref.watch(requestRepositoryProvider).board(
        openOnly: f.openOnly,
        status: f.status,
        supervisorId: f.supervisorId,
        search: f.search,
      );
});

final customerSearchProvider =
    FutureProvider.family<List<Customer>, String>((ref, query) async {
  return ref.watch(customerRepositoryProvider).search(query);
});

/// Customers already on this number. Empty for a blank number.
final duplicatePhoneProvider =
    FutureProvider.family<List<Customer>, String>((ref, phone) async {
  return ref.watch(customerRepositoryProvider).sharingPhone(phone);
});

final customerProvider =
    FutureProvider.family<Customer, String>((ref, id) async {
  return ref.watch(customerRepositoryProvider).byId(id);
});

final requestProvider =
    FutureProvider.family<RequestSummary, String>((ref, id) async {
  return ref.watch(requestRepositoryProvider).summary(id);
});

final requestItemsProvider =
    FutureProvider.family<List<RequestItem>, String>((ref, requestId) async {
  return ref.watch(requestRepositoryProvider).items(requestId);
});

/// Null for a designer or production user — the view returns no rows for
/// them, which is the answer, not an error.
final requestFinancialsProvider =
    FutureProvider.family<RequestFinancials?, String>((ref, requestId) async {
  return ref.watch(requestRepositoryProvider).financials(requestId);
});

final requestTasksProvider =
    FutureProvider.family<List<TaskSummary>, String>((ref, requestId) async {
  return ref.watch(taskRepositoryProvider).forRequest(requestId);
});

final requestQuotationsProvider =
    FutureProvider.family<List<QuotationWithLines>, String>(
        (ref, requestId) async {
  return ref.watch(quotationRepositoryProvider).forRequest(requestId);
});

final requestPaymentsProvider =
    FutureProvider.family<List<Payment>, String>((ref, requestId) async {
  return ref.watch(paymentRepositoryProvider).forRequest(requestId);
});

final requestActivityProvider =
    FutureProvider.family<List<ActivityEntry>, String>((ref, requestId) async {
  return ref.watch(activityRepositoryProvider).forRequest(requestId);
});

/// Open tasks assigned to the signed-in person.
final myWorkProvider = FutureProvider<List<TaskSummary>>((ref) async {
  final me = await ref.watch(currentEmployeeProvider.future);
  if (me == null) return const [];
  return ref.watch(taskRepositoryProvider).myWork(me.id);
});

final productsProvider = FutureProvider<List<Product>>((ref) async {
  return ref.watch(catalogRepositoryProvider).products();
});

final partnersProvider = FutureProvider<List<Partner>>((ref) async {
  return ref.watch(catalogRepositoryProvider).partners();
});

final activeEmployeesProvider = FutureProvider<List<Employee>>((ref) async {
  return ref.watch(employeeRepositoryProvider).active();
});

/// Invalidate everything that hangs off one request after a mutation.
///
/// A single call site means a new panel added to the detail screen cannot be
/// forgotten here — which is how a screen ends up showing a stale total next
/// to a fresh payment.
void refreshRequest(WidgetRef ref, String requestId) {
  ref
    ..invalidate(requestProvider(requestId))
    ..invalidate(requestItemsProvider(requestId))
    ..invalidate(requestFinancialsProvider(requestId))
    ..invalidate(requestTasksProvider(requestId))
    ..invalidate(requestQuotationsProvider(requestId))
    ..invalidate(requestPaymentsProvider(requestId))
    ..invalidate(requestActivityProvider(requestId))
    ..invalidate(boardProvider)
    ..invalidate(myWorkProvider);
}
