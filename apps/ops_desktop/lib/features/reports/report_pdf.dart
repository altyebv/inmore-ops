import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:inmore_core/inmore_core.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// What goes around the table on paper.
class ReportMeta {
  const ReportMeta({
    required this.title,
    required this.period,
    required this.preparedBy,
    required this.generatedOn,
    required this.business,
    required this.labels,
    this.note,
  });

  final String title;
  final String period;
  final String preparedBy;
  final String generatedOn;
  final BusinessProfile business;
  final PdfLabels labels;
  final String? note;
}

/// The words the printout needs, in the reader's language.
class PdfLabels {
  const PdfLabels({
    required this.period,
    required this.preparedBy,
    required this.generated,
    required this.total,
    required this.subtotal,
    required this.rows,
    required this.page,
    required this.crNumber,
  });

  final String period;
  final String preparedBy;
  final String generated;
  final String total;
  final String subtotal;
  final String Function(int) rows;
  final String Function(int page, int pages) page;
  final String crNumber;
}

/// A shaped report as an A4 PDF: Inmore's letterhead, what the report
/// covers, then the table exactly as it is on screen — the same columns and
/// order, groups with subtotals, hidden rows left out — and the totals.
///
/// Landscape when the columns won't fit upright. Set in Rubik, which carries
/// Arabic and Latin in one family; each cell takes its direction from its
/// own text, so an Arabic customer name in an English report is still joined
/// up and reads right to left.
Future<Uint8List> buildReportPdf({
  required ShapedReport report,
  required String Function(ReportColumn) label,
  required String Function(ReportColumn, Object?) display,
  required ReportMeta meta,
  required bool rtl,
}) async {
  final regular = pw.Font.ttf(await rootBundle
      .load('packages/inmore_ui/assets/fonts/Rubik-Regular.ttf'));
  final medium = pw.Font.ttf(await rootBundle
      .load('packages/inmore_ui/assets/fonts/Rubik-Medium.ttf'));
  final bold = pw.Font.ttf(await rootBundle
      .load('packages/inmore_ui/assets/fonts/Rubik-SemiBold.ttf'));
  // Rubik has the Arabic letters but not the joined forms this library
  // shapes them into (it does no OpenType shaping of its own), and its
  // fallback is decided before shaping — so a fallback font never kicks in.
  // Text with any Arabic in it is set in Windows' Segoe UI instead, which has
  // the joined forms; everything else stays in Rubik.
  final arabic = await _windowsFont('segoeui.ttf');
  final arabicBold = await _windowsFont('segoeuib.ttf') ?? arabic;
  pw.Font fontFor(String s, pw.Font latin) {
    if (arabic == null || !_arabic.hasMatch(s)) return latin;
    return latin == regular ? arabic : arabicBold!;
  }

  final logo = pw.MemoryImage(
      (await rootBundle.load('packages/inmore_ui/assets/brand/logo_ink.png'))
          .buffer
          .asUint8List());

  final base = rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;
  final cols = report.columns;
  final flexTotal = cols.fold<int>(0, (s, c) => s + c.flex);
  final landscape = cols.length > 6 || flexTotal > 14;
  final format = landscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4;

  const ink = PdfColor.fromInt(0xFF1D1D1B);
  const muted = PdfColor.fromInt(0xFF5F6368);
  const rule = PdfColor.fromInt(0xFFDADCE0);
  const band = PdfColor.fromInt(0xFFF1F3F4);
  const tint = PdfColor.fromInt(0xFFE8F4FB);

  pw.TextDirection dirOf(String s) =>
      _arabic.hasMatch(s) ? pw.TextDirection.rtl : base;

  pw.Widget text(
    String s, {
    double size = 8.5,
    pw.Font? font,
    PdfColor color = ink,
    pw.TextAlign? align,
    int? maxLines,
  }) =>
      pw.Text(
        s,
        textDirection: dirOf(s),
        textAlign: align,
        maxLines: maxLines,
        style: pw.TextStyle(
          font: fontFor(s, font ?? regular),
          fontSize: size,
          color: color,
        ),
      );

  // Text that mixes Arabic and Latin is laid out as separate pieces in a row,
  // each shaped on its own: this library's bidi reordering scrambles a mixed
  // line (a label, a Latin name, a date) when it is one string.
  pw.Widget pieces(List<String> parts,
          {double size = 8.5, PdfColor color = muted, String sep = ' · '}) =>
      pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          for (var i = 0; i < parts.length; i++) ...[
            if (i > 0) text(sep, size: size, color: color),
            text(parts[i], size: size, color: color),
          ],
        ],
      );

  // A space on its own has no width here, so the gap is a box.
  pw.Widget labelled(String label, String value, {double size = 8.5}) => pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          text('$label:', size: size, color: muted),
          pw.SizedBox(width: 4),
          text(value, size: size, color: muted),
        ],
      );

  // In a right-to-left page, "end" is the left: numbers line up there.
  pw.TextAlign alignFor(ReportColumn c) => c.isNumeric
      ? (rtl ? pw.TextAlign.left : pw.TextAlign.right)
      : (rtl ? pw.TextAlign.right : pw.TextAlign.left);

  pw.Widget row(
    List<String> cells, {
    pw.Font? font,
    PdfColor? fill,
    PdfColor color = ink,
    bool topRule = false,
  }) =>
      pw.Container(
        decoration: pw.BoxDecoration(
          color: fill,
          border: pw.Border(
            bottom: const pw.BorderSide(color: rule, width: 0.5),
            top: topRule
                ? const pw.BorderSide(color: ink, width: 0.8)
                : pw.BorderSide.none,
          ),
        ),
        padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < cols.length; i++)
              pw.Expanded(
                flex: cols[i].flex,
                child: pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 3),
                  child: text(cells[i],
                      font: font,
                      color: color,
                      align: alignFor(cols[i]),
                      maxLines: 3),
                ),
              ),
          ],
        ),
      );

  List<String> sums(Map<String, double> values, String first) => [
        for (var i = 0; i < cols.length; i++)
          cols[i].summable
              ? display(cols[i], values[cols[i].id] ?? 0)
              : (i == 0 ? first : ''),
      ];

  final columnHeader = row([for (final c in cols) label(c)],
      font: bold, fill: band, color: muted);

  pw.Widget stripe() => pw.Row(children: [
        for (final c in const [0xFF009FE3, 0xFFE6007E, 0xFFF6E000, 0xFF1D1D1B])
          pw.Expanded(
              child: pw.Container(height: 3, color: PdfColor.fromInt(c))),
      ]);

  final b = meta.business;
  final letterhead = pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Image(logo, height: 26),
                pw.SizedBox(height: 6),
                text(b.name, size: 11, font: bold),
                if (b.tagline != null) text(b.tagline!, size: 8, color: muted),
                if (b.address != null) text(b.address!, size: 8, color: muted),
                if (b.contactLine.isNotEmpty)
                  text(b.contactLine, size: 8, color: muted),
                if (b.crNumber != null)
                  labelled(meta.labels.crNumber, b.crNumber!, size: 8),
              ],
            ),
          ),
          pw.SizedBox(width: 24),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              text(meta.title, size: 16, font: bold),
              pw.SizedBox(height: 4),
              labelled(meta.labels.period, meta.period),
              pieces([
                '${meta.labels.preparedBy}:',
                ...meta.preparedBy.split(' · ')
              ]),
              labelled(meta.labels.generated, meta.generatedOn),
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 10),
      stripe(),
      if (meta.note != null && meta.note!.trim().isNotEmpty) ...[
        pw.SizedBox(height: 8),
        text(meta.note!.trim(), size: 9),
      ],
      pw.SizedBox(height: 10),
    ],
  );

  final doc = pw.Document(
    title: meta.title,
    author: b.name,
    creator: 'Inmore Operations',
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: format,
      textDirection: base,
      margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 32),
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      header: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          if (ctx.pageNumber == 1)
            letterhead
          else
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pieces([b.name, meta.title]),
            ),
          columnHeader,
        ],
      ),
      footer: (ctx) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 8),
        child: pw.Row(
          children: [
            pw.Expanded(
              child: pw.Align(
                alignment:
                    rtl ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
                child: pieces(
                    [b.name, meta.title, meta.labels.rows(report.rowCount)],
                    size: 7.5),
              ),
            ),
            text(meta.labels.page(ctx.pageNumber, ctx.pagesCount),
                size: 7.5, color: muted),
          ],
        ),
      ),
      build: (ctx) => [
        for (final g in report.groups) ...[
          if (g.label != null)
            pw.Container(
              color: tint,
              padding:
                  const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 5),
              margin: const pw.EdgeInsets.only(top: 6),
              child: text(
                  '${g.label!.isEmpty ? '—' : g.label!}  (${g.rows.length})',
                  font: bold,
                  size: 9),
            ),
          for (var i = 0; i < g.rows.length; i++)
            row([for (final c in cols) display(c, g.rows[i][c.id])],
                fill: i.isOdd ? const PdfColor.fromInt(0xFFFAFAFA) : null),
          if (g.label != null && report.hasTotals)
            row(sums(g.subtotals, meta.labels.subtotal),
                font: medium, color: muted),
        ],
        if (report.hasTotals)
          row(sums(report.totals, meta.labels.total),
              font: bold, topRule: true),
      ],
    ),
  );

  return doc.save();
}

/// A font from the Windows fonts folder, or null anywhere else.
Future<pw.Font?> _windowsFont(String file) async {
  final dir = Platform.environment['WINDIR'];
  if (dir == null) return null;
  final f = File('$dir/Fonts/$file');
  if (!f.existsSync()) return null;
  return pw.Font.ttf(ByteData.sublistView(await f.readAsBytes()));
}

final _arabic = RegExp(r'[؀-ۿݐ-ݿﭐ-﷿ﹰ-﻿]');
