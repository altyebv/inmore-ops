import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inmore_core/inmore_core.dart';

import '../../widgets/common.dart';

/// The supervisor's landing screen.
///
/// Blocked and overdue requests are pulled to the top: the first question on
/// walking in is "what needs me", not "what exists".
class BoardScreen extends ConsumerWidget {
  const BoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(boardProvider);
    final filter = ref.watch(boardFilterProvider);
    final me = ref.watch(currentEmployeeProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Work board'),
        actions: [
          if (me?.role.canManageRequests ?? false)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                onPressed: () => context.go('/requests/new'),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New request'),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(filter: filter),
          const Divider(height: 1),
          Expanded(
            child: AsyncView(
              value: board,
              builder: (requests) {
                if (requests.isEmpty) {
                  return const Center(
                    child: EmptyNote('No requests match these filters.'),
                  );
                }
                final attention =
                    requests.where((r) => r.needsAttention).toList();
                final rest = requests.where((r) => !r.needsAttention).toList();

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(boardProvider),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (attention.isNotEmpty) ...[
                        _GroupHeading(
                          'Needs attention',
                          count: attention.length,
                          colour: Theme.of(context).colorScheme.error,
                        ),
                        ...attention.map((r) => _RequestRow(r)),
                        const SizedBox(height: 24),
                      ],
                      _GroupHeading('Open', count: rest.length),
                      ...rest.map((r) => _RequestRow(r)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.filter});

  final BoardFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentEmployeeProvider).valueOrNull;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 280,
            child: TextField(
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 18),
                hintText: 'Customer, title, or #1042',
              ),
              onSubmitted: (v) => ref
                  .read(boardFilterProvider.notifier)
                  .update((f) => f.copyWith(search: v)),
            ),
          ),
          const SizedBox(width: 12),
          DropdownMenu<RequestStatus?>(
            initialSelection: filter.status,
            width: 200,
            label: const Text('Stage'),
            dropdownMenuEntries: [
              const DropdownMenuEntry(value: null, label: 'All stages'),
              ...RequestStatus.values.map(
                (s) => DropdownMenuEntry(value: s, label: s.label),
              ),
            ],
            onSelected: (s) => ref.read(boardFilterProvider.notifier).update(
                  (f) => s == null
                      ? f.copyWith(clearStatus: true)
                      : f.copyWith(status: s),
                ),
          ),
          const SizedBox(width: 12),
          if (me != null)
            FilterChip(
              label: const Text('Mine'),
              selected: filter.supervisorId == me.id,
              onSelected: (on) => ref.read(boardFilterProvider.notifier).update(
                    (f) => on
                        ? f.copyWith(supervisorId: me.id)
                        : f.copyWith(clearSupervisor: true),
                  ),
            ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Include closed'),
            selected: !filter.openOnly,
            onSelected: (on) => ref
                .read(boardFilterProvider.notifier)
                .update((f) => f.copyWith(openOnly: !on)),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh, size: 18),
            onPressed: () => ref.invalidate(boardProvider),
          ),
        ],
      ),
    );
  }
}

class _GroupHeading extends StatelessWidget {
  const _GroupHeading(this.label, {required this.count, this.colour});

  final String label;
  final int count;
  final Color? colour;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1,
              color: colour ?? theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Text('$count', style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow(this.request);

  final RequestSummary request;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () => context.go('/requests/${request.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                child:
                    Text(request.reference, style: theme.textTheme.titleSmall),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.customerName,
                        style: theme.textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis),
                    if (request.title != null)
                      Text(request.title!,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                          overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    StatusChip(request.status.label,
                        color: statusColour(request.status, scheme)),
                    if (request.waitingOn != null)
                      StatusChip(request.waitingOn!.label,
                          color: Colors.red, icon: Icons.pause_circle_outline),
                    if (request.isOverdue)
                      StatusChip('Overdue',
                          color: scheme.error, icon: Icons.schedule),
                    if (request.needsSupervisor)
                      const StatusChip('No supervisor',
                          color: Colors.deepOrange,
                          icon: Icons.person_off_outlined),
                  ],
                ),
              ),
              SizedBox(
                width: 120,
                child: Text(
                  request.supervisorName ?? '—',
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(
                width: 80,
                child: Text(
                    '${request.itemCount} item'
                    '${request.itemCount == 1 ? '' : 's'}',
                    style: theme.textTheme.bodySmall),
              ),
              SizedBox(
                width: 110,
                child: Text(
                  request.neededBy != null
                      ? Fmt.date(request.neededBy)
                      : Fmt.date(request.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: request.isOverdue ? scheme.error : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
