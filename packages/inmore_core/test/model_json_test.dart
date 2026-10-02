import 'package:flutter_test/flutter_test.dart';
import 'package:inmore_core/inmore_core.dart';

/// The owner's phone keeps its last overview on disk through these toJson
/// methods. They are hand-written beside hand-written fromJson, so the risk is
/// the usual one: a field added to one and not the other comes back null, and
/// null looks exactly like empty. Round-tripping a fully populated row catches
/// that without a database.
void main() {
  final request = RequestSummary.fromJson({
    'id': 'r1',
    'number': 1042,
    'status': 'PRODUCTION',
    'waiting_on': 'PAYMENT',
    'source': 'WEBSITE',
    'title': 'Cafe opening pack',
    'needed_by': '2026-10-14',
    'created_at': '2026-09-30T08:15:00+00:00',
    'completed_at': '2026-10-01T12:00:00+00:00',
    'customer_id': 'c1',
    'customer_name': 'مقهى الدوحة',
    'customer_phone': '+974 5555 1234',
    'customer_company': 'Doha Cafe W.L.L.',
    'supervisor_id': 's1',
    'supervisor_name': 'Ahmed',
    'item_count': 3,
    'open_task_count': 2,
  });

  final task = TaskSummary.fromJson({
    'id': 't1',
    'request_id': 'r1',
    'request_number': 1042,
    'request_status': 'DESIGN',
    'customer_name': 'Doha Cafe',
    'request_item_id': 'i1',
    'item_name': 'Cups',
    'type': 'PREPRESS',
    'title': 'Cup artwork',
    'description': 'Two colours',
    'status': 'IN_PROGRESS',
    'assignee_id': 'e1',
    'assignee_name': 'Sara',
    'partner_id': 'p1',
    'partner_name': 'PrintCo',
    'due_at': '2026-10-03T10:00:00+00:00',
    'started_at': '2026-10-01T09:00:00+00:00',
    'completed_at': '2026-10-02T09:30:00+00:00',
    'is_overdue': true,
    'is_unassigned': true,
  });

  test('RequestSummary survives a round trip', () {
    final back = RequestSummary.fromJson(request.toJson());
    expect(back.toJson(), request.toJson());
    expect(back.neededBy, DateTime(2026, 10, 14),
        reason: 'a date column must not shift a day through UTC');
    expect(back.createdAt, request.createdAt);
    expect(back.waitingOn, WaitingReason.payment);
  });

  test('TaskSummary survives a round trip', () {
    final back = TaskSummary.fromJson(task.toJson());
    expect(back.toJson(), task.toJson());
    expect(back.duration, task.duration);
  });

  test('owner snapshots survive a round trip', () {
    final snapshot = OwnerSnapshot(
      open: [request],
      completedThisWeek: [request],
      arrivedThisWeek: const [],
    );
    expect(
        OwnerSnapshot.fromJson(snapshot.toJson()).toJson(), snapshot.toJson());

    const money = MoneySnapshot(
      outstanding: 1200.5,
      approved: 5000,
      received: 3799.5,
      requestsOwing: 2,
    );
    expect(MoneySnapshot.fromJson(money.toJson()).toJson(), money.toJson());

    final load = Workload(employeeId: null, name: '', tasks: [task]);
    final back = Workload.fromJson(load.toJson());
    expect(back.toJson(), load.toJson());
    expect(back.isUnassigned, isTrue);
  });

  test('money keeps Western digits in Arabic', () {
    Fmt.locale = 'ar';
    addTearDown(() => Fmt.locale = 'en');
    expect(Fmt.money(1234.5), '1,234.50 ر.ق');
    Fmt.locale = 'en';
    expect(Fmt.money(1234.5), 'QAR 1,234.50');
  });
}
