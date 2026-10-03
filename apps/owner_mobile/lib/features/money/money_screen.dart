import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inmore_core/inmore_core.dart';
import 'package:inmore_ui/inmore_ui.dart';

import '../../data/cached.dart';
import '../../widgets/owner_page.dart';
import '../../widgets/request_tile.dart';

/// Where the money is.
///
/// Deliberately not accounting: it answers "how much is owed and by whom",
/// which is the operational question, and nothing else.
class MoneyScreen extends ConsumerWidget {
  const MoneyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final money = ref.watch(moneyProvider);
    final overview = ref.watch(overviewProvider).valueOrNull?.value;
    final t = context.tokens;

    return AsyncView(
      value: money,
      onRetry: () => refreshOwner(ref),
      loading: const OwnerPageSkeleton(),
      builder: (cached) {
        final m = cached.value;
        final collected =
            m.approved == 0 ? 0.0 : (m.received / m.approved).clamp(0.0, 1.0);
        final waiting = overview?.open
                .where((r) => r.waitingOn == WaitingReason.payment)
                .toList() ??
            const <RequestSummary>[];

        return OwnerPage(
          title: l.moneyTitle,
          subtitle: l.acrossEveryRequest,
          cached: cached,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.stillOwed,
                        style: context.text.labelLarge?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        )),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        Fmt.money(m.outstanding),
                        style: context.text.displaySmall?.copyWith(
                          color: m.outstanding > 0 ? t.danger : t.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(l.stillOwing(m.requestsOwing),
                        style: context.text.bodyMedium),
                    const SizedBox(height: Space.lg),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: collected,
                        minHeight: 8,
                        color: t.success,
                      ),
                    ),
                    const SizedBox(height: Space.sm),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${l.received} ${(collected * 100).round()}%',
                            style: context.text.labelMedium,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Space.md),
            Row(
              children: [
                Expanded(
                  child: FigureTile(
                    icon: Icons.verified_outlined,
                    value: Fmt.moneyShort(m.approved),
                    label: l.approvedInTotal,
                  ),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: FigureTile(
                    icon: Icons.savings_outlined,
                    value: Fmt.moneyShort(m.received),
                    label: l.received,
                    color: t.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 16, color: context.colors.onSurfaceVariant),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(l.moneyNote, style: context.text.bodySmall),
                ),
              ],
            ),
            SectionHeading(
              l.waitingOnPayment,
              trailing: waiting.isEmpty ? null : '${waiting.length}',
            ),
            if (waiting.isEmpty)
              EmptyState(
                compact: true,
                icon: Icons.check_rounded,
                tone: t.success,
                title: l.noneOnPayment,
              )
            else
              ...waiting.map(RequestTile.new),
          ],
        );
      },
    );
  }
}
