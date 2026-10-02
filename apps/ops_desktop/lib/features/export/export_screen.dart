import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inmore_core/inmore_core.dart';
import 'package:inmore_ui/inmore_ui.dart';
import 'package:path_provider/path_provider.dart';

/// Replaces the sheet a supervisor keeps by hand.
///
/// Inmore's current report is customer / item / price, one row per item. That
/// shape is kept — it is also what Excel can pivot — and widened with columns
/// the database already fills by itself. Nothing here asks anyone to type
/// something they do not type today.
///
/// The workbook is always in English, whatever language the screen is in, so
/// the same file reads the same on every desk and in the accountant's hands.
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  DateTimeRange? _range;
  RequestStatus? _status;
  String? _supervisorId;
  bool _busy = false;
  String? _lastPath;
  String? _lastSummary;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final staff = ref.watch(activeEmployeesProvider).valueOrNull ?? [];

    return Column(
      children: [
        PageHeader(title: l.reportsTitle, subtitle: l.reportsSubtitle),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 32),
            child: Align(
              alignment: AlignmentDirectional.topStart,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionCard(
                      icon: Icons.filter_list_rounded,
                      title: l.whatToInclude,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(Radii.md),
                            onTap: _pickRange,
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: l.dateRange,
                                prefixIcon: const Icon(
                                    Icons.date_range_outlined,
                                    size: 18),
                                suffixIcon: _range == null
                                    ? null
                                    : IconButton(
                                        tooltip: l.clear,
                                        icon: const Icon(Icons.close_rounded,
                                            size: 16),
                                        onPressed: () =>
                                            setState(() => _range = null),
                                      ),
                              ),
                              child: Text(
                                _range == null
                                    ? l.everything
                                    : '${Fmt.date(_range!.start)} – '
                                        '${Fmt.date(_range!.end)}',
                              ),
                            ),
                          ),
                          const SizedBox(height: Space.md),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<RequestStatus?>(
                                  initialValue: _status,
                                  decoration:
                                      InputDecoration(labelText: l.stage),
                                  items: [
                                    DropdownMenuItem(
                                        value: null, child: Text(l.allStages)),
                                    for (final s in RequestStatus.values)
                                      DropdownMenuItem(
                                          value: s, child: Text(s.tr(l))),
                                  ],
                                  onChanged: (s) => setState(() => _status = s),
                                ),
                              ),
                              const SizedBox(width: Space.md),
                              Expanded(
                                child: DropdownButtonFormField<String?>(
                                  initialValue: _supervisorId,
                                  decoration:
                                      InputDecoration(labelText: l.supervisor),
                                  items: [
                                    DropdownMenuItem(
                                        value: null, child: Text(l.everyone)),
                                    for (final e in staff
                                        .where((e) => e.role.canManageRequests))
                                      DropdownMenuItem(
                                          value: e.id,
                                          child: UserText(e.fullName)),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _supervisorId = v),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Space.lg),
                    SectionCard(
                      icon: Icons.table_chart_outlined,
                      title: l.whatYouGet,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Sheet(
                              icon: Icons.list_alt_rounded,
                              text: l.reportItemsSheet),
                          const SizedBox(height: Space.md),
                          _Sheet(
                              icon: Icons.summarize_outlined,
                              text: l.reportRequestsSheet),
                        ],
                      ),
                    ),
                    const SizedBox(height: Space.xl),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _export,
                        icon: _busy
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.download_rounded, size: 18),
                        label: Text(l.createWorkbook),
                      ),
                    ),
                    if (_lastPath != null) ...[
                      const SizedBox(height: Space.lg),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(Space.lg),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: context.tokens.success
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(Radii.md),
                                ),
                                child: Icon(Icons.task_rounded,
                                    color: context.tokens.success),
                              ),
                              const SizedBox(width: Space.lg),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(l.workbookSaved,
                                        style: context.text.titleSmall),
                                    if (_lastSummary != null)
                                      Text(_lastSummary!,
                                          style: context.text.bodySmall),
                                    SelectableText(
                                      _lastPath!,
                                      textDirection: TextDirection.ltr,
                                      style: context.text.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: Space.md),
                              OutlinedButton.icon(
                                onPressed: () => _reveal(_lastPath!),
                                icon: const Icon(Icons.folder_open_outlined,
                                    size: 18),
                                label: Text(l.showInFolder),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _range ??
          DateTimeRange(
            start: DateTime(now.year, now.month, 1),
            end: now,
          ),
    );
    if (picked != null) setState(() => _range = picked);
  }

  /// Opens Explorer with the file selected.
  Future<void> _reveal(String path) async {
    if (Platform.isWindows) {
      await Process.run('explorer.exe', ['/select,', path]);
    }
  }

  Future<void> _export() async {
    final l = context.l10n;
    setState(() => _busy = true);
    try {
      final repo = ref.read(exportRepositoryProvider);
      // The end of the chosen day, not its midnight, or the last day drops out.
      final to = _range == null
          ? null
          : DateTime(
              _range!.end.year, _range!.end.month, _range!.end.day, 23, 59, 59);

      final items = await repo.items(
        from: _range?.start,
        to: to,
        supervisorId: _supervisorId,
        status: _status,
      );
      final requests = await repo.requests(
        from: _range?.start,
        to: to,
        supervisorId: _supervisorId,
        status: _status,
      );

      if (items.isEmpty && requests.isEmpty) {
        if (mounted) showError(context, l.nothingMatchesFilters);
        return;
      }

      final bytes = ExcelReport.build(items: items, requests: requests);
      if (bytes == null) {
        if (mounted) showError(context, l.workbookFailed);
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final folder = Directory('${dir.path}${Platform.pathSeparator}Inmore');
      if (!folder.existsSync()) folder.createSync(recursive: true);

      final stamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final file = File('${folder.path}${Platform.pathSeparator}'
          'inmore-report-$stamp.xlsx');
      await file.writeAsBytes(bytes, flush: true);

      if (mounted) {
        final summary = l.exportSummary(items.length, requests.length);
        setState(() {
          _lastPath = file.path;
          _lastSummary = summary;
        });
        showDone(context, summary);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: context.colors.onSurfaceVariant),
          const SizedBox(width: Space.md),
          Expanded(child: Text(text, style: context.text.bodyMedium)),
        ],
      );
}
