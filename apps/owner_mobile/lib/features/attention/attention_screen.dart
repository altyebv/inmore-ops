import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inmore_core/inmore_core.dart';
import 'package:inmore_ui/inmore_ui.dart';

import '../../data/cached.dart';
import '../../widgets/owner_page.dart';
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
    final l = context.l10n;
    final overview = ref.watch(overviewProvider);
    final t = context.tokens;

    return AsyncView(
      value: overview,
      onRetry: () => refreshOwner(ref),
      loading: const OwnerPageSkeleton(figures: false),
      builder: (cached) {
        final s = cached.value;
        if (s.attention.isEmpty) {
          return OwnerPage(
            title: l.attentionTitle,
            cached: cached,
            children: [
              const SizedBox(height: 48),
              EmptyState(
                icon: Icons.check_circle_outline_rounded,
                tone: t.success,
                title: l.nothingStuck,
                body: l.nothingStuckBody,
              ),
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

        return OwnerPage(
          title: l.attentionTitle,
          subtitle: l.attentionSubtitle(s.attention.length, s.activeCount),
          cached: cached,
          children: [
            for (final reason in WaitingReason.values)
              if (blockedBy[reason] != null) ...[
                SectionHeading(
                  reason.tr(l),
                  trailing: '${blockedBy[reason]!.length}',
                  color: t.danger,
                ),
                ...blockedBy[reason]!.map(RequestTile.new),
              ],
            if (overdue.isNotEmpty) ...[
              SectionHeading(
                l.pastPromisedDate,
                trailing: '${overdue.length}',
                color: t.danger,
              ),
              ...overdue.map(RequestTile.new),
            ],
            if (unowned.isNotEmpty) ...[
              SectionHeading(
                l.nobodyPickedUp,
                trailing: '${unowned.length}',
                color: t.warning,
              ),
              ...unowned.map(RequestTile.new),
            ],
          ],
        );
      },
    );
  }
}
