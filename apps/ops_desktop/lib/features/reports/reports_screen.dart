import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inmore_core/inmore_core.dart';
import 'package:inmore_ui/inmore_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

import 'report_definitions.dart';
import 'report_pdf.dart';

/// Reports: look at the numbers, shape them, then print or export.
///
/// Shaping — which columns, in what order, sorted, grouped with subtotals,
/// rows searched or left out, a title and a note — changes only what is shown
/// and printed. Records are corrected where they live (a request, an
/// expense), so the history stays true.
///
/// The printout carries the business's letterhead and who prepared it. The
/// "as shown" Excel file holds the rows only (so its columns sum truly) with
/// totals on a Summary sheet; the accountant's two-sheet workbook is still
/// here for sales and requests. Owner and supervisors only: it's money.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  ReportKind _kind = ReportKind.sales;
  final Map<ReportKind, ReportShape> _shapes = {};
  final Map<ReportKind, ReportFilter> _filters = {};
  final Map<ReportKind, TextEditingController> _titles = {};
  final Map<ReportKind, TextEditingController> _notes = {};
  final _search = TextEditingController();
  bool _busy = false;

  ReportShape get _shape => _shapes[_kind] ??= _kind.defaultShape;
  set _shape(ReportShape s) => _shapes[_kind] = s;

  ReportFilter get _filter => _filters[_kind] ??= _defaultFilter(_kind);

  TextEditingController get _title =>
      _titles[_kind] ??= TextEditingController(text: _kind.title(context.l10n));
  TextEditingController get _note => _notes[_kind] ??= TextEditingController();

  static ReportFilter _defaultFilter(ReportKind k) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (k) {
      ReportKind.stock => const ReportFilter(),
      ReportKind.income => ReportFilter(
          range: DateTimeRange(start: DateTime(now.year), end: today)),
      _ => ReportFilter(
          range:
              DateTimeRange(start: DateTime(now.year, now.month), end: today)),
    };
  }

  @override
  void dispose() {
    for (final c in [..._titles.values, ..._notes.values, _search]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final data = ref.watch(reportDataProvider((_kind, _filter)));
    final shaped = data.whenData((d) => _shape
        .copyWith(search: _search.text)
        .apply(_kind.columns, d.rows(l), display: displayValue));

    return Column(
      children: [
        PageHeader(
          title: l.reportsTitle,
          subtitle: l.reportsSubtitleNew,
          actions: [
            TextButton.icon(
              onPressed: () => showDialog<void>(
                  context: context, builder: (_) => const _BusinessDialog()),
              icon: const Icon(Icons.storefront_outlined, size: 18),
              label: Text(l.businessDetails),
            ),
            const SizedBox(width: Space.sm),
            OutlinedButton.icon(
              onPressed: _busy || shaped.valueOrNull == null
                  ? null
                  : () => _pdf(shaped.value!, print: true),
              icon: const Icon(Icons.print_outlined, size: 18),
              label: Text(l.printReport),
            ),
            const SizedBox(width: Space.sm),
            OutlinedButton.icon(
              onPressed: _busy || shaped.valueOrNull == null
                  ? null
                  : () => _pdf(shaped.value!, print: false),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: Text(l.savePdf),
            ),
            const SizedBox(width: Space.sm),
            MenuAnchor(
              menuChildren: [
                MenuItemButton(
                  leadingIcon: const Icon(Icons.table_view_outlined, size: 18),
                  onPressed: data.valueOrNull == null
                      ? null
                      : () => _excelShown(data.value!),
                  child: Text(l.excelThisReport),
                ),
                if (_kind.hasWorkbook)
                  MenuItemButton(
                    leadingIcon:
                        const Icon(Icons.library_books_outlined, size: 18),
                    onPressed: _excelWorkbook,
                    child: Text(l.excelWorkbook),
                  ),
              ],
              builder: (context, controller, _) => FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () => controller.isOpen
                        ? controller.close()
                        : controller.open(),
                icon: const Icon(Icons.grid_on_rounded, size: 18),
                label: Text(l.exportExcel),
              ),
            ),
          ],
          bottom: Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final k in ReportKind.values)
                Tooltip(
                  message: k.hint(l),
                  child: ChoiceChip(
                    showCheckmark: false,
                    avatar: Icon(k.icon, size: 16),
                    label: Text(k.title(l)),
                    selected: k == _kind,
                    onSelected: (_) => setState(() {
                      _kind = k;
                      _search.clear();
                    }),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _toolbar(context, shaped.valueOrNull),
                const SizedBox(height: Space.md),
                Expanded(
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _heading(context),
                        const Divider(),
                        Expanded(
                          child: AsyncView(
                            value: shaped,
                            onRetry: () => ref.invalidate(reportDataProvider),
                            builder: (r) => r.rowCount == 0
                                ? EmptyState(
                                    icon: _kind.icon,
                                    title: l.noRowsReport,
                                    body: l.noRowsReportHint,
                                    compact: true,
                                  )
                                : _ReportTable(
                                    report: r,
                                    shape: _shape,
                                    onSort: _sort,
                                    onHide: (key) => setState(() => _shape =
                                            _shape.copyWith(hiddenRows: {
                                          ..._shape.hiddenRows,
                                          key
                                        })),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _toolbar(BuildContext context, ShapedReport? shaped) {
    final l = context.l10n;
    final f = _filter;
    final staff = ref.watch(activeEmployeesProvider).valueOrNull ?? const [];
    final groupable = _kind.columns
        .where((c) => c.type == ReportValueType.text || c.id == 'date')
        .toList();

    void setFilter(ReportFilter nf) => setState(() => _filters[_kind] = nf);

    return Wrap(
      spacing: Space.md,
      runSpacing: Space.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (_kind.hasDates)
          SizedBox(
            width: 290,
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.md),
              onTap: _pickRange,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l.dateRange,
                  prefixIcon: const Icon(Icons.date_range_outlined, size: 18),
                  suffixIcon: f.range == null
                      ? null
                      : IconButton(
                          tooltip: l.clear,
                          icon: const Icon(Icons.close_rounded, size: 16),
                          onPressed: () =>
                              setFilter(f.copyWith(clearRange: true)),
                        ),
                ),
                child: Text(_period(context), overflow: TextOverflow.ellipsis),
              ),
            ),
          ),
        if (_kind.hasStage)
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<RequestStatus?>(
              isExpanded: true,
              key: ValueKey('stage$_kind'),
              initialValue: f.status,
              decoration: InputDecoration(labelText: l.stage),
              items: [
                DropdownMenuItem(value: null, child: Text(l.allStages)),
                for (final s in RequestStatus.values)
                  DropdownMenuItem(value: s, child: Text(s.tr(l))),
              ],
              onChanged: (s) => setFilter(s == null
                  ? f.copyWith(clearStatus: true)
                  : f.copyWith(status: s)),
            ),
          ),
        if (_kind.hasSupervisor)
          SizedBox(
            width: 190,
            child: DropdownButtonFormField<String?>(
              isExpanded: true,
              key: ValueKey('sup$_kind'),
              initialValue: f.supervisorId,
              decoration: InputDecoration(labelText: l.supervisor),
              items: [
                DropdownMenuItem(value: null, child: Text(l.everyone)),
                for (final e in staff.where((e) => e.role.canManageRequests))
                  DropdownMenuItem(value: e.id, child: UserText(e.fullName)),
              ],
              onChanged: (v) => setFilter(v == null
                  ? f.copyWith(clearSupervisor: true)
                  : f.copyWith(supervisorId: v)),
            ),
          ),
        if (_kind == ReportKind.stock)
          FilterChip(
            label: Text(l.includeArchived),
            selected: f.includeArchived,
            onSelected: (v) => setFilter(f.copyWith(includeArchived: v)),
          ),
        SizedBox(
          width: 220,
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              hintText: l.searchHint,
            ),
          ),
        ),
        if (groupable.isNotEmpty)
          SizedBox(
            width: 190,
            child: DropdownButtonFormField<String?>(
              isExpanded: true,
              key: ValueKey('group$_kind'),
              initialValue: _shape.groupBy,
              decoration: InputDecoration(labelText: l.groupBy),
              items: [
                DropdownMenuItem(value: null, child: Text(l.noGrouping)),
                for (final c in groupable)
                  DropdownMenuItem(
                      value: c.id, child: Text(columnLabel(l, c.id))),
              ],
              onChanged: (v) => setState(() => _shape = v == null
                  ? _shape.copyWith(clearGroup: true)
                  : _shape.copyWith(groupBy: v)),
            ),
          ),
        OutlinedButton.icon(
          onPressed: _pickColumns,
          icon: const Icon(Icons.view_column_outlined, size: 18),
          label: Text(l.columnsButton),
        ),
        if (shaped != null && shaped.hiddenCount > 0)
          InputChip(
            avatar: const Icon(Icons.visibility_off_outlined, size: 16),
            label:
                Text('${l.hiddenRows(shaped.hiddenCount)} · ${l.showAllRows}'),
            onPressed: () =>
                setState(() => _shape = _shape.copyWith(hiddenRows: const {})),
          ),
      ],
    );
  }

  /// The editable title and note, and what the report covers — what will sit
  /// at the top of the printout.
  Widget _heading(BuildContext context) {
    final l = context.l10n;
    final me = ref.watch(currentEmployeeProvider).valueOrNull;
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _title,
                  style: context.text.titleLarge,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    filled: false,
                    hintText: l.reportTitleField,
                    suffixIcon: const Icon(Icons.edit_outlined, size: 16),
                  ),
                ),
                TextField(
                  controller: _note,
                  style: context.text.bodyMedium,
                  maxLines: null,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    filled: false,
                    hintText: '${l.reportNote}: ${l.reportNoteHint}',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Space.lg),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${l.period}: ${_period(context)}',
                  style: context.text.bodySmall),
              if (me != null)
                Text('${l.preparedBy}: ${me.fullName} · ${me.role.tr(l)}',
                    style: context.text.bodySmall),
            ],
          ),
        ],
      ),
    );
  }

  String _period(BuildContext context) {
    final r = _filter.range;
    if (!_kind.hasDates) return Fmt.date(DateTime.now());
    if (r == null) return context.l10n.allTime;
    return '${Fmt.date(r.start)} – ${Fmt.date(r.end)}';
  }

  void _sort(String column) => setState(() {
        _shape = _shape.sortBy == column
            ? _shape.copyWith(ascending: !_shape.ascending)
            : _shape.copyWith(sortBy: column, ascending: true);
      });

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _filter.range ??
          DateTimeRange(start: DateTime(now.year, now.month), end: now),
    );
    if (picked != null) {
      setState(() => _filters[_kind] = _filter.copyWith(range: picked));
    }
  }

  Future<void> _pickColumns() async {
    final picked = await showDialog<List<String>>(
      context: context,
      builder: (_) => _ColumnsDialog(
        all: _kind.columns,
        shown: _shape.columns,
        defaults: _kind.defaultShape.columns,
      ),
    );
    if (picked != null && picked.isNotEmpty) {
      setState(() => _shape = _shape.copyWith(columns: picked));
    }
  }

  // ---------------------------------------------------------------------------
  // Output
  // ---------------------------------------------------------------------------

  Future<void> _pdf(ShapedReport report, {required bool print}) async {
    final l = context.l10n;
    final me = ref.read(currentEmployeeProvider).valueOrNull;
    setState(() => _busy = true);
    try {
      final business = await ref.read(businessProfileProvider.future);
      final title =
          _title.text.trim().isEmpty ? _kind.title(l) : _title.text.trim();
      if (!mounted) return;
      final bytes = await buildReportPdf(
        report: report,
        label: (c) => columnLabel(l, c.id),
        display: displayValue,
        rtl: Directionality.of(context) == TextDirection.rtl,
        meta: ReportMeta(
          title: title,
          note: _note.text,
          period: _period(context),
          preparedBy: me == null ? '—' : '${me.fullName} · ${me.role.tr(l)}',
          generatedOn: Fmt.dateTime(DateTime.now()),
          business: business,
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
      if (print) {
        await Printing.layoutPdf(onLayout: (_) async => bytes, name: title);
      } else {
        final file = await _save(title, 'pdf', bytes);
        if (mounted) _saved(l.pdfSaved, file);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The report as shown, in English: rows only on one sheet, the letterhead
  /// and totals on another.
  Future<void> _excelShown(ReportData data) async {
    final l = context.l10n;
    final en = lookupL10n(const Locale('en'));
    final me = ref.read(currentEmployeeProvider).valueOrNull;
    final period = _period(context);
    setState(() => _busy = true);
    final previous = Fmt.locale;
    try {
      final business = await ref.read(businessProfileProvider.future);
      Fmt.locale = 'en'; // the workbook is English whatever the screen shows
      final report = _shape
          .copyWith(search: _search.text)
          .apply(_kind.columns, data.rows(en), display: displayValue);
      final title =
          _title.text.trim().isEmpty ? _kind.title(en) : _title.text.trim();
      final bytes = ReportWorkbook.build(
        report: report,
        label: (c) => columnLabel(en, c.id),
        groupLabel:
            _shape.groupBy == null ? null : columnLabel(en, _shape.groupBy!),
        about: [
          (business.name, title),
          if (business.tagline != null) ('', business.tagline!),
          (en.period, period),
          if (_note.text.trim().isNotEmpty) (en.reportNote, _note.text.trim()),
          if (me != null) (en.preparedBy, '${me.fullName} (${me.role.tr(en)})'),
          (en.generatedOn, Fmt.dateTime(DateTime.now())),
        ],
      );
      Fmt.locale = previous;
      if (bytes == null) throw StateError(l.workbookFailed);
      final file = await _save(title, 'xlsx', bytes);
      if (mounted) _saved(l.excelSaved, file);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      Fmt.locale = previous;
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The accountant's workbook: every product and every request in range,
  /// unshaped, exactly as before.
  Future<void> _excelWorkbook() async {
    final l = context.l10n;
    final f = _filter;
    setState(() => _busy = true);
    try {
      final repo = ref.read(exportRepositoryProvider);
      final items = await repo.items(
          from: f.from,
          to: f.to,
          supervisorId: f.supervisorId,
          status: f.status);
      final requests = await repo.requests(
          from: f.from,
          to: f.to,
          supervisorId: f.supervisorId,
          status: f.status);
      if (items.isEmpty && requests.isEmpty) {
        if (mounted) showError(context, l.nothingMatchesFilters);
        return;
      }
      final bytes = ExcelReport.build(items: items, requests: requests);
      if (bytes == null) throw StateError(l.workbookFailed);
      final file = await _save('inmore-report', 'xlsx', bytes);
      if (mounted) _saved(l.exportSummary(items.length, requests.length), file);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Documents\Inmore\<title>-<time>.<ext>
  Future<File> _save(String name, String ext, List<int> bytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}${Platform.pathSeparator}Inmore');
    if (!folder.existsSync()) folder.createSync(recursive: true);
    final safe = name
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '-');
    final stamp =
        DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final file = File('${folder.path}${Platform.pathSeparator}'
        '${safe.isEmpty ? 'report' : safe}-$stamp.$ext');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  void _saved(String message, File file) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: context.l10n.showInFolder,
          onPressed: () {
            if (Platform.isWindows) {
              Process.run('explorer.exe', ['/select,', file.path]);
            }
          },
        ),
      ));
  }
}

// =============================================================================
// The table
// =============================================================================

sealed class _Entry {}

class _GroupEntry extends _Entry {
  _GroupEntry(this.group);
  final ReportGroup group;
}

class _RowEntry extends _Entry {
  _RowEntry(this.row, this.odd);
  final ReportRow row;
  final bool odd;
}

class _SubtotalEntry extends _Entry {
  _SubtotalEntry(this.group);
  final ReportGroup group;
}

class _ReportTable extends StatelessWidget {
  const _ReportTable({
    required this.report,
    required this.shape,
    required this.onSort,
    required this.onHide,
  });

  final ShapedReport report;
  final ReportShape shape;
  final ValueChanged<String> onSort;
  final ValueChanged<String> onHide;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cols = report.columns;
    final entries = <_Entry>[
      for (final g in report.groups) ...[
        if (g.label != null) _GroupEntry(g),
        for (var i = 0; i < g.rows.length; i++) _RowEntry(g.rows[i], i.isOdd),
        if (g.label != null && report.hasTotals) _SubtotalEntry(g),
      ],
    ];
    final muted = context.colors.onSurfaceVariant;

    Widget cells(List<Widget> children) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.md),
          child: Row(children: [...children, const SizedBox(width: 36)]),
        );

    Widget cell(ReportColumn c, String text, {TextStyle? style}) => Expanded(
          flex: c.flex,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: UserText(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: (style ?? context.text.bodySmall)?.copyWith(
                fontFeatures:
                    c.isNumeric ? const [FontFeature.tabularFigures()] : null,
              ),
            ).alignedFor(c),
          ),
        );

    List<Widget> sums(Map<String, double> v, String first, TextStyle? s) => [
          for (var i = 0; i < cols.length; i++)
            cell(
                cols[i],
                cols[i].summable
                    ? displayValue(cols[i], v[cols[i].id] ?? 0)
                    : (i == 0 ? first : ''),
                style: s),
        ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: context.colors.surfaceContainerLow,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: cells([
            for (final c in cols)
              Expanded(
                flex: c.flex,
                child: InkWell(
                  onTap: () => onSort(c.id),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisAlignment: c.isNumeric
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      children: [
                        Flexible(
                          child: Text(columnLabel(l, c.id),
                              overflow: TextOverflow.ellipsis,
                              style: context.text.labelSmall?.copyWith(
                                  color: muted, fontWeight: FontWeight.w600)),
                        ),
                        if (shape.sortBy == c.id)
                          Icon(
                              shape.ascending
                                  ? Icons.arrow_upward_rounded
                                  : Icons.arrow_downward_rounded,
                              size: 13,
                              color: muted),
                      ],
                    ),
                  ),
                ),
              ),
          ]),
        ),
        const Divider(),
        Expanded(
          child: ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, i) => switch (entries[i]) {
              _GroupEntry(:final group) => Container(
                  color:
                      context.colors.primaryContainer.withValues(alpha: 0.35),
                  padding: const EdgeInsets.symmetric(
                      horizontal: Space.lg, vertical: 7),
                  child: Text(
                    '${group.label!.isEmpty ? '—' : group.label!}  ·  '
                    '${l.rowsCount(group.rows.length)}',
                    style: context.text.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              _RowEntry(:final row, :final odd) => _HoverRow(
                  odd: odd,
                  hideLabel: l.hideRow,
                  onHide: () => onHide(row.key),
                  child: cells([
                    for (final c in cols)
                      cell(c, displayValue(c, row[c.id]),
                          style: context.text.bodySmall
                              ?.copyWith(color: context.colors.onSurface)),
                  ]),
                ),
              _SubtotalEntry(:final group) => Container(
                  decoration: BoxDecoration(
                      border: Border(
                          bottom: BorderSide(
                              color: context.colors.outlineVariant))),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: cells(sums(
                      group.subtotals,
                      l.subtotal,
                      context.text.bodySmall?.copyWith(
                          color: muted, fontWeight: FontWeight.w600))),
                ),
            },
          ),
        ),
        if (report.hasTotals)
          Container(
            decoration: BoxDecoration(
              color: context.colors.surfaceContainerLow,
              border: Border(top: BorderSide(color: context.colors.outline)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: cells(sums(
                report.totals,
                l.total,
                context.text.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700))),
          ),
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 6),
          child: Text(l.rowsCount(report.rowCount),
              style: context.text.labelSmall?.copyWith(color: muted)),
        ),
      ],
    );
  }
}

extension on Widget {
  Widget alignedFor(ReportColumn c) => Align(
        alignment: c.isNumeric
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: this,
      );
}

/// A row that offers "leave out" while the pointer is over it.
class _HoverRow extends StatefulWidget {
  const _HoverRow({
    required this.child,
    required this.odd,
    required this.hideLabel,
    required this.onHide,
  });

  final Widget child;
  final bool odd;
  final String hideLabel;
  final VoidCallback onHide;

  @override
  State<_HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<_HoverRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Container(
          color: _hover
              ? context.colors.surfaceContainerHigh
              : (widget.odd ? context.colors.surfaceContainerLowest : null),
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Stack(
            alignment: AlignmentDirectional.centerEnd,
            children: [
              widget.child,
              if (_hover)
                PositionedDirectional(
                  end: 8,
                  child: IconButton(
                    tooltip: widget.hideLabel,
                    visualDensity: VisualDensity.compact,
                    iconSize: 16,
                    icon: const Icon(Icons.visibility_off_outlined),
                    onPressed: widget.onHide,
                  ),
                ),
            ],
          ),
        ),
      );
}

// =============================================================================
// Dialogs
// =============================================================================

class _ColumnsDialog extends StatefulWidget {
  const _ColumnsDialog({
    required this.all,
    required this.shown,
    required this.defaults,
  });

  final List<ReportColumn> all;
  final List<String> shown;
  final List<String> defaults;

  @override
  State<_ColumnsDialog> createState() => _ColumnsDialogState();
}

class _ColumnsDialogState extends State<_ColumnsDialog> {
  late List<String> _order;
  late Set<String> _on;

  @override
  void initState() {
    super.initState();
    _reset(widget.shown);
  }

  void _reset(List<String> shown) {
    _order = [
      ...shown,
      for (final c in widget.all)
        if (!shown.contains(c.id)) c.id,
    ];
    _on = {...shown};
  }

  void _move(int i, int by) => setState(() {
        final j = i + by;
        if (j < 0 || j >= _order.length) return;
        final x = _order.removeAt(i);
        _order.insert(j, x);
      });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.columnsTitle),
      content: SizedBox(
        width: 380,
        height: 440,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.columnsHint, style: context.text.bodySmall),
            const SizedBox(height: Space.sm),
            Expanded(
              child: ListView(
                children: [
                  for (var i = 0; i < _order.length; i++)
                    Row(
                      children: [
                        Checkbox(
                          value: _on.contains(_order[i]),
                          onChanged: (v) => setState(() => v == true
                              ? _on.add(_order[i])
                              : _on.remove(_order[i])),
                        ),
                        Expanded(child: Text(columnLabel(l, _order[i]))),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          iconSize: 18,
                          icon: const Icon(Icons.arrow_upward_rounded),
                          onPressed: i == 0 ? null : () => _move(i, -1),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          iconSize: 18,
                          icon: const Icon(Icons.arrow_downward_rounded),
                          onPressed:
                              i == _order.length - 1 ? null : () => _move(i, 1),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() => _reset(widget.defaults)),
          child: Text(l.resetToDefault),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: _on.isEmpty
              ? null
              : () => Navigator.pop(context, [
                    for (final id in _order)
                      if (_on.contains(id)) id
                  ]),
          child: Text(l.save),
        ),
      ],
    );
  }
}

/// The letterhead: name, tagline, contact details, CR number.
class _BusinessDialog extends ConsumerStatefulWidget {
  const _BusinessDialog();

  @override
  ConsumerState<_BusinessDialog> createState() => _BusinessDialogState();
}

class _BusinessDialogState extends ConsumerState<_BusinessDialog> {
  final _formKey = GlobalKey<FormState>();
  final _c = {
    for (final k in [
      'name',
      'tagline',
      'phone',
      'email',
      'address',
      'cr',
      'web'
    ])
      k: TextEditingController(),
  };
  bool _loaded = false;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = ref.watch(businessProfileProvider).valueOrNull;
    if (p != null && !_loaded) {
      _loaded = true;
      _c['name']!.text = p.name;
      _c['tagline']!.text = p.tagline ?? '';
      _c['phone']!.text = p.phone ?? '';
      _c['email']!.text = p.email ?? '';
      _c['address']!.text = p.address ?? '';
      _c['cr']!.text = p.crNumber ?? '';
      _c['web']!.text = p.website ?? '';
    }
    Widget gap() => const SizedBox(height: Space.md);
    return AlertDialog(
      title: Text(l.businessDetails),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.businessDetailsHint, style: context.text.bodySmall),
                gap(),
                AppField(
                  controller: _c['name']!,
                  label: l.fieldBusinessName,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? l.required : null,
                ),
                gap(),
                AppField(controller: _c['tagline']!, label: l.fieldTagline),
                gap(),
                Row(
                  children: [
                    Expanded(
                      child: AppField(
                          controller: _c['phone']!,
                          label: l.fieldPhone,
                          fixedDirection: TextDirection.ltr),
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: AppField(
                          controller: _c['email']!,
                          label: l.fieldEmail,
                          fixedDirection: TextDirection.ltr),
                    ),
                  ],
                ),
                gap(),
                AppField(controller: _c['address']!, label: l.fieldAddress),
                gap(),
                Row(
                  children: [
                    Expanded(
                      child: AppField(
                          controller: _c['cr']!,
                          label: l.fieldCrNumber,
                          fixedDirection: TextDirection.ltr),
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: AppField(
                          controller: _c['web']!,
                          label: l.fieldWebsite,
                          fixedDirection: TextDirection.ltr),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(onPressed: _busy ? null : _save, child: Text(l.save)),
      ],
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    String? v(String k) =>
        _c[k]!.text.trim().isEmpty ? null : _c[k]!.text.trim();
    setState(() => _busy = true);
    final ok = await runAction(
      context,
      () => ref.read(businessProfileRepositoryProvider).save(BusinessProfile(
            name: _c['name']!.text.trim(),
            tagline: v('tagline'),
            phone: v('phone'),
            email: v('email'),
            address: v('address'),
            crNumber: v('cr'),
            website: v('web'),
          )),
      success: context.l10n.businessSaved,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      ref.invalidate(businessProfileProvider);
      Navigator.pop(context);
    }
  }
}
