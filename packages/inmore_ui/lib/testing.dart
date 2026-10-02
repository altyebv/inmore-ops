/// Helpers for the apps' screen tests: realistic sample data, real fonts, and
/// a way to save what was drawn as a PNG.
///
/// Not exported from `inmore_ui.dart` — import `package:inmore_ui/testing.dart`
/// from a test only.
library inmore_ui_testing;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:inmore_core/inmore_core.dart';

/// Loads every font in the app's manifest — Rubik and the Material icons —
/// so screenshots show real text instead of the test font's black boxes.
Future<void> loadAppFonts() async {
  final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json'))
      as List<dynamic>;
  for (final entry in manifest) {
    final family = (entry as Map)['family'] as String;
    final loader = FontLoader(family);
    for (final font in entry['fonts'] as List) {
      loader.addFont(rootBundle.load((font as Map)['asset'] as String));
    }
    await loader.load();
  }
}

/// Writes the boundary's current frame to `build/screenshots/<name>.png`.
Future<void> savePng(
  RenderRepaintBoundary boundary,
  String name, {
  double pixelRatio = 1,
}) async {
  final image = await boundary.toImage(pixelRatio: pixelRatio);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final dir = Directory('build/screenshots')..createSync(recursive: true);
  File('${dir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
}

/// A believable day at Inmore, mixing English and Arabic names the way the
/// real data will.
abstract final class Sample {
  static final now = DateTime.now();
  static DateTime daysAgo(int d) => now.subtract(Duration(days: d));
  static DateTime daysAhead(int d) =>
      DateTime(now.year, now.month, now.day).add(Duration(days: d));

  static const supervisor = Employee(
    id: 'e-ahmed',
    fullName: 'Ahmed Al-Kuwari',
    email: 'ahmed@inmore.local',
    role: EmployeeRole.supervisor,
    isActive: true,
  );

  static const owner = Employee(
    id: 'e-owner',
    fullName: 'Khalid Al-Thani',
    email: 'owner@inmore.local',
    role: EmployeeRole.owner,
    isActive: true,
  );

  static const designer = Employee(
    id: 'e-sara',
    fullName: 'Sara Haddad',
    email: 'sara@inmore.local',
    role: EmployeeRole.designer,
    isActive: true,
  );

  static const staff = [
    owner,
    supervisor,
    designer,
    Employee(
      id: 'e-mona',
      fullName: 'منى العبدالله',
      email: 'mona@inmore.local',
      role: EmployeeRole.supervisor,
      isActive: true,
    ),
  ];

  static RequestSummary _r(
    int n,
    RequestStatus status,
    String customer, {
    String? title,
    WaitingReason? waiting,
    int? dueIn,
    bool supervised = true,
    int created = 3,
    int items = 2,
    String? company,
    String? supervisorName,
    RequestSource source = RequestSource.supervisor,
  }) =>
      RequestSummary(
        id: 'r$n',
        number: n,
        status: status,
        source: source,
        createdAt: daysAgo(created),
        completedAt: status == RequestStatus.completed ? daysAgo(1) : null,
        customerId: 'c$n',
        customerName: customer,
        customerCompany: company,
        customerPhone: '+974 5512 ${3000 + n}',
        title: title,
        waitingOn: waiting,
        neededBy: dueIn == null ? null : daysAhead(dueIn),
        supervisorId: supervised ? supervisor.id : null,
        supervisorName:
            supervised ? (supervisorName ?? supervisor.fullName) : null,
        itemCount: items,
        openTaskCount: 1,
      );

  static final requests = [
    _r(1042, RequestStatus.production, 'Al Bidda Café',
        title: 'Café opening pack',
        company: 'Al Bidda Hospitality W.L.L.',
        waiting: WaitingReason.payment,
        dueIn: 4,
        items: 3),
    _r(1047, RequestStatus.design, 'مقهى الريان',
        title: 'أكواب ورقية مطبوعة',
        dueIn: -2,
        supervisorName: 'منى العبدالله'),
    _r(1051, RequestStatus.isNew, 'Katara Events',
        title: 'Roll-up banners',
        supervised: false,
        created: 0,
        source: RequestSource.website),
    _r(1039, RequestStatus.quotation, 'Doha Dental Clinic',
        title: 'Appointment cards and signage', dueIn: 10),
    _r(1044, RequestStatus.customerApproval, 'Pearl Bakery',
        title: 'Cake boxes, three sizes',
        waiting: WaitingReason.customer,
        dueIn: 6,
        items: 3),
    _r(1036, RequestStatus.delivery, 'شركة الخليج للتجارة',
        title: 'كتيبات الشركة', dueIn: 1, items: 1),
    _r(1040, RequestStatus.production, 'Lusail Fitness',
        title: 'Gym wall graphics', dueIn: 12, items: 4),
    _r(1049, RequestStatus.quotation, 'Souq Waqif Perfumes',
        title: 'Gift bags', dueIn: 15),
  ];

  static final completed = [
    _r(1031, RequestStatus.completed, 'Qatar Foundation',
        title: 'Event lanyards', created: 9),
  ];

  static final items = [
    const RequestItem(
      id: 'i1',
      requestId: 'r1042',
      name: 'Paper cups 8oz, two-colour print',
      quantity: 5000,
      unit: 'pcs',
      specs: 'Kraft, logo front and back',
      status: ItemStatus.approved,
      position: 1,
    ),
    const RequestItem(
      id: 'i2',
      requestId: 'r1042',
      name: 'أكياس ورقية بمقبض',
      quantity: 1000,
      unit: 'pcs',
      specs: 'مقاس متوسط، طباعة لون واحد',
      status: ItemStatus.approved,
      position: 2,
    ),
    const RequestItem(
      id: 'i3',
      requestId: 'r1042',
      name: 'Menu boards',
      quantity: 4,
      unit: 'pcs',
      position: 3,
    ),
  ];

  static final tasks = [
    TaskSummary(
      id: 't1',
      requestId: 'r1042',
      requestNumber: 1042,
      requestStatus: RequestStatus.production,
      customerName: 'Al Bidda Café',
      type: TaskType.design,
      title: 'Cup artwork',
      status: TaskStatus.done,
      assigneeId: designer.id,
      assigneeName: designer.fullName,
      itemName: 'Paper cups 8oz',
      startedAt: daysAgo(3),
      completedAt: daysAgo(1),
    ),
    TaskSummary(
      id: 't2',
      requestId: 'r1042',
      requestNumber: 1042,
      requestStatus: RequestStatus.production,
      customerName: 'Al Bidda Café',
      type: TaskType.external,
      title: 'Print cups',
      status: TaskStatus.inProgress,
      partnerId: 'p1',
      partnerName: 'Gulf Print Co.',
      dueAt: daysAhead(2),
    ),
    TaskSummary(
      id: 't3',
      requestId: 'r1047',
      requestNumber: 1047,
      requestStatus: RequestStatus.design,
      customerName: 'مقهى الريان',
      type: TaskType.design,
      title: 'تصميم الأكواب',
      status: TaskStatus.inProgress,
      assigneeId: designer.id,
      assigneeName: designer.fullName,
      dueAt: daysAgo(1),
      isOverdue: true,
    ),
    TaskSummary(
      id: 't4',
      requestId: 'r1039',
      requestNumber: 1039,
      requestStatus: RequestStatus.quotation,
      customerName: 'Doha Dental Clinic',
      type: TaskType.prepress,
      title: 'Prepare signage files',
      status: TaskStatus.todo,
      assigneeId: designer.id,
      assigneeName: designer.fullName,
      dueAt: daysAhead(3),
    ),
  ];

  static const financials = RequestFinancials(
    requestId: 'r1042',
    approvedTotal: 12400,
    paidTotal: 5000,
    balance: 7400,
    approvedQuotationCount: 1,
  );

  static final quotations = [
    QuotationWithLines(
      Quotation(
        id: 'q2',
        requestId: 'r1042',
        version: 2,
        status: QuotationStatus.approved,
        createdAt: daysAgo(2),
        presentedAt: daysAgo(2),
        subtotal: 12900,
        discount: 500,
        total: 12400,
      ),
      const [
        QuotationLine(
          id: 'l1',
          quotationId: 'q2',
          requestItemId: 'i1',
          quantity: 5000,
          unitPrice: 1.5,
          lineTotal: 7500,
        ),
        QuotationLine(
          id: 'l2',
          quotationId: 'q2',
          requestItemId: 'i2',
          quantity: 1000,
          unitPrice: 5.4,
          lineTotal: 5400,
        ),
      ],
    ),
    QuotationWithLines(
      Quotation(
        id: 'q1',
        requestId: 'r1042',
        version: 1,
        status: QuotationStatus.superseded,
        createdAt: daysAgo(3),
        presentedAt: daysAgo(3),
        subtotal: 14000,
        total: 14000,
      ),
      const [],
    ),
  ];

  static final payments = [
    Payment(
      id: 'p1',
      requestId: 'r1042',
      amount: 5000,
      method: PaymentMethod.bankTransfer,
      kind: PaymentKind.downPayment,
      paidAt: daysAgo(2),
      reference: 'TRX-88213',
    ),
  ];

  static ActivityEntry _a(
    int id,
    String event, {
    String? from,
    String? to,
    Map<String, dynamic> meta = const {},
    int hoursAgo = 1,
    String actor = 'Ahmed Al-Kuwari',
  }) =>
      ActivityEntry(
        id: id,
        occurredAt: now.subtract(Duration(hours: hoursAgo)),
        entityType: event.split('.').first,
        entityId: 'x$id',
        eventType: event,
        actorKind: ActorKind.employee,
        actorName: actor,
        requestId: 'r1042',
        requestNumber: 1042,
        fromValue: from,
        toValue: to,
        metadata: meta,
      );

  static final activity = [
    _a(9, 'request.waiting_set', to: 'PAYMENT', hoursAgo: 2),
    _a(8, 'payment.recorded',
        meta: {'amount': 5000, 'method': 'BANK_TRANSFER'}, hoursAgo: 26),
    _a(7, 'request.status_changed',
        from: 'CUSTOMER_APPROVAL', to: 'PRODUCTION', hoursAgo: 27),
    _a(6, 'quotation.approved', meta: {'amount': 12400}, hoursAgo: 28),
    _a(5, 'task.completed', actor: 'Sara Haddad', hoursAgo: 30),
    _a(4, 'task.created', to: 'Cup artwork', hoursAgo: 70),
    _a(3, 'item.added', to: 'Paper cups 8oz, two-colour print', hoursAgo: 72),
    _a(2, 'request.created', hoursAgo: 72),
  ];

  static const customers = [
    Customer(
      id: 'c1',
      name: 'Al Bidda Café',
      company: 'Al Bidda Hospitality W.L.L.',
      phone: '+974 5512 4042',
      email: 'orders@albidda.qa',
    ),
    Customer(id: 'c2', name: 'مقهى الريان', phone: '+974 3341 2210'),
    Customer(
      id: 'c3',
      name: 'Doha Dental Clinic',
      phone: '+974 4400 1122',
      email: 'admin@dohadental.qa',
    ),
    Customer(
      id: 'c4',
      name: 'شركة الخليج للتجارة',
      company: 'Gulf Trading Co.',
      phone: '+974 5590 7788',
    ),
  ];

  static OwnerSnapshot get snapshot => OwnerSnapshot(
        open: requests,
        completedThisWeek: completed,
        arrivedThisWeek: requests.where((r) => r.number >= 1047).toList(),
      );

  static const money = MoneySnapshot(
    outstanding: 18650,
    approved: 64200,
    received: 45550,
    requestsOwing: 4,
  );

  static List<Workload> get workload => [
        Workload(
          employeeId: designer.id,
          name: designer.fullName,
          tasks: tasks.where((t) => t.assigneeId == designer.id).toList(),
        ),
        Workload(
          employeeId: null,
          name: 'Gulf Print Co.',
          tasks: tasks.where((t) => t.partnerName != null).toList(),
        ),
      ];
}
