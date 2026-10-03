@Timeout(Duration(minutes: 3))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:inmore_core/inmore_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Exercises the Dart data layer against the real local database.
///
/// This is the only thing that can catch a mis-mapped column. The models are
/// hand-written, so `name` vs `full_name` or `waiting_on` vs `waitingOn` is a
/// runtime failure that `flutter analyze` is blind to — and a field that
/// silently reads null looks exactly like an empty one on screen.
///
/// Needs the local stack:
///
///   npx supabase db reset && flutter test
///
/// It writes real rows. Run `npx supabase db reset` afterwards to clear them.
void main() {
  const url = 'http://127.0.0.1:54321';
  const key = 'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH';
  const password = 'inmore-dev';

  late SupabaseClient db;

  Future<void> signIn(String email) async {
    await db.auth.signInWithPassword(email: email, password: password);
  }

  setUp(() {
    db = SupabaseClient(url, key);
  });

  tearDown(() async {
    await db.auth.signOut();
    await db.dispose();
  });

  test('supervisor walks a request end to end', () async {
    await signIn('ahmed@inmore.local');

    final customers = CustomerRepository(db);
    final requests = RequestRepository(db);
    final quotations = QuotationRepository(db);
    final payments = PaymentRepository(db);
    final tasks = TaskRepository(db);
    final activity = ActivityRepository(db);

    // --- customer, with the phone normalization that stops duplicates -------
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final customer = await customers.create(
      name: 'Integration Customer $stamp',
      phone: '+974 5555 $stamp'.substring(0, 17),
      company: 'Integration Co.',
    );
    expect(customer.name, contains('Integration Customer'));
    expect(customer.phoneNormalized, isNotNull,
        reason: 'the generated column must come back mapped');

    final found = await customers.search('Integration Customer $stamp');
    expect(found.map((c) => c.id), contains(customer.id));

    // any spelling of the number finds the same record
    final byPhone = await customers.search(customer.phone!.replaceAll(' ', '-'));
    expect(byPhone.map((c) => c.id), contains(customer.id));

    final dupes = await customers.sharingPhone(customer.phone!);
    expect(dupes.map((c) => c.id), contains(customer.id));

    // --- request with several products in one call --------------------------
    final created = await requests.create(
      customerId: customer.id,
      title: 'Integration run',
      neededBy: DateTime.now().add(const Duration(days: 10)),
      items: const [
        NewRequestItem(name: 'Paper Cups', quantity: 5000, unit: 'pcs'),
        NewRequestItem(name: 'Paper Bags', quantity: 2000, unit: 'pcs'),
      ],
    );
    expect(created.number, greaterThanOrEqualTo(1001));
    expect(created.status, RequestStatus.isNew);
    expect(created.source, RequestSource.supervisor);
    expect(created.supervisorId, isNotNull,
        reason: 'a supervisor owns the request they create');

    final summary = await requests.summary(created.id);
    expect(summary.itemCount, 2);
    expect(summary.customerName, customer.name);
    expect(summary.supervisorName, 'Ahmed');
    expect(summary.neededBy, isNotNull);

    final items = await requests.items(created.id);
    expect(items, hasLength(2));
    expect(items.first.quantityLabel, '5,000 pcs');

    // --- stage and blocking are independent ---------------------------------
    await requests.setStatus(created.id, RequestStatus.production);
    await requests.setWaiting(created.id, WaitingReason.payment);
    final blocked = await requests.summary(created.id);
    expect(blocked.status, RequestStatus.production,
        reason: 'blocking must not lose the stage');
    expect(blocked.waitingOn, WaitingReason.payment);
    expect(blocked.isBlocked, isTrue);

    await requests.setWaiting(created.id, null);
    expect((await requests.summary(created.id)).waitingOn, isNull);

    // --- pricing ------------------------------------------------------------
    final quote = await quotations.create(
      requestId: created.id,
      lines: [
        NewQuotationLine(requestItemId: items[0].id, unitPrice: 0.75),
        NewQuotationLine(requestItemId: items[1].id, unitPrice: 1.25),
      ],
      discount: 250,
    );
    expect(quote.subtotal, 6250);
    expect(quote.total, 6000, reason: 'the server applies the discount');
    expect(quote.status, QuotationStatus.draft);

    await quotations.setStatus(quote.id, QuotationStatus.presented);
    await quotations.setStatus(quote.id, QuotationStatus.approved);

    final withLines = await quotations.forRequest(created.id);
    expect(withLines, hasLength(1));
    expect(withLines.first.lines, hasLength(2));
    expect(withLines.first.lineFor(items[0].id)?.lineTotal, 3750);

    // --- money --------------------------------------------------------------
    await payments.record(
      requestId: created.id,
      amount: 2000,
      method: PaymentMethod.cash,
      kind: PaymentKind.downPayment,
    );

    final fin = await requests.financials(created.id);
    expect(fin, isNotNull);
    expect(fin!.approvedTotal, 6000);
    expect(fin.paidTotal, 2000);
    expect(fin.balance, 4000);
    expect(fin.hasApprovedQuotation, isTrue);

    // --- work ---------------------------------------------------------------
    await tasks.create(
      requestId: created.id,
      type: TaskType.design,
      title: 'Cup artwork',
      requestItemId: items[0].id,
      assigneeId: '44444444-4444-4444-4444-444444444444', // Sara
    );
    final taskList = await tasks.forRequest(created.id);
    expect(taskList, hasLength(1));
    expect(taskList.first.assigneeName, 'Sara');
    expect(taskList.first.itemName, 'Paper Cups');
    expect(taskList.first.requestNumber, created.number);

    // --- history ------------------------------------------------------------
    final feed = await activity.forRequest(created.id);
    expect(feed, isNotEmpty);
    expect(feed.map((e) => e.eventType), contains('request.created'));
    expect(feed.map((e) => e.eventType), contains('payment.recorded'));
    expect(feed.first.actorName, isNotEmpty);
    // newest first, ordered by id — not occurred_at, which ties within a
    // transaction
    expect(feed.first.id, greaterThan(feed.last.id));

    // --- export rows --------------------------------------------------------
    final exports = ExportRepository(db);
    final itemRows = await exports.items();
    final requestRows = await exports.requests();
    expect(itemRows, isNotEmpty);
    expect(requestRows, isNotEmpty);

    final mine = itemRows.where((r) => r.requestNumber == created.number);
    expect(mine, hasLength(2));
    expect(mine.first.company, 'Integration Co.');
    expect(mine.map((r) => r.lineTotal).whereType<double>().reduce((a, b) => a + b),
        6250, reason: 'line totals sum to the approved subtotal');

    final mineRequest =
        requestRows.firstWhere((r) => r.requestNumber == created.number);
    expect(mineRequest.approvedTotal, 6000);
    expect(mineRequest.balance, 4000);
    expect(mineRequest.items, 2);

    // --- the workbook actually encodes --------------------------------------
    final bytes = ExcelReport.build(items: itemRows, requests: requestRows);
    expect(bytes, isNotNull);
    expect(bytes!.length, greaterThan(1000));
    // xlsx is a zip: 'PK'
    expect(bytes[0], 0x50);
    expect(bytes[1], 0x4B);
  });

  test('a designer sees the work but none of the money', () async {
    await signIn('sara@inmore.local');

    final session = SessionRepository(db);
    final me = await session.loadCurrentEmployee();
    expect(me, isNotNull);
    expect(me!.role, EmployeeRole.designer);
    expect(me.role.canSeeMoney, isFalse);

    final requests = RequestRepository(db);
    final board = await requests.board(openOnly: false);
    expect(board, isNotEmpty, reason: 'operational data stays visible');

    final target = board.first;

    // Every money route must come back empty, not wrong.
    expect(await requests.financials(target.id), isNull);
    expect(await QuotationRepository(db).forRequest(target.id), isEmpty);
    expect(await PaymentRepository(db).forRequest(target.id), isEmpty);
    expect(await ExportRepository(db).items(), isEmpty);
    expect(await ExportRepository(db).requests(), isEmpty);

    final feed = await ActivityRepository(db).forRequest(target.id);
    expect(feed.where((e) => e.isMoney), isEmpty,
        reason: 'money events are filtered out of the timeline');
    expect(feed, isNotEmpty, reason: 'the operational story is still there');
  });

  test('a denied write raises rather than silently doing nothing', () async {
    await signIn('sara@inmore.local');

    final requests = RequestRepository(db);
    final tasks = TaskRepository(db);
    final board = await requests.board(openOnly: false);
    final target = board.first;

    // Path 1 — a TRIGGER guard. The designer can see and update the row, so
    // the statement reaches the guard, which raises with a message written
    // for a human.
    await expectLater(
      requests.updateDetails(target.id, title: 'hijacked'),
      throwsA(
        isA<PostgrestException>().having(
          (e) => e.message,
          'message',
          contains('status and waiting state'),
        ),
      ),
    );

    // Path 2 — an RLS POLICY, which filters silently. Someone else's task is
    // simply not in the designer's update scope: zero rows, no error from
    // Postgres. The repository is what turns that into a failure, and this
    // assertion is the one that stops a future refactor quietly reintroducing
    // a fake "Saved".
    final others = await tasks.forRequest(target.id);
    final notMine = others
        .where((t) => t.assigneeId != '44444444-4444-4444-4444-444444444444')
        .toList();
    if (notMine.isNotEmpty) {
      await expectLater(
        tasks.setStatus(notMine.first.id, TaskStatus.done),
        throwsA(isA<PermissionDeniedException>()),
      );
    }

    // Money is refused outright.
    await expectLater(
      PaymentRepository(db).record(
        requestId: target.id,
        amount: 1,
        method: PaymentMethod.cash,
        kind: PaymentKind.partial,
      ),
      throwsA(anything),
    );
  });
}
