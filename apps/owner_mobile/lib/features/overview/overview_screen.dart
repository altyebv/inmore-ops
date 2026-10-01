import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inmore_core/inmore_core.dart';

import '../../widgets/common.dart';
import '../../widgets/request_tile.dart';

/// What is happening right now.
class OverviewScreen extends ConsumerWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(ownerSnapshotProvider);
    final me = ref.watch(currentEmployeeProvider).valueOrNull;
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(ownerSnapshotProvider),
      child: AsyncView(
        value: snapshot,
        builder: (s) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text(
              me == null ? 'Inmore' : 'Good day, ${me.shortName}',
              style: theme.textTheme.headlineSmall,
            ),
            Text(
              '${s.activeCount} job${s.activeCount == 1 ? '' : 's'} open',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Figure(
                    value: '${s.arrivedThisWeek.length}',
                    label: 'Came in this week',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Figure(
                    value: '${s.completedThisWeek.length}',
                    label: 'Finished this week',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Figure(
                    value: '${s.blocked.length}',
                    label: 'Blocked',
                    colour: s.blocked.isEmpty ? null : theme.colorScheme.error,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Figure(
                    value: '${s.overdue.length}',
                    label: 'Past due',
                    colour: s.overdue.isEmpty ? null : theme.colorScheme.error,
                  ),
                ),
              ],
            ),
            const SectionHeading('Where the work sits'),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                child: Column(
                  children: [
                    for (final stage in RequestStatus.pipeline)
                      _StageRow(
                        stage: stage,
                        count: s.byStage[stage] ?? 0,
                        total: s.activeCount,
                      ),
                  ],
                ),
              ),
            ),
            const SectionHeading('Latest'),
            if (s.open.isEmpty)
              const Nothing('Nothing open.')
            else
              ...s.open.take(8).map(RequestTile.new),
          ],
        ),
      ),
    );
  }
}

/// A count and a proportional bar. Not a chart — a bar you can read at a
/// glance without a legend.
class _StageRow extends StatelessWidget {
  const _StageRow({
    required this.stage,
    required this.count,
    required this.total,
  });

  final RequestStatus stage;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fraction = total == 0 ? 0.0 : count / total;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 112,
            child: Text(stage.label, style: theme.textTheme.bodySmall),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 6,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(
                  stageColour(stage, scheme),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$count',
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
