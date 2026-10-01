import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inmore_core/inmore_core.dart';

import '../../widgets/common.dart';

// =============================================================================
// Header: stage, blocking reason, supervisor
// =============================================================================

/// Stage and blocking are two separate controls, because they are two separate
/// columns. Marking a job "waiting on payment" must not lose the fact that it
/// is in production.
class RequestHeaderPanel extends ConsumerWidget {
  const RequestHeaderPanel({
    required this.request,
    required this.canManage,
    super.key,
  });

  final RequestSummary request;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final repo = ref.read(requestRepositoryProvider);

    return SectionCard(
      title: 'Status',
      subtitle: request.source.label,
      actions: [
        if (canManage && request.status != RequestStatus.cancelled)
          TextButton.icon(
            onPressed: () => _cancel(context, ref),
            icon: const Icon(Icons.block, size: 16),
            label: const Text('Cancel request'),
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in RequestStatus.pipeline)
                ChoiceChip(
                  label: Text(s.label),
                  selected: request.status == s,
                  onSelected: (_) => runAction(
                    context,
                    () => repo.setStatus(request.id, s),
                    success: 'Moved to ${s.label}',
                  ).then((ok) {
                    if (ok) refreshRequest(ref, request.id);
                  }),
                ),
              if (request.status == RequestStatus.completed)
                const StatusChip('Completed', color: Colors.green),
              if (request.status == RequestStatus.cancelled)
                StatusChip('Cancelled', color: scheme.outline),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text('Blocked on', style: theme.textTheme.labelMedium),
              const SizedBox(width: 12),
              Wrap(
                spacing: 6,
                children: [
                  for (final w in WaitingReason.values)
                    FilterChip(
                      label: Text(w.label),
                      selected: request.waitingOn == w,
                      onSelected: (on) => runAction(
                        context,
                        () => repo.setWaiting(request.id, on ? w : null),
                      ).then((ok) {
                        if (ok) refreshRequest(ref, request.id);
                      }),
                    ),
                ],
              ),
            ],
          ),
          const Divider(height: 28),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Field(
                  label: 'Supervisor',
                  child: canManage
                      ? _SupervisorPicker(request: request)
                      : Text(request.supervisorName ?? 'Nobody yet'),
                ),
              ),
              Expanded(
                child: _Field(
                  label: 'Needed by',
                  child: Text(
                    Fmt.date(request.neededBy),
                    style: TextStyle(
                        color: request.isOverdue ? scheme.error : null),
                  ),
                ),
              ),
              Expanded(
                child: _Field(
                  label: 'Created',
                  child: Text(Fmt.date(request.createdAt)),
                ),
              ),
              Expanded(
                child: _Field(
                  label: 'Customer',
                  child: Text([
                    request.customerName,
                    if (request.customerPhone != null) request.customerPhone!,
                  ].join('\n')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel this request'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Why?',
              hintText: 'Customer went elsewhere',
              helperText:
                  'Required. Months from now this is the only record of why.',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Cancel request'),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty || !context.mounted) return;
    final ok = await runAction(
      context,
      () => ref.read(requestRepositoryProvider).cancel(request.id, reason),
      success: 'Request cancelled',
    );
    if (ok) refreshRequest(ref, request.id);
  }
}

class _SupervisorPicker extends ConsumerWidget {
  const _SupervisorPicker({required this.request});

  final RequestSummary request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staff = ref.watch(activeEmployeesProvider);
    return staff.maybeWhen(
      data: (people) {
        final supervisors = people
            .where((e) => e.role.canManageRequests)
            .toList(growable: false);
        return DropdownButton<String?>(
          value: request.supervisorId,
          isDense: true,
          underline: const SizedBox.shrink(),
          hint: const Text('Nobody yet'),
          items: [
            const DropdownMenuItem(value: null, child: Text('Nobody yet')),
            ...supervisors.map(
              (e) => DropdownMenuItem(value: e.id, child: Text(e.fullName)),
            ),
          ],
          onChanged: (id) => runAction(
            context,
            () => ref
                .read(requestRepositoryProvider)
                .setSupervisor(request.id, id),
            success: 'Supervisor updated',
          ).then((ok) {
            if (ok) refreshRequest(ref, request.id);
          }),
        );
      },
      orElse: () => Text(request.supervisorName ?? 'Nobody yet'),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

// =============================================================================
// Money summary
// =============================================================================

class MoneyPanel extends ConsumerWidget {
  const MoneyPanel({required this.requestId, super.key});

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fin = ref.watch(requestFinancialsProvider(requestId));

    return SectionCard(
      title: 'Money',
      child: AsyncView(
        value: fin,
        builder: (f) {
          if (f == null) return const EmptyNote('Not available.');

          // Nothing agreed yet: the balance is just the negative of what was
          // paid, which would read as nonsense. Say what is actually true.
          if (!f.hasApprovedQuotation) {
            return Row(
              children: [
                _Figure(label: 'Paid', value: Fmt.money(f.paidTotal)),
                const SizedBox(width: 32),
                Expanded(
                  child: Text(
                    f.paidTotal > 0
                        ? 'Paid in advance — nothing has been approved yet, so '
                            'there is no balance to show.'
                        : 'No approved quotation yet.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            );
          }

          return Row(
            children: [
              _Figure(label: 'Approved', value: Fmt.money(f.approvedTotal)),
              const SizedBox(width: 32),
              _Figure(label: 'Paid', value: Fmt.money(f.paidTotal)),
              const SizedBox(width: 32),
              _Figure(
                label: 'Balance',
                value: Fmt.money(f.balance),
                emphasis: f.balance > 0,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    this.emphasis = false,
  });

  final String label;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: emphasis ? theme.colorScheme.error : null,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Items
// =============================================================================

class ItemsPanel extends ConsumerWidget {
  const ItemsPanel({required this.request, required this.canManage, super.key});

  final RequestSummary request;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(requestItemsProvider(request.id));
    final theme = Theme.of(context);

    return SectionCard(
      title: 'Products',
      child: AsyncView(
        value: items,
        builder: (list) {
          if (list.isEmpty) return const EmptyNote('Nothing listed yet.');
          return Column(
            children: [
              for (final item in list)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text('${item.position}',
                            style: theme.textTheme.labelSmall),
                      ),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name, style: theme.textTheme.bodyMedium),
                            if (item.specs != null)
                              Text(item.specs!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 120,
                        child: Text(item.quantityLabel,
                            style: theme.textTheme.bodyMedium),
                      ),
                      SizedBox(
                        width: 110,
                        child: StatusChip(item.status.label),
                      ),
                      if (canManage)
                        IconButton(
                          tooltip: 'Remove',
                          icon: const Icon(Icons.delete_outline, size: 16),
                          onPressed: () => runAction(
                            context,
                            () => ref
                                .read(requestRepositoryProvider)
                                .removeItem(item.id),
                            success: 'Item removed',
                          ).then((ok) {
                            if (ok) refreshRequest(ref, request.id);
                          }),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// =============================================================================
// Tasks
// =============================================================================

/// The supervisor owns the request; these are the people doing the work.
/// A partner is just another executor.
class TasksPanel extends ConsumerWidget {
  const TasksPanel({required this.request, required this.canManage, super.key});

  final RequestSummary request;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(requestTasksProvider(request.id));
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SectionCard(
      title: 'Work',
      actions: [
        TextButton.icon(
          onPressed: () => _addTask(context, ref),
          icon: const Icon(Icons.add, size: 16),
          label: Text(canManage ? 'Assign work' : 'Add my task'),
        ),
      ],
      child: AsyncView(
        value: tasks,
        builder: (list) {
          if (list.isEmpty) {
            return const EmptyNote('Nobody is on this yet.');
          }
          return Column(
            children: [
              for (final t in list)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(width: 96, child: StatusChip(t.type.label)),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.title, style: theme.textTheme.bodyMedium),
                            Text(
                              t.isExternal
                                  ? '${t.executorName} (external)'
                                  : t.executorName,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 120,
                        child: StatusChip(t.status.label,
                            color: taskColour(t.status, scheme)),
                      ),
                      SizedBox(
                        width: 100,
                        child: Text(
                          t.duration != null
                              ? Fmt.duration(t.duration)
                              : (t.dueAt != null ? Fmt.date(t.dueAt) : '—'),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addTask(BuildContext context, WidgetRef ref) async {
    final items = ref.read(requestItemsProvider(request.id)).valueOrNull ?? [];
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _TaskDialog(requestId: request.id, items: items),
    );
    if (created ?? false) refreshRequest(ref, request.id);
  }
}

class _TaskDialog extends ConsumerStatefulWidget {
  const _TaskDialog({required this.requestId, required this.items});

  final String requestId;
  final List<RequestItem> items;

  @override
  ConsumerState<_TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends ConsumerState<_TaskDialog> {
  final _title = TextEditingController();
  TaskType _type = TaskType.design;
  String? _assigneeId;
  String? _partnerId;
  String? _itemId;
  bool _external = false;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentEmployeeProvider).valueOrNull;
    final canManage = me?.role.canManageRequests ?? false;
    final staff = ref.watch(activeEmployeesProvider).valueOrNull ?? [];
    final partners = ref.watch(partnersProvider).valueOrNull ?? [];

    return AlertDialog(
      title: Text(canManage ? 'Assign work' : 'Add my task'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _title,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'What needs doing',
                  hintText: 'Cup artwork',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<TaskType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Kind of work'),
                items: TaskType.values
                    .map(
                        (t) => DropdownMenuItem(value: t, child: Text(t.label)))
                    .toList(),
                onChanged: (t) => setState(() => _type = t ?? _type),
              ),
              if (widget.items.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: _itemId,
                  decoration:
                      const InputDecoration(labelText: 'For which product'),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('The whole request')),
                    ...widget.items.map((i) =>
                        DropdownMenuItem(value: i.id, child: Text(i.name))),
                  ],
                  onChanged: (v) => setState(() => _itemId = v),
                ),
              ],
              if (canManage) ...[
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Going to an external partner'),
                  value: _external,
                  onChanged: (v) => setState(() {
                    _external = v;
                    _assigneeId = null;
                    _partnerId = null;
                    if (v) _type = TaskType.external;
                  }),
                ),
                if (_external)
                  DropdownButtonFormField<String>(
                    initialValue: _partnerId,
                    decoration: const InputDecoration(labelText: 'Partner'),
                    items: partners
                        .map((p) =>
                            DropdownMenuItem(value: p.id, child: Text(p.name)))
                        .toList(),
                    onChanged: (v) => setState(() => _partnerId = v),
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue: _assigneeId,
                    decoration: const InputDecoration(labelText: 'Who'),
                    items: staff
                        .map((e) => DropdownMenuItem(
                            value: e.id,
                            child: Text('${e.fullName} · ${e.role.label}')))
                        .toList(),
                    onChanged: (v) => setState(() => _assigneeId = v),
                  ),
              ] else
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'This will be assigned to you.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : () => _save(me),
          child: const Text('Add'),
        ),
      ],
    );
  }

  Future<void> _save(Employee? me) async {
    if (_title.text.trim().isEmpty) return;
    setState(() => _busy = true);
    final canManage = me?.role.canManageRequests ?? false;
    final ok = await runAction(
      context,
      () => ref.read(taskRepositoryProvider).create(
            requestId: widget.requestId,
            type: _type,
            title: _title.text,
            requestItemId: _itemId,
            // A non-supervisor may only create work for themselves, which is
            // also what the database allows.
            assigneeId: canManage ? (_external ? null : _assigneeId) : me?.id,
            partnerId: canManage && _external ? _partnerId : null,
          ),
      success: 'Work added',
    );
    if (mounted) {
      setState(() => _busy = false);
      if (ok) Navigator.pop(context, true);
    }
  }
}
