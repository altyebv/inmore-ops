import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inmore_core/inmore_core.dart';
import 'package:inmore_ui/inmore_ui.dart';

/// The reports on offer. Each is a read of data the system already holds —
/// nothing here writes anything.
enum ReportKind {
  sales(Icons.shopping_bag_outlined),
  requests(Icons.assignment_outlined),
  payments(Icons.south_west_rounded),
  expenses(Icons.receipt_long_outlined),
  stock(Icons.inventory_2_outlined),
  income(Icons.balance_rounded);

  const ReportKind(this.icon);
  final IconData icon;

  String title(L10n l) => switch (this) {
        sales => l.reportSales,
        requests => l.reportRequests,
        payments => l.reportPayments,
        expenses => l.reportExpenses,
        stock => l.reportStock,
        income => l.reportIncome,
      };

  String hint(L10n l) => switch (this) {
        sales => l.reportSalesHint,
        requests => l.reportRequestsHint,
        payments => l.reportPaymentsHint,
        expenses => l.reportExpensesHint,
        stock => l.reportStockHint,
        income => l.reportIncomeHint,
      };

  bool get hasDates => this != stock;
  bool get hasStage => this == sales || this == requests;
  bool get hasSupervisor =>
      this == sales || this == requests || this == payments;

  /// Products + Requests is the accountant's two-sheet workbook.
  bool get hasWorkbook => this == sales || this == requests;

  List<ReportColumn> get columns => switch (this) {
        sales => const [
            ReportColumn('request', ReportValueType.number),
            ReportColumn('date', ReportValueType.date),
            ReportColumn('customer', ReportValueType.text, flex: 3),
            ReportColumn('company', ReportValueType.text,
                flex: 3, shownByDefault: false),
            ReportColumn('phone', ReportValueType.text, shownByDefault: false),
            ReportColumn('product', ReportValueType.text, flex: 3),
            // Not totalled: pieces and rolls don't add up.
            ReportColumn('qty', ReportValueType.number),
            ReportColumn('unit', ReportValueType.text, flex: 1),
            ReportColumn('spec', ReportValueType.text,
                flex: 3, shownByDefault: false),
            ReportColumn('unitPrice', ReportValueType.money),
            ReportColumn('lineTotal', ReportValueType.money, summable: true),
            ReportColumn('itemStatus', ReportValueType.text),
            ReportColumn('stage', ReportValueType.text),
            ReportColumn('waitingOn', ReportValueType.text,
                shownByDefault: false),
            ReportColumn('supervisor', ReportValueType.text,
                shownByDefault: false),
            ReportColumn('neededBy', ReportValueType.date,
                shownByDefault: false),
            ReportColumn('completed', ReportValueType.date,
                shownByDefault: false),
          ],
        requests => const [
            ReportColumn('request', ReportValueType.number),
            ReportColumn('date', ReportValueType.date),
            ReportColumn('customer', ReportValueType.text, flex: 3),
            ReportColumn('supervisor', ReportValueType.text),
            ReportColumn('stage', ReportValueType.text),
            ReportColumn('waitingOn', ReportValueType.text,
                shownByDefault: false),
            ReportColumn('items', ReportValueType.number,
                flex: 1, shownByDefault: false),
            ReportColumn('approved', ReportValueType.money, summable: true),
            ReportColumn('paid', ReportValueType.money, summable: true),
            ReportColumn('balance', ReportValueType.money, summable: true),
            ReportColumn('neededBy', ReportValueType.date,
                shownByDefault: false),
            ReportColumn('completed', ReportValueType.date,
                shownByDefault: false),
          ],
        payments => const [
            ReportColumn('date', ReportValueType.date),
            ReportColumn('request', ReportValueType.number),
            ReportColumn('customer', ReportValueType.text, flex: 3),
            ReportColumn('company', ReportValueType.text,
                flex: 3, shownByDefault: false),
            ReportColumn('method', ReportValueType.text),
            ReportColumn('kind', ReportValueType.text),
            ReportColumn('reference', ReportValueType.text,
                shownByDefault: false),
            ReportColumn('supervisor', ReportValueType.text,
                shownByDefault: false),
            ReportColumn('recordedBy', ReportValueType.text,
                shownByDefault: false),
            ReportColumn('amount', ReportValueType.money, summable: true),
          ],
        expenses => const [
            ReportColumn('date', ReportValueType.date),
            ReportColumn('category', ReportValueType.text),
            ReportColumn('description', ReportValueType.text, flex: 3),
            ReportColumn('paidTo', ReportValueType.text),
            ReportColumn('type', ReportValueType.text),
            ReportColumn('method', ReportValueType.text),
            ReportColumn('reference', ReportValueType.text,
                shownByDefault: false),
            ReportColumn('amount', ReportValueType.money, summable: true),
          ],
        stock => const [
            ReportColumn('item', ReportValueType.text, flex: 3),
            ReportColumn('code', ReportValueType.text, flex: 1),
            ReportColumn('category', ReportValueType.text),
            ReportColumn('onHand', ReportValueType.number),
            ReportColumn('unit', ReportValueType.text, flex: 1),
            ReportColumn('reorderAt', ReportValueType.number),
            ReportColumn('status', ReportValueType.text),
            ReportColumn('location', ReportValueType.text,
                shownByDefault: false),
            ReportColumn('unitCost', ReportValueType.money),
            ReportColumn('value', ReportValueType.money, summable: true),
          ],
        income => const [
            ReportColumn('month', ReportValueType.date, flex: 3),
            ReportColumn('moneyIn', ReportValueType.money, summable: true),
            ReportColumn('moneyOut', ReportValueType.money, summable: true),
            ReportColumn('net', ReportValueType.money, summable: true),
          ],
      };

  ReportShape get defaultShape => ReportShape(
        columns: [
          for (final c in columns)
            if (c.shownByDefault) c.id,
        ],
        sortBy: switch (this) {
          stock => 'item',
          income => 'month',
          _ => 'date',
        },
      );
}

String columnLabel(L10n l, String id) => switch (id) {
      'request' => l.colRequestNo,
      'date' => l.colDate,
      'customer' => l.colCustomer,
      'company' => l.colCompany,
      'phone' => l.colPhone,
      'product' => l.colProduct,
      'qty' => l.colQty,
      'unit' => l.colUnit,
      'spec' => l.colSpec,
      'unitPrice' => l.colUnitPrice,
      'lineTotal' => l.colLineTotal,
      'itemStatus' => l.colItemStatus,
      'stage' => l.stage,
      'waitingOn' => l.colWaitingOn,
      'supervisor' => l.supervisor,
      'neededBy' => l.colNeededBy,
      'completed' => l.colCompleted,
      'items' => l.colItems,
      'approved' => l.colApproved,
      'paid' => l.colPaid,
      'balance' => l.colBalance,
      'amount' => l.colAmount,
      'method' => l.colMethod,
      'kind' => l.colKind,
      'reference' => l.colReference,
      'recordedBy' => l.colRecordedBy,
      'category' => l.colCategory,
      'description' => l.colDescription,
      'paidTo' => l.colPaidTo,
      'type' => l.colType,
      'item' => l.colItem,
      'code' => l.colCode,
      'onHand' => l.colOnHand,
      'reorderAt' => l.colReorderAt,
      'status' => l.colStockStatus,
      'location' => l.colLocation,
      'unitCost' => l.colUnitCost,
      'value' => l.colValue,
      'month' => l.colMonth,
      'moneyIn' => l.colMoneyIn,
      'moneyOut' => l.colMoneyOut,
      'net' => l.colNet,
      _ => id,
    };

/// A value as a person reads it, in the current [Fmt] language.
String displayValue(ReportColumn c, Object? v) {
  if (v == null) return '';
  if (c.id == 'request' && v is num) return '#${v.toInt()}';
  if (c.id == 'month' && v is DateTime) return Fmt.month(v);
  return switch (v) {
    num n => c.type == ReportValueType.money ? Fmt.amount(n) : Fmt.qty(n),
    DateTime d =>
      c.type == ReportValueType.dateTime ? Fmt.dateTime(d) : Fmt.date(d),
    _ => v.toString(),
  };
}

/// What narrows a report before it's shaped.
@immutable
class ReportFilter {
  const ReportFilter({
    this.range,
    this.status,
    this.supervisorId,
    this.includeArchived = false,
  });

  final DateTimeRange? range;
  final RequestStatus? status;
  final String? supervisorId;
  final bool includeArchived;

  DateTime? get from => range?.start;

  /// The end of the chosen day, not its midnight, or the last day drops out.
  DateTime? get to => range == null
      ? null
      : DateTime(range!.end.year, range!.end.month, range!.end.day, 23, 59, 59);

  ReportFilter copyWith({
    DateTimeRange? range,
    RequestStatus? status,
    String? supervisorId,
    bool? includeArchived,
    bool clearRange = false,
    bool clearStatus = false,
    bool clearSupervisor = false,
  }) =>
      ReportFilter(
        range: clearRange ? null : (range ?? this.range),
        status: clearStatus ? null : (status ?? this.status),
        supervisorId:
            clearSupervisor ? null : (supervisorId ?? this.supervisorId),
        includeArchived: includeArchived ?? this.includeArchived,
      );

  @override
  bool operator ==(Object other) =>
      other is ReportFilter &&
      other.range == range &&
      other.status == status &&
      other.supervisorId == supervisorId &&
      other.includeArchived == includeArchived;

  @override
  int get hashCode => Object.hash(range, status, supervisorId, includeArchived);
}

/// The data behind one report, fetched once; rows are built from it in
/// whichever language is needed.
class ReportData {
  const ReportData(this.kind, this.raw, {this.costs = const {}, this.extra});

  final ReportKind kind;
  final List<Object> raw;
  final Map<String, double> costs;

  /// Income vs expenses: the expenses beside [raw]'s payments.
  final List<Expense>? extra;

  List<ReportRow> rows(L10n l) => switch (kind) {
        ReportKind.sales => [
            for (final (i, r) in raw.cast<ExportItemRow>().indexed)
              ReportRow('${r.requestNumber}/$i', {
                'request': r.requestNumber,
                'date': r.requestDate,
                'customer': r.customer,
                'company': r.company,
                'phone': r.phone,
                'product': r.item,
                'qty': r.qty,
                'unit': r.unit,
                'spec': r.spec,
                'unitPrice': r.unitPrice,
                'lineTotal': r.lineTotal,
                'itemStatus': r.itemStatus.tr(l),
                'stage': r.requestStatus.tr(l),
                'waitingOn': r.waitingOn?.tr(l),
                'supervisor': r.supervisor,
                'neededBy': r.neededBy,
                'completed': r.completed,
              }),
          ],
        ReportKind.requests => [
            for (final r in raw.cast<ExportRequestRow>())
              ReportRow('${r.requestNumber}', {
                'request': r.requestNumber,
                'date': r.requestDate,
                'customer': r.customer,
                'supervisor': r.supervisor,
                'stage': r.status.tr(l),
                'waitingOn': r.waitingOn?.tr(l),
                'items': r.items,
                'approved': r.approvedTotal,
                'paid': r.paid,
                'balance': r.balance,
                'neededBy': r.neededBy,
                'completed': r.completed,
              }),
          ],
        ReportKind.payments => [
            for (final p in raw.cast<PaymentReportRow>())
              ReportRow(p.id, {
                'date': p.paidAt,
                'request': p.requestNumber,
                'customer': p.customer,
                'company': p.company,
                'method': p.method.tr(l),
                'kind': p.kind.tr(l),
                'reference': p.reference,
                'supervisor': p.supervisor,
                'recordedBy': p.recordedBy,
                'amount': p.amount,
              }),
          ],
        ReportKind.expenses => [
            for (final e in raw.cast<Expense>())
              ReportRow(e.id, {
                'date': e.spentOn,
                'category': e.category,
                'description': e.description,
                'paidTo': e.paidTo,
                'type': e.isMonthly ? l.typeMonthly : l.typeDayToDay,
                'method': e.method.tr(l),
                'reference': e.reference,
                'amount': e.amount,
              }),
          ],
        ReportKind.stock => [
            for (final i in raw.cast<InventoryItem>())
              ReportRow(i.id, {
                'item': i.name,
                'code': i.code,
                'category': i.category,
                'onHand': i.onHand,
                'unit': i.unit,
                'reorderAt': i.reorderLevel > 0 ? i.reorderLevel : null,
                'status': i.isOut
                    ? l.outOfStock
                    : (i.isLow ? l.runningLow : l.stockOk),
                'location': i.location,
                'unitCost': costs[i.id],
                'value': costs[i.id] == null
                    ? null
                    : costs[i.id]! * (i.onHand > 0 ? i.onHand : 0),
              }),
          ],
        ReportKind.income => _incomeRows(),
      };

  /// Money in (payments) and out (expenses), one row per month.
  List<ReportRow> _incomeRows() {
    final months = <DateTime, (double, double)>{};
    for (final p in raw.cast<PaymentReportRow>()) {
      final m = DateTime(p.paidAt.year, p.paidAt.month);
      final (i, o) = months[m] ?? (0.0, 0.0);
      months[m] = (i + p.amount, o);
    }
    for (final e in extra ?? const <Expense>[]) {
      final m = DateTime(e.spentOn.year, e.spentOn.month);
      final (i, o) = months[m] ?? (0.0, 0.0);
      months[m] = (i, o + e.amount);
    }
    return [
      for (final m in months.keys)
        ReportRow(m.toIso8601String(), {
          'month': m,
          'moneyIn': months[m]!.$1,
          'moneyOut': months[m]!.$2,
          'net': months[m]!.$1 - months[m]!.$2,
        }),
    ];
  }
}

final reportDataProvider = FutureProvider.autoDispose
    .family<ReportData, (ReportKind, ReportFilter)>((ref, key) async {
  ref.watch(currentUserIdProvider);
  final (kind, f) = key;
  final export = ref.watch(exportRepositoryProvider);
  final expenses = ref.watch(expenseRepositoryProvider);
  final everything = (DateTime(2000), DateTime(2100));

  switch (kind) {
    case ReportKind.sales:
      return ReportData(
          kind,
          await export.items(
              from: f.from,
              to: f.to,
              supervisorId: f.supervisorId,
              status: f.status));
    case ReportKind.requests:
      return ReportData(
          kind,
          await export.requests(
              from: f.from,
              to: f.to,
              supervisorId: f.supervisorId,
              status: f.status));
    case ReportKind.payments:
      return ReportData(
          kind,
          await export.payments(
              from: f.from, to: f.to, supervisorId: f.supervisorId));
    case ReportKind.expenses:
      return ReportData(
          kind,
          await expenses.between(
              f.from ?? everything.$1, f.to ?? everything.$2));
    case ReportKind.stock:
      final repo = ref.watch(inventoryRepositoryProvider);
      return ReportData(
          kind, await repo.items(includeArchived: f.includeArchived),
          costs: await repo.costs());
    case ReportKind.income:
      return ReportData(
        kind,
        await export.payments(from: f.from, to: f.to),
        extra: await expenses.between(
            f.from ?? everything.$1, f.to ?? everything.$2),
      );
  }
});
