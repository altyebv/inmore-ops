import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inmore_core/inmore_core.dart';

import '../../widgets/common.dart';
import '../../widgets/request_tile.dart';

/// Where the money is.
///
/// Deliberately not accounting: it answers "how much is owed and by whom",
/// which is the operational question, and nothing else.
class MoneyScreen extends ConsumerWidget {
  const MoneyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final money = ref.watch(moneySnapshotProvider);
    final snapshot = ref.watch(ownerSnapshotProvider);
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async {
        ref
          ..invalidate(moneySnapshotProvider)
          ..invalidate(ownerSnapshotProvider);
      },
      child: AsyncView(
        value: money,
        builder: (m) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text('Money', style: theme.textTheme.headlineSmall),
            Text(
              'Across every request',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Figure(
              value: Fmt.money(m.outstanding),
              label: '${m.requestsOwing} request'
                  '${m.requestsOwing == 1 ? '' : 's'} still owing',
              colour: m.outstanding > 0 ? theme.colorScheme.error : null,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Figure(
                    value: Fmt.money(m.approved),
                    label: 'Approved in total',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Figure(
                    value: Fmt.money(m.received),
                    label: 'Received',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Only jobs with an approved quotation count towards what is '
              'owed. A down payment taken before pricing shows under Received '
              'and nowhere else — counting it as a debt would invent a number.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SectionHeading('Waiting on payment'),
            snapshot.maybeWhen(
              data: (s) {
                final waiting = s.open
                    .where((r) => r.waitingOn == WaitingReason.payment)
                    .toList();
                if (waiting.isEmpty) {
                  return const Nothing('No job is held up on payment.');
                }
                return Column(children: waiting.map(RequestTile.new).toList());
              },
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
