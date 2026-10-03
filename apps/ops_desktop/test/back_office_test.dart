import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inmore_core/inmore_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:inmore_ui/inmore_ui.dart';
import 'package:inmore_ui/testing.dart';
import 'package:ops_desktop/features/reports/report_definitions.dart';
import 'package:ops_desktop/features/reports/report_pdf.dart';

import 'harness.dart';

/// Inventory, expenses, staff and reports: drawn in both languages and
/// themes, with what each role may see.
void main() {
  setUpAll(loadAppFonts);

  final en = lookupL10n(const Locale('en'));

  for (final (path, name) in const [
    ('/inventory', 'inventory'),
    ('/expenses', 'expenses'),
    ('/staff', 'staff'),
    ('/reports', 'reports'),
  ]) {
    for (final (locale, mode) in const [
      (Locale('en'), ThemeMode.light),
      (Locale('ar'), ThemeMode.dark),
    ]) {
      final shot =
          'desktop_${name}_${locale.languageCode}_${mode == ThemeMode.light ? 'light' : 'dark'}';
      testWidgets(shot, (tester) async {
        final key = GlobalKey();
        await pumpDesktop(tester,
            location: path, boundaryKey: key, locale: locale, mode: mode);
        await capture(tester, key, shot);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('inventory: designers see stock but no money and no actions',
      (tester) async {
    await pumpDesktop(tester,
        location: '/inventory',
        boundaryKey: GlobalKey(),
        employee: Sample.designer);
    expect(find.text('Kraft paper roll 80gsm'), findsOneWidget);
    expect(find.text(en.stockValue), findsNothing);
    expect(find.text(en.colUnitCost), findsNothing);
    expect(find.byTooltip(en.receiveStock), findsNothing);
    expect(find.text(en.addStockItem), findsNothing);
  });

  testWidgets('inventory: low and out of stock are flagged', (tester) async {
    await pumpDesktop(tester, location: '/inventory', boundaryKey: GlobalKey());
    expect(find.text(en.lowBadge), findsOneWidget);
    expect(find.text(en.outBadge), findsOneWidget);
  });

  testWidgets('expenses: totals leave voided expenses out', (tester) async {
    await pumpDesktop(tester, location: '/expenses', boundaryKey: GlobalKey());
    // 12,000 + 28,500 + 1,840 + 150 + 1,320 — not the voided 90.
    expect(find.text(Fmt.moneyShort(43810)), findsOneWidget);
    expect(find.text(Fmt.moneyShort(41820)), findsOneWidget); // monthly fixed
    expect(find.text('Entered twice'), findsNothing);
  });

  testWidgets('staff: the owner account is locked for a supervisor',
      (tester) async {
    await pumpDesktop(tester, location: '/staff', boundaryKey: GlobalKey());
    expect(find.byTooltip(en.ownerAccountLocked), findsOneWidget);
    expect(find.text(en.noAccess), findsOneWidget);
    expect(find.text(en.you), findsOneWidget);
  });

  testWidgets('reports: switch report, group with subtotals', (tester) async {
    final key = GlobalKey();
    await pumpDesktop(tester, location: '/reports', boundaryKey: key);
    await tester.tap(find.widgetWithText(ChoiceChip, en.reportExpenses));
    await settle(tester);
    expect(find.text('Kraft paper, 10 rolls'), findsOneWidget);
    // 12,000 + 28,500 + 1,840 + 150 + 1,320
    expect(find.text(Fmt.amount(43810)), findsOneWidget);

    await tester.tap(find.text(en.noGrouping));
    await settle(tester);
    await tester.tap(find.text(en.colCategory).last);
    await settle(tester);
    expect(find.text(en.subtotal), findsWidgets);
    await capture(tester, key, 'desktop_reports_grouped_en_light');
  });

  group('pdf', () {
    setUpAll(() async {
      await initializeDateFormatting('en');
      await initializeDateFormatting('ar');
    });

    Future<void> write(String name, Locale locale, ReportKind kind,
        {String? groupBy}) async {
      final l = lookupL10n(locale);
      final previous = Fmt.locale;
      Fmt.locale = locale.languageCode;
      final report = kind.defaultShape.copyWith(groupBy: groupBy).apply(
          kind.columns, sampleReport(kind).rows(l),
          display: displayValue);
      final bytes = await buildReportPdf(
        report: report,
        label: (c) => columnLabel(l, c.id),
        display: displayValue,
        rtl: locale.languageCode == 'ar',
        meta: ReportMeta(
          title: kind.title(l),
          note: locale.languageCode == 'ar'
              ? 'للمراجعة مع المحاسب.'
              : 'For review with the accountant.',
          period:
              '${Fmt.date(DateTime(2026, 10, 1))} – ${Fmt.date(DateTime(2026, 10, 3))}',
          preparedBy: 'Ahmed Al-Kuwari · ${EmployeeRole.supervisor.tr(l)}',
          generatedOn: Fmt.dateTime(DateTime(2026, 10, 3, 14, 30)),
          business: Sample.business,
          labels: PdfLabels(
            period: l.period,
            preparedBy: l.preparedBy,
            generated: l.generatedOn,
            total: l.total,
            subtotal: l.subtotal,
            rows: l.rowsCount,
            page: (p, n) => l.pageOf(p, n),
            crNumber: l.fieldCrNumber,
          ),
        ),
      );
      Fmt.locale = previous;
      final dir = Directory('build/screenshots')..createSync(recursive: true);
      File('${dir.path}/$name.pdf').writeAsBytesSync(bytes);
      expect(bytes.length, greaterThan(10000));
    }

    test('sales, English',
        () => write('report_sales_en', const Locale('en'), ReportKind.sales));
    test(
        'expenses by category, Arabic',
        () => write(
            'report_expenses_ar', const Locale('ar'), ReportKind.expenses,
            groupBy: 'category'));
    test('stock, English',
        () => write('report_stock_en', const Locale('en'), ReportKind.stock));
  });
}
