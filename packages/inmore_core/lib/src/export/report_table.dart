import 'package:excel/excel.dart';

/// What a report cell holds, which decides how it is shown, sorted and summed.
enum ReportValueType { text, number, money, date, dateTime }

/// One column a report can show. Labels are not here: the screen and the
/// printout use the reader's language, the Excel file always English, so the
/// caller supplies the label for each.
class ReportColumn {
  const ReportColumn(
    this.id,
    this.type, {
    this.summable = false,
    this.flex = 2,
    this.shownByDefault = true,
  });

  final String id;
  final ReportValueType type;

  /// Totalled in the footer and in each group's subtotal.
  final bool summable;

  /// Relative width on screen and on paper.
  final int flex;
  final bool shownByDefault;

  bool get isNumeric =>
      type == ReportValueType.number || type == ReportValueType.money;
}

/// One row: a stable [key] (so hiding a row survives a refresh or a change of
/// language) and its values by column id — `String`, `num`, `DateTime` or null.
class ReportRow {
  const ReportRow(this.key, this.values);

  final String key;
  final Map<String, Object?> values;

  Object? operator [](String column) => values[column];
}

/// How the person has shaped the report. Shaping never changes a record: it
/// decides which rows and columns are shown, in what order, grouped how.
class ReportShape {
  const ReportShape({
    required this.columns,
    this.sortBy,
    this.ascending = true,
    this.groupBy,
    this.hiddenRows = const {},
    this.search = '',
  });

  /// Visible columns, in order.
  final List<String> columns;
  final String? sortBy;
  final bool ascending;
  final String? groupBy;
  final Set<String> hiddenRows;
  final String search;

  ReportShape copyWith({
    List<String>? columns,
    String? sortBy,
    bool? ascending,
    String? groupBy,
    Set<String>? hiddenRows,
    String? search,
    bool clearSort = false,
    bool clearGroup = false,
  }) =>
      ReportShape(
        columns: columns ?? this.columns,
        sortBy: clearSort ? null : (sortBy ?? this.sortBy),
        ascending: ascending ?? this.ascending,
        groupBy: clearGroup ? null : (groupBy ?? this.groupBy),
        hiddenRows: hiddenRows ?? this.hiddenRows,
        search: search ?? this.search,
      );

  /// Rows after search, hiding and sorting, cut into groups with subtotals.
  ///
  /// [display] turns a value into the text a person reads — used for search
  /// and for group labels, so a stage groups by its translated name.
  ShapedReport apply(
    List<ReportColumn> all,
    List<ReportRow> rows, {
    required String Function(ReportColumn column, Object? value) display,
  }) {
    final byId = {for (final c in all) c.id: c};
    final visible = [
      for (final id in columns)
        if (byId[id] != null) byId[id]!,
    ];
    final q = search.trim().toLowerCase();

    final kept = <ReportRow>[];
    var hidden = 0;
    for (final r in rows) {
      if (hiddenRows.contains(r.key)) {
        hidden++;
        continue;
      }
      if (q.isNotEmpty &&
          !visible.any((c) => display(c, r[c.id]).toLowerCase().contains(q))) {
        continue;
      }
      kept.add(r);
    }

    final sortCol = sortBy == null ? null : byId[sortBy];
    if (sortCol != null) {
      kept.sort((a, b) {
        final x = a[sortCol.id], y = b[sortCol.id];
        // Blanks stay at the bottom whichever way it's sorted.
        if (x == null || y == null) return _compare(x, y);
        final c = _compare(x, y);
        return ascending ? c : -c;
      });
    }

    final groupCol = groupBy == null ? null : byId[groupBy];
    final groups = <ReportGroup>[];
    if (groupCol == null) {
      groups.add(ReportGroup(null, kept, _sums(visible, kept)));
    } else {
      final buckets = <String, List<ReportRow>>{};
      for (final r in kept) {
        final label = display(groupCol, r[groupCol.id]);
        buckets.putIfAbsent(label, () => []).add(r);
      }
      // Groups in the order of the grouping value, not of first appearance.
      final labels = buckets.keys.toList()
        ..sort((a, b) {
          final c = _compare(
              buckets[a]!.first[groupCol.id], buckets[b]!.first[groupCol.id]);
          return c != 0 ? c : a.compareTo(b);
        });
      for (final label in labels) {
        groups.add(ReportGroup(
            label, buckets[label]!, _sums(visible, buckets[label]!)));
      }
    }

    return ShapedReport(
      columns: visible,
      groups: groups,
      totals: _sums(visible, kept),
      rowCount: kept.length,
      hiddenCount: hidden,
    );
  }

  static Map<String, double> _sums(
      List<ReportColumn> cols, List<ReportRow> rows) {
    final out = <String, double>{};
    for (final c in cols.where((c) => c.summable)) {
      var s = 0.0;
      for (final r in rows) {
        final v = r[c.id];
        if (v is num) s += v;
      }
      out[c.id] = s;
    }
    return out;
  }

  /// Nulls last, whatever the direction of the type.
  static int _compare(Object? a, Object? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    if (a is num && b is num) return a.compareTo(b);
    if (a is DateTime && b is DateTime) return a.compareTo(b);
    return a.toString().toLowerCase().compareTo(b.toString().toLowerCase());
  }
}

class ReportGroup {
  const ReportGroup(this.label, this.rows, this.subtotals);

  /// Null when the report isn't grouped.
  final String? label;
  final List<ReportRow> rows;
  final Map<String, double> subtotals;
}

class ShapedReport {
  const ShapedReport({
    required this.columns,
    required this.groups,
    required this.totals,
    required this.rowCount,
    required this.hiddenCount,
  });

  final List<ReportColumn> columns;
  final List<ReportGroup> groups;
  final Map<String, double> totals;
  final int rowCount;
  final int hiddenCount;

  bool get isGrouped => groups.isNotEmpty && groups.first.label != null;
  bool get hasTotals => totals.isNotEmpty;
}

/// A shaped report as an Excel workbook.
///
/// **Report** holds the rows exactly as shown — visible columns, in order,
/// sorted, hidden rows left out — and nothing else: no subtotal or total rows
/// mixed in, so selecting a column and reading its sum gives the real figure,
/// and the sheet pivots. **Summary** carries the letterhead, what the report
/// covers, and the totals and group subtotals.
class ReportWorkbook {
  const ReportWorkbook._();

  static List<int>? build({
    required ShapedReport report,
    required String Function(ReportColumn) label,
    required List<(String, String)> about,
    String? groupLabel,
  }) {
    final book = Excel.createExcel();
    const dataSheet = 'Report';
    const summarySheet = 'Summary';
    final data = book[dataSheet];
    final summary = book[summarySheet];

    final bold = CellStyle(bold: true);
    final money = CellStyle(
        numberFormat: const CustomNumericNumFormat(formatCode: '#,##0.00'));
    final number = CellStyle(
        numberFormat: const CustomNumericNumFormat(formatCode: '#,##0.##'));
    final date = CellStyle(
        numberFormat: const CustomDateTimeNumFormat(formatCode: 'yyyy-mm-dd'));
    final dateTime = CellStyle(
        numberFormat:
            const CustomDateTimeNumFormat(formatCode: 'yyyy-mm-dd hh:mm'));

    CellStyle? styleFor(ReportColumn c) => switch (c.type) {
          ReportValueType.money => money,
          ReportValueType.number => number,
          ReportValueType.date => date,
          ReportValueType.dateTime => dateTime,
          ReportValueType.text => null,
        };

    CellValue? cell(ReportColumn c, Object? v) => switch (v) {
          null => null,
          num n => DoubleCellValue(n.toDouble()),
          DateTime d => c.type == ReportValueType.date
              ? DateCellValue(year: d.year, month: d.month, day: d.day)
              : DateTimeCellValue(
                  year: d.year,
                  month: d.month,
                  day: d.day,
                  hour: d.hour,
                  minute: d.minute),
          _ => TextCellValue(v.toString()),
        };

    final cols = report.columns;
    for (var i = 0; i < cols.length; i++) {
      final h =
          data.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      h.value = TextCellValue(label(cols[i]));
      h.cellStyle = bold;
      data.setColumnWidth(i, cols[i].isNumeric ? 14 : 22);
    }
    var row = 1;
    for (final g in report.groups) {
      for (final r in g.rows) {
        for (var i = 0; i < cols.length; i++) {
          final value = cell(cols[i], r[cols[i].id]);
          if (value == null) continue;
          final c = data
              .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row));
          c.value = value;
          final s = styleFor(cols[i]);
          if (s != null) c.cellStyle = s;
        }
        row++;
      }
    }

    var s = 0;
    void line(String k, CellValue? v, {bool strong = false, CellStyle? style}) {
      final a =
          summary.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: s));
      a.value = TextCellValue(k);
      if (strong) a.cellStyle = bold;
      if (v != null) {
        final b = summary
            .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: s));
        b.value = v;
        if (style != null) b.cellStyle = style;
      }
      s++;
    }

    summary.setColumnWidth(0, 30);
    summary.setColumnWidth(1, 40);
    for (final (k, v) in about) {
      line(k, TextCellValue(v), strong: k == about.first.$1);
    }
    s++;
    line('Rows', DoubleCellValue(report.rowCount.toDouble()));
    final summed = cols.where((c) => c.summable).toList();
    for (final c in summed) {
      line('Total ${label(c)}', DoubleCellValue(report.totals[c.id] ?? 0),
          strong: true,
          style: c.type == ReportValueType.money ? money : number);
    }
    if (report.isGrouped && summed.isNotEmpty) {
      s++;
      line('By ${groupLabel ?? 'group'}', null, strong: true);
      for (final g in report.groups) {
        final parts = [
          for (final c in summed)
            '${label(c)}: ${_fmt(g.subtotals[c.id] ?? 0)}',
        ];
        line('${g.label} (${g.rows.length})', TextCellValue(parts.join('   ')));
      }
    }

    book.setDefaultSheet(dataSheet);
    if (book.sheets.containsKey('Sheet1')) book.delete('Sheet1');
    return book.save();
  }

  static String _fmt(double v) {
    final fixed = v.toStringAsFixed(2);
    final parts = fixed.split('.');
    final whole = parts[0]
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
    return '$whole.${parts[1]}';
  }
}
