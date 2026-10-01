import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inmore_core/inmore_core.dart';
import 'package:path_provider/path_provider.dart';

import '../../widgets/common.dart';

/// Replaces the sheet a supervisor keeps by hand.
///
/// Inmore's current report is customer / item / price, one row per item. That
/// shape is kept — it is also what Excel can pivot — and widened with columns
/// the database already fills by itself. Nothing here asks anyone to type
/// something they do not type today.
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final staff = ref.watch(activeEmployeesProvider).valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              SectionCard(
                title: 'What to include',
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Date range'),
                      subtitle: Text(
                        _range == null
                            ? 'Everything'
                            : '${Fmt.date(_range!.start)} – '
                                '${Fmt.date(_range!.end)}',
                      ),
                      trailing: Wrap(
                        children: [
                          if (_range != null)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => setState(() => _range = null),
                            ),
                          TextButton(
                            onPressed: _pickRange,
                            child: const Text('Choose'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<RequestStatus?>(
                      initialValue: _status,
                      decoration: const InputDecoration(labelText: 'Stage'),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('All stages')),
                        ...RequestStatus.values.map((s) =>
                            DropdownMenuItem(value: s, child: Text(s.label))),
                      ],
                      onChanged: (s) => setState(() => _status = s),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: _supervisorId,
                      decoration:
                          const InputDecoration(labelText: 'Supervisor'),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Everyone')),
                        ...staff.where((e) => e.role.canManageRequests).map(
                            (e) => DropdownMenuItem(
                                value: e.id, child: Text(e.fullName))),
                      ],
                      onChanged: (v) => setState(() => _supervisorId = v),
                    ),
                  ],
                ),
              ),
              SectionCard(
                title: 'What you get',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Bullet(
                      'Items — one row per product, the way the current sheet '
                      'already reads. Line totals sum correctly here.',
                    ),
                    const _Bullet(
                      'Requests — one row per request. The totals live here '
                      'and only here, so summing a column gives the real '
                      'figure instead of counting each job once per product.',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Dates are real Excel dates, money is a number with two '
                      'decimals, and phone numbers stay text so the leading '
                      'zero survives.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _busy ? null : _export,
                icon: _busy
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download, size: 18),
                label: const Text('Create the workbook'),
              ),
              if (_lastPath != null) ...[
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('Saved'),
                    subtitle: SelectableText(_lastPath!),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
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

  Future<void> _export() async {
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
        if (mounted) showError(context, 'Nothing matches those filters.');
        return;
      }

      final bytes = ExcelReport.build(items: items, requests: requests);
      if (bytes == null) {
        if (mounted) showError(context, 'The workbook could not be written.');
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
        setState(() => _lastPath = file.path);
        showDone(
            context, '${items.length} item rows, ${requests.length} requests');
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('·  '),
            Expanded(child: Text(text)),
          ],
        ),
      );
}
