import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inmore_core/inmore_core.dart';
import 'package:inmore_ui/inmore_ui.dart';

/// Where designers and production land.
///
/// They can move their own task along and nothing else — the database
/// enforces that, so this screen simply doesn't offer the rest. Grouped by
/// what the person is doing now, then what is next, then what is stuck.
class MyWorkScreen extends ConsumerWidget {
  const MyWorkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final tasks = ref.watch(myWorkProvider);
    final count = tasks.valueOrNull?.length;

    return Column(
      children: [
        PageHeader(
          title: l.myWorkTitle,
          subtitle: count == null ? null : l.myWorkSubtitle(count),
          actions: [
            IconButton(
              tooltip: '${l.refresh}  (F5)',
              onPressed: () => ref.invalidate(myWorkProvider),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        Expanded(
          child: AsyncView(
            value: tasks,
            onRetry: () => ref.invalidate(myWorkProvider),
            builder: (list) {
              if (list.isEmpty) {
                return EmptyState(
                  icon: Icons.task_alt_rounded,
                  tone: context.tokens.success,
                  title: l.allCaughtUp,
                  body: l.allCaughtUpBody,
                );
              }
              final groups = [
                (TaskStatus.inProgress, l.taskInProgress),
                (TaskStatus.todo, l.taskTodo),
                (TaskStatus.blocked, l.taskBlocked),
              ];
              return ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 32),
                children: [
                  for (final (status, label) in groups)
                    if (list.any((t) => t.status == status)) ...[
                      SectionHeading(
                        label,
                        trailing:
                            '${list.where((t) => t.status == status).length}',
                        color: status == TaskStatus.blocked
                            ? context.tokens.danger
                            : null,
                      ),
                      for (final t in list.where((t) => t.status == status))
                        Padding(
                          padding: const EdgeInsets.only(bottom: Space.sm),
                          child: _TaskCard(task: t),
                        ),
                    ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TaskCard extends ConsumerWidget {
  const _TaskCard({required this.task});

  final TaskSummary task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = context.tokens;
    final c = context.colors;

    return Card(
      child: InkWell(
        onTap: () => context.go('/requests/${task.requestId}'),
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 44,
                decoration: BoxDecoration(
                  color: t.task(task.status),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: Space.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: UserText(task.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.titleSmall),
                        ),
                        const SizedBox(width: Space.sm),
                        StatusBadge(task.type.tr(l)),
                        if (task.isOverdue) ...[
                          const SizedBox(width: 6),
                          StatusBadge(l.flagOverdue,
                              color: t.danger, icon: Icons.schedule_rounded),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        '#${task.requestNumber}',
                        task.customerName,
                        if (task.itemName != null) task.itemName!,
                        if (task.dueAt != null)
                          l.dueOn(Fmt.dateTime(task.dueAt)),
                      ].join('  ·  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(
                        color: task.isOverdue ? t.danger : c.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Space.lg),
              // Only the statuses a person moves their own work through.
              SegmentedButton<TaskStatus>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                      value: TaskStatus.todo, label: Text(l.taskTodo)),
                  ButtonSegment(
                      value: TaskStatus.inProgress,
                      label: Text(l.taskDoingShort)),
                  ButtonSegment(
                      value: TaskStatus.blocked, label: Text(l.taskBlocked)),
                  ButtonSegment(
                      value: TaskStatus.done, label: Text(l.taskDone)),
                ],
                selected: {task.status},
                onSelectionChanged: (sel) async {
                  final ok = await runAction(
                    context,
                    () => ref
                        .read(taskRepositoryProvider)
                        .setStatus(task.id, sel.first),
                    success: l.markedStatus(sel.first.tr(l)),
                  );
                  if (ok) {
                    ref
                      ..invalidate(myWorkProvider)
                      ..invalidate(requestTasksProvider(task.requestId))
                      ..invalidate(requestActivityProvider(task.requestId));
                  }
                },
              ),
              const SizedBox(width: Space.sm),
              IconButton(
                tooltip: l.openRequest,
                onPressed: () => context.go('/requests/${task.requestId}'),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
