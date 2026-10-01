import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inmore_core/inmore_core.dart';

import '../../widgets/common.dart';

/// Who is handling what.
///
/// Partners appear alongside employees, because a job sitting at an external
/// printer is just as much "in progress somewhere" as one on a designer's
/// desk — and the owner's question is where the work is, not who is on
/// payroll.
class PeopleScreen extends ConsumerWidget {
  const PeopleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workload = ref.watch(workloadProvider);
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(workloadProvider),
      child: AsyncView(
        value: workload,
        builder: (people) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text('People', style: theme.textTheme.headlineSmall),
            Text(
              'Open work, most loaded first',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (people.isEmpty)
              const Nothing('No open work assigned to anyone.')
            else
              ...people.map((w) => _PersonCard(workload: w)),
          ],
        ),
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.workload});

  final Workload workload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        shape: const Border(),
        leading: CircleAvatar(
          radius: 16,
          child: Text(
            workload.name.characters.first,
            style: theme.textTheme.labelLarge,
          ),
        ),
        title: Text(workload.name, style: theme.textTheme.titleSmall),
        subtitle: Text(
          '${workload.tasks.length} open'
          '${workload.inProgressCount > 0 ? ' · ${workload.inProgressCount} in progress' : ''}',
          style: theme.textTheme.bodySmall,
        ),
        trailing: workload.overdueCount > 0
            ? Pill(
                '${workload.overdueCount} late',
                colour: scheme.error,
                icon: Icons.schedule,
              )
            : null,
        children: [
          for (final t in workload.tasks)
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.only(left: 64, right: 16),
              title: Text(t.title, style: theme.textTheme.bodyMedium),
              subtitle: Text(
                '#${t.requestNumber} · ${t.customerName}',
                style: theme.textTheme.bodySmall,
              ),
              trailing: Pill(
                t.status.label,
                colour: t.isOverdue ? scheme.error : null,
              ),
            ),
        ],
      ),
    );
  }
}
