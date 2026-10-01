import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inmore_core/inmore_core.dart';

import '../../widgets/common.dart';

/// Where designers and production land.
///
/// They can move their own task along and nothing else — the database
/// enforces that, so this screen simply doesn't offer the rest.
class MyWorkScreen extends ConsumerWidget {
  const MyWorkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(myWorkProvider);
    final me = ref.watch(currentEmployeeProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My work'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh, size: 18),
            onPressed: () => ref.invalidate(myWorkProvider),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AsyncView(
        value: tasks,
        builder: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.task_alt, size: 40),
                  const SizedBox(height: 12),
                  Text(me == null
                      ? 'Nothing assigned.'
                      : 'Nothing assigned to you, ${me.shortName}.'),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, i) => _TaskCard(task: list[i]),
          );
        },
      ),
    );
  }
}

class _TaskCard extends ConsumerWidget {
  const _TaskCard({required this.task});

  final TaskSummary task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(task.title, style: theme.textTheme.titleSmall),
                      const SizedBox(width: 8),
                      StatusChip(task.type.label),
                      const SizedBox(width: 6),
                      StatusChip(task.status.label,
                          color: taskColour(task.status, scheme)),
                      if (task.isOverdue) ...[
                        const SizedBox(width: 6),
                        StatusChip('Overdue',
                            color: scheme.error, icon: Icons.schedule),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '#${task.requestNumber} · ${task.customerName}'
                    '${task.itemName != null ? ' · ${task.itemName}' : ''}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  if (task.dueAt != null)
                    Text('Due ${Fmt.dateTime(task.dueAt)}',
                        style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            // Only the statuses a person moves their own work through.
            SegmentedButton<TaskStatus>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: TaskStatus.todo, label: Text('To do')),
                ButtonSegment(
                    value: TaskStatus.inProgress, label: Text('Doing')),
                ButtonSegment(
                    value: TaskStatus.blocked, label: Text('Blocked')),
                ButtonSegment(value: TaskStatus.done, label: Text('Done')),
              ],
              selected: {task.status},
              onSelectionChanged: (sel) async {
                final ok = await runAction(
                  context,
                  () => ref
                      .read(taskRepositoryProvider)
                      .setStatus(task.id, sel.first),
                );
                if (ok) {
                  ref
                    ..invalidate(myWorkProvider)
                    ..invalidate(requestTasksProvider(task.requestId))
                    ..invalidate(requestActivityProvider(task.requestId));
                }
              },
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Open request',
              icon: const Icon(Icons.open_in_new, size: 18),
              onPressed: () => context.go('/requests/${task.requestId}'),
            ),
          ],
        ),
      ),
    );
  }
}
