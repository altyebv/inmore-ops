import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inmore_core/inmore_core.dart';

import '../../widgets/common.dart';
import '../../widgets/request_tile.dart';

/// What is stuck, and why.
///
/// Grouped by reason rather than merged into one list: "waiting on the
/// customer" and "nobody has picked this up" need different actions from the
/// owner, and a single list hides that.
class AttentionScreen extends ConsumerWidget {
  const AttentionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(ownerSnapshotProvider);
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(ownerSnapshotProvider),
      child: AsyncView(
        value: snapshot,
        builder: (s) {
          if (s.attention.isEmpty) {
            return ListView(
              children: [
                const SizedBox(height: 80),
                Icon(
                  Icons.check_circle_outline,
                  size: 44,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 12),
                const Nothing('Nothing is stuck. Everything open is moving.'),
              ],
            );
          }

          // Each job appears once, under the most specific reason it is
          // stuck. A request can be blocked AND overdue AND unowned all at
          // once; listing it three times makes the page look longer than the
          // problem is, and makes the count at the top look wrong.
          final shown = <String>{};
          List<RequestSummary> take(Iterable<RequestSummary> rs) =>
              rs.where((r) => shown.add(r.id)).toList(growable: false);

          final blockedBy = <WaitingReason, List<RequestSummary>>{};
          for (final r in take(s.blocked)) {
            blockedBy.putIfAbsent(r.waitingOn!, () => []).add(r);
          }
          final overdue = take(s.overdue);
          final unowned = take(s.unowned);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Text('Needs attention', style: theme.textTheme.headlineSmall),
              Text(
                '${s.attention.length} of ${s.activeCount} open jobs',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              for (final reason in WaitingReason.values)
                if (blockedBy[reason] != null) ...[
                  SectionHeading(
                    reason.label,
                    trailing: '${blockedBy[reason]!.length}',
                  ),
                  ...blockedBy[reason]!.map(RequestTile.new),
                ],
              if (overdue.isNotEmpty) ...[
                SectionHeading(
                  'Past the promised date',
                  trailing: '${overdue.length}',
                ),
                ...overdue.map(RequestTile.new),
              ],
              if (unowned.isNotEmpty) ...[
                SectionHeading(
                  'Nobody has picked these up',
                  trailing: '${unowned.length}',
                ),
                ...unowned.map(RequestTile.new),
              ],
            ],
          );
        },
      ),
    );
  }
}
