import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_providers.dart';
import 'back_office_providers.dart';
import 'data_providers.dart';
import 'owner_providers.dart';

/// Keeps every open screen current without anyone pressing refresh.
///
/// Listens on the tables migrations 006 and 013 publish — `requests`, `tasks`,
/// `activities`, and the stock, expense and staff tables — and invalidates
/// exactly the providers a change touches.
/// Nothing is patched in place: the provider refetches through the same
/// repository and the same RLS as a manual refresh, so a live update can never
/// show a row the reader could not have selected.
///
/// `activities` carries most of the signal. Every state change writes one,
/// with its `request_id` and `event_type`, so a payment recorded on another
/// PC arrives here as a `payment.recorded` insert even though `payments`
/// itself is not published. RLS applies to realtime too: a designer never
/// receives the money events, which is also why their money panels are never
/// invalidated by one.
///
/// Changes are collected for a moment before anything refetches. Creating a
/// request writes the request, one item per product and an activity per item
/// in a single transaction; without the pause that burst would refetch the
/// board a dozen times.
///
/// Watch this from the signed-in shell. It tears the channel down on sign-out
/// and opens a new one for the next person.
final realtimeSyncProvider = Provider<void>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return;

  final client = ref.watch(supabaseClientProvider);
  final pending = _Pending();
  Timer? timer;

  void flush() {
    timer = null;
    final p = pending.take();

    if (p.board) {
      ref
        ..invalidate(boardProvider)
        ..invalidate(ownerSnapshotProvider);
    }
    if (p.tasks) {
      ref
        ..invalidate(myWorkProvider)
        ..invalidate(workloadProvider);
    }
    if (p.money) ref.invalidate(moneySnapshotProvider);
    if (p.customers) ref.invalidate(customerSearchProvider);
    if (p.stock) {
      ref
        ..invalidate(inventoryProvider)
        ..invalidate(stockMovementsProvider);
    }
    if (p.expenses) ref.invalidate(expensesForMonthProvider);
    if (p.staff) {
      ref
        ..invalidate(allStaffProvider)
        ..invalidate(activeEmployeesProvider);
    }

    for (final id in p.requests) {
      ref
        ..invalidate(requestProvider(id))
        ..invalidate(requestActivityProvider(id));
    }
    for (final id in p.items) {
      ref.invalidate(requestItemsProvider(id));
    }
    for (final id in p.requestTasks) {
      ref.invalidate(requestTasksProvider(id));
    }
    for (final id in p.quotations) {
      ref
        ..invalidate(requestQuotationsProvider(id))
        ..invalidate(requestFinancialsProvider(id));
    }
    for (final id in p.payments) {
      ref
        ..invalidate(requestPaymentsProvider(id))
        ..invalidate(requestFinancialsProvider(id));
    }
  }

  void schedule() {
    timer ??= Timer(const Duration(milliseconds: 400), flush);
  }

  String? idOf(PostgresChangePayload p, String column) =>
      (p.newRecord[column] ?? p.oldRecord[column]) as String?;

  final channel = client.channel('inmore-sync-$userId')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'requests',
      callback: (p) {
        pending
          ..board = true
          ..tasks = true // task rows carry the request's stage
          ..request(idOf(p, 'id'));
        schedule();
      },
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'tasks',
      callback: (p) {
        final requestId = idOf(p, 'request_id');
        pending
          ..board = true // open task counts
          ..tasks = true
          ..request(requestId);
        if (requestId != null) pending.requestTasks.add(requestId);
        schedule();
      },
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'activities',
      callback: (p) {
        final requestId = p.newRecord['request_id'] as String?;
        final event = (p.newRecord['event_type'] as String?) ?? '';
        pending.request(requestId);
        if (event.startsWith('customer.')) pending.customers = true;
        if (requestId != null) {
          if (event.startsWith('item.')) {
            pending
              ..items.add(requestId)
              ..board = true;
          }
          if (event.startsWith('quotation.')) {
            pending
              ..quotations.add(requestId)
              ..money = true;
          }
          if (event.startsWith('payment.')) {
            pending
              ..payments.add(requestId)
              ..money = true;
          }
        }
        schedule();
      },
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'inventory_items',
      callback: (_) {
        pending.stock = true;
        schedule();
      },
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'stock_movements',
      callback: (_) {
        pending.stock = true;
        schedule();
      },
    )
    // RLS applies: only owner and supervisors receive these.
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'expenses',
      callback: (_) {
        pending.expenses = true;
        schedule();
      },
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'employees',
      callback: (_) {
        pending.staff = true;
        schedule();
      },
    )
    ..subscribe();

  ref.onDispose(() {
    timer?.cancel();
    client.removeChannel(channel);
  });
});

/// What has changed since the last flush.
class _Pending {
  bool board = false;
  bool tasks = false;
  bool money = false;
  bool customers = false;
  bool stock = false;
  bool expenses = false;
  bool staff = false;
  Set<String> requests = {};
  Set<String> items = {};
  Set<String> requestTasks = {};
  Set<String> quotations = {};
  Set<String> payments = {};

  void request(String? id) {
    if (id != null) requests.add(id);
  }

  _Pending take() {
    final out = _Pending()
      ..board = board
      ..tasks = tasks
      ..money = money
      ..customers = customers
      ..stock = stock
      ..expenses = expenses
      ..staff = staff
      ..requests = requests
      ..items = items
      ..requestTasks = requestTasks
      ..quotations = quotations
      ..payments = payments;
    board = tasks = money = customers = stock = expenses = staff = false;
    requests = {};
    items = {};
    requestTasks = {};
    quotations = {};
    payments = {};
    return out;
  }
}
