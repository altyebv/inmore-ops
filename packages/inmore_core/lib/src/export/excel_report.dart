import 'package:excel/excel.dart';

import '../models/export_row.dart';

/// Builds the workbook that replaces the supervisor's hand-kept sheet.
///
/// Inmore's current report is customer / item / price, **one row per item**.
/// That shape is kept, because it is also the one Excel can pivot — product
/// demand, revenue per customer, items per supervisor all fall out of it.
///
/// Two sheets, and the split is the important part:
///
/// * **Items** — one row per request item. Line totals sum correctly here.
/// * **Requests** — one row per request. The request-level money lives *only*
///   here. Repeating a request total across its three item rows would mean
///   anyone who selects that column and reads the sum gets triple the real
///   figure: a confident wrong number, which is worse than no number.
class ExcelReport {
  const ExcelReport._();

  /// Returns the `.xlsx` bytes, or null if the workbook could not be encoded.
  static List<int>? build({
    required List<ExportItemRow> items,
    required List<ExportRequestRow> requests,
  }) {
    final book = Excel.createExcel();

    _writeItems(book[_itemsSheet], items);
    _writeRequests(book[_requestsSheet], requests);

    // Excel.createExcel() seeds a default sheet we do not use.
    book.setDefaultSheet(_itemsSheet);
    if (book.sheets.containsKey('Sheet1')) book.delete('Sheet1');

    return book.save();
  }

  static const String _itemsSheet = 'Items';
  static const String _requestsSheet = 'Requests';

  // Money as a real number with two decimals, so the column sums and formats
  // like money rather than arriving as text.
  static CellStyle get _moneyStyle => CellStyle(
      numberFormat: const CustomNumericNumFormat(formatCode: '#,##0.00'));

  static CellStyle get _headerStyle => CellStyle(bold: true);

  static const List<String> _itemHeaders = [
    'Request #',
    'Date',
    'Customer',
    'Company',
    'Phone',
    'Item',
    'Qty',
    'Unit',
    'Spec',
    'Unit Price',
    'Line Total',
    'Item Status',
    'Request Status',
    'Waiting On',
    'Supervisor',
    'Needed By',
    'Completed',
  ];

  static const List<String> _requestHeaders = [
    'Request #',
    'Date',
    'Customer',
    'Supervisor',
    'Status',
    'Waiting On',
    'Items',
    'Approved Total',
    'Paid',
    'Balance',
    'Needed By',
    'Completed',
  ];

  static void _writeItems(Sheet sheet, List<ExportItemRow> rows) {
    _writeHeader(sheet, _itemHeaders);

    for (final r in rows) {
      sheet.appendRow(<CellValue?>[
        IntCellValue(r.requestNumber),
        _date(r.requestDate),
        TextCellValue(r.customer),
        _text(r.company),
        // Phone stays TEXT: as a number Excel eats the leading zero and
        // reformats a Qatari number into something nobody can dial.
        _text(r.phone),
        TextCellValue(r.item),
        DoubleCellValue(r.qty),
        _text(r.unit),
        _text(r.spec),
        _money(r.unitPrice),
        _money(r.lineTotal),
        TextCellValue(r.itemStatus.label),
        TextCellValue(r.requestStatus.label),
        _text(r.waitingOn?.label),
        _text(r.supervisor),
        _date(r.neededBy),
        _date(r.completed),
      ]);
    }

    _styleMoneyColumns(sheet, const [9, 10], rows.length);
    _fit(sheet, _itemHeaders.length);
  }

  static void _writeRequests(Sheet sheet, List<ExportRequestRow> rows) {
    _writeHeader(sheet, _requestHeaders);

    for (final r in rows) {
      sheet.appendRow(<CellValue?>[
        IntCellValue(r.requestNumber),
        _date(r.requestDate),
        TextCellValue(r.customer),
        _text(r.supervisor),
        TextCellValue(r.status.label),
        _text(r.waitingOn?.label),
        IntCellValue(r.items),
        // Nothing agreed yet: leave the cell empty rather than writing 0,
        // which would read as "we quoted nothing" instead of "not quoted".
        r.approvedQuotationCount == 0 ? null : _money(r.approvedTotal),
        _money(r.paid),
        r.approvedQuotationCount == 0 ? null : _money(r.balance),
        _date(r.neededBy),
        _date(r.completed),
      ]);
    }

    _styleMoneyColumns(sheet, const [7, 8, 9], rows.length);
    _fit(sheet, _requestHeaders.length);
  }

  static void _writeHeader(Sheet sheet, List<String> headers) {
    sheet.appendRow(headers.map(TextCellValue.new).toList());
    for (var c = 0; c < headers.length; c++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
          .cellStyle = _headerStyle;
    }
  }

  static void _styleMoneyColumns(Sheet sheet, List<int> columns, int rowCount) {
    for (final c in columns) {
      for (var r = 1; r <= rowCount; r++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r))
            .cellStyle = _moneyStyle;
      }
    }
  }

  static void _fit(Sheet sheet, int columns) {
    for (var c = 0; c < columns; c++) {
      sheet.setColumnAutoFit(c);
    }
  }

  static CellValue? _text(String? v) =>
      (v == null || v.isEmpty) ? null : TextCellValue(v);

  static CellValue? _money(double? v) => v == null ? null : DoubleCellValue(v);

  /// A real Excel date, so it sorts and filters as one.
  static CellValue? _date(DateTime? v) => v == null
      ? null
      : DateCellValue(year: v.year, month: v.month, day: v.day);
}
