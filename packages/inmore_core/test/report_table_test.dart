import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inmore_core/inmore_core.dart';

void main() {
  const cols = [
    ReportColumn('date', ReportValueType.date),
    ReportColumn('category', ReportValueType.text),
    ReportColumn('amount', ReportValueType.money, summable: true),
  ];
  final rows = [
    ReportRow('a', {'date': DateTime(2026, 10, 3), 'category': 'Rent', 'amount': 12000}),
    ReportRow('b', {'date': DateTime(2026, 10, 1), 'category': 'Fuel', 'amount': 150}),
    ReportRow('c', {'date': DateTime(2026, 10, 2), 'category': 'Fuel', 'amount': 90.5}),
    const ReportRow('d', {'date': null, 'category': 'Ink', 'amount': null}),
  ];
  String display(ReportColumn c, Object? v) =>
      v is DateTime ? '${v.day}/${v.month}' : (v?.toString() ?? '');

  test('sorts with nulls last, either direction', () {
    var r = const ReportShape(columns: ['date', 'category', 'amount'], sortBy: 'date')
        .apply(cols, rows, display: display);
    expect(r.groups.single.rows.map((r) => r.key), ['b', 'c', 'a', 'd']);
    r = const ReportShape(
            columns: ['date', 'category', 'amount'], sortBy: 'amount', ascending: false)
        .apply(cols, rows, display: display);
    expect(r.groups.single.rows.map((r) => r.key), ['a', 'b', 'c', 'd']);
  });

  test('groups with subtotals; totals ignore hidden rows', () {
    final r = const ReportShape(
      columns: ['category', 'amount'],
      groupBy: 'category',
      hiddenRows: {'a'},
    ).apply(cols, rows, display: display);
    expect(r.groups.map((g) => g.label), ['Fuel', 'Ink']);
    expect(r.groups.first.subtotals['amount'], 240.5);
    expect(r.totals['amount'], 240.5);
    expect(r.hiddenCount, 1);
    expect(r.rowCount, 3);
    expect(r.columns.map((c) => c.id), ['category', 'amount']);
  });

  test('search matches what is shown', () {
    final r = const ReportShape(columns: ['category', 'amount'], search: 'fu')
        .apply(cols, rows, display: display);
    expect(r.rowCount, 2);
  });

  test('workbook: rows only on the data sheet, totals on the summary', () {
    final shaped = const ReportShape(columns: ['date', 'category', 'amount'])
        .apply(cols, rows, display: display);
    final bytes = ReportWorkbook.build(
      report: shaped,
      label: (c) => c.id,
      about: const [('Inmore', 'Expenses'), ('Period', 'October 2026')],
    );
    expect(bytes, isNotNull);
    final book = Excel.decodeBytes(bytes!);
    expect(book.tables.keys, containsAll(['Report', 'Summary']));
    expect(book.tables['Report']!.maxRows, 5); // header + 4 rows, no total row
  });
}
