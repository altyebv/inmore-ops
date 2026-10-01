import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../enums/enums.dart';
import '../models/request.dart';
import '../models/task.dart';
import 'repository_providers.dart';

/// What the owner's overview answers: what is active, what is stuck, what came
/// in, what got done.
///
/// Counts and lists, computed on the client from data that already exists.
/// Deliberately not a SQL rollup or a materialized view — V1's job is to make
/// the data trustworthy, and a dashboard built on three months of shaky data
/// is worse than no dashboard. When the numbers have been right for a quarter,
/// move the arithmetic into Postgres.
class OwnerSnapshot {
  const OwnerSnapshot({
    required this.open,
    required this.completedThisWeek,
    required this.arrivedThisWeek,
  });

  final List<RequestSummary> open;
  final List<RequestSummary> completedThisWeek;
  final List<RequestSummary> arrivedThisWeek;

  int get activeCount => open.length;

  List<RequestSummary> get blocked =>
      open.where((r) => r.isBlocked).toList(growable: false);

  List<RequestSummary> get overdue =>
      open.where((r) => r.isOverdue).toList(growable: false);

  List<RequestSummary> get unowned =>
      open.where((r) => r.needsSupervisor).toList(growable: false);

  /// Everything that wants a decision, newest first, each request once.
  List<RequestSummary> get attention {
    final seen = <String>{};
    final out = <RequestSummary>[];
    for (final r in [...blocked, ...overdue, ...unowned]) {
      if (seen.add(r.id)) out.add(r);
    }
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  /// How many open requests sit at each stage.
  Map<RequestStatus, int> get byStage {
    final counts = <RequestStatus, int>{};
    for (final r in open) {
      counts[r.status] = (counts[r.status] ?? 0) + 1;
    }
    return counts;
  }
}

final ownerSnapshotProvider = FutureProvider<OwnerSnapshot>((ref) async {
  final repo = ref.watch(requestRepositoryProvider);
  final weekAgo = DateTime.now().subtract(const Duration(days: 7));

  final open = await repo.board(openOnly: true, limit: 500);
  final all = await repo.board(openOnly: false, limit: 500);

  return OwnerSnapshot(
    open: open,
    completedThisWeek: all
        .where((r) =>
            r.completedAt != null && r.completedAt!.isAfter(weekAgo))
        .toList(growable: false),
    arrivedThisWeek:
        all.where((r) => r.createdAt.isAfter(weekAgo)).toList(growable: false),
  );
});

/// The money position across the business.
class MoneySnapshot {
  const MoneySnapshot({
    required this.outstanding,
    required this.approved,
    required this.received,
    required this.requestsOwing,
  });

  /// Only counted where a quotation has actually been approved. Without that
  /// guard, a down payment taken before pricing shows as negative money owed,
  /// which is nonsense rather than a number.
  final double outstanding;
  final double approved;
  final double received;
  final int requestsOwing;
}

final moneySnapshotProvider = FutureProvider<MoneySnapshot>((ref) async {
  final rows = await ref.watch(requestRepositoryProvider).financialsAll();
  final priced = rows.where((f) => f.hasApprovedQuotation);

  return MoneySnapshot(
    approved: priced.fold(0, (s, f) => s + f.approvedTotal),
    received: rows.fold(0, (s, f) => s + f.paidTotal),
    outstanding:
        priced.where((f) => f.balance > 0).fold(0, (s, f) => s + f.balance),
    requestsOwing: priced.where((f) => f.balance > 0).length,
  );
});

/// Open work per person, for "who is handling what".
class Workload {
  const Workload({
    required this.employeeId,
    required this.name,
    required this.tasks,
  });

  final String? employeeId;
  final String name;
  final List<TaskSummary> tasks;

  int get overdueCount => tasks.where((t) => t.isOverdue).length;
  int get inProgressCount =>
      tasks.where((t) => t.status == TaskStatus.inProgress).length;
}

final workloadProvider = FutureProvider<List<Workload>>((ref) async {
  final tasks = await ref.watch(taskRepositoryProvider).allOpen();

  final grouped = <String, List<TaskSummary>>{};
  for (final t in tasks) {
    // Unassigned work and partner work both matter to the owner, so they get
    // their own rows rather than being dropped.
    final key = t.assigneeName ?? t.partnerName ?? 'Unassigned';
    grouped.putIfAbsent(key, () => []).add(t);
  }

  final out = grouped.entries
      .map((e) => Workload(
            employeeId: e.value.first.assigneeId,
            name: e.key,
            tasks: e.value,
          ))
      .toList();
  out.sort((a, b) => b.tasks.length.compareTo(a.tasks.length));
  return out;
});
