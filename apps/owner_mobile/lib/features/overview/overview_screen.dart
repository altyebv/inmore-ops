import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inmore_core/inmore_core.dart';
import 'package:inmore_ui/inmore_ui.dart';

import '../../data/cached.dart';
import '../../home.dart';
import '../../widgets/owner_page.dart';
import '../../widgets/request_tile.dart';

/// What is happening right now.
class OverviewScreen extends ConsumerWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final overview = ref.watch(overviewProvider);
    final me = ref.watch(currentEmployeeProvider).valueOrNull;
    final t = context.tokens;

    return AsyncView(
      value: overview,
      onRetry: () => refreshOwner(ref),
      loading: const OwnerPageSkeleton(),
      builder: (cached) {
        final s = cached.value;
        void toAttention() => ref.read(homeTabProvider.notifier).state = 1;

        return OwnerPage(
          title: me == null ? l.appName : _greeting(l, me.shortName),
          cached: cached,
          children: [
            _Hero(active: s.activeCount, label: l.openJobs),
            const SizedBox(height: Space.md),
            Row(
              children: [
                Expanded(
                  child: FigureTile(
                    icon: Icons.move_to_inbox_outlined,
                    value: '${s.arrivedThisWeek.length}',
                    label: l.cameInThisWeek,
                    color: s.arrivedThisWeek.isEmpty ? null : t.info,
                  ),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: FigureTile(
                    icon: Icons.check_circle_outline_rounded,
                    value: '${s.completedThisWeek.length}',
                    label: l.finishedThisWeek,
                    color: s.completedThisWeek.isEmpty ? null : t.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.md),
            Row(
              children: [
                Expanded(
                  child: FigureTile(
                    icon: Icons.pause_circle_outline_rounded,
                    value: '${s.blocked.length}',
                    label: l.blocked,
                    color: s.blocked.isEmpty ? null : t.danger,
                    onTap: s.blocked.isEmpty ? null : toAttention,
                  ),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: FigureTile(
                    icon: Icons.schedule_rounded,
                    value: '${s.overdue.length}',
                    label: l.pastDue,
                    color: s.overdue.isEmpty ? null : t.danger,
                    onTap: s.overdue.isEmpty ? null : toAttention,
                  ),
                ),
              ],
            ),
            SectionHeading(l.whereWorkSits),
            _Pipeline(snapshot: s),
            SectionHeading(l.latest),
            if (s.open.isEmpty)
              EmptyState(
                compact: true,
                icon: Icons.inbox_outlined,
                title: l.nothingOpen,
              )
            else
              ...s.open.take(6).map(RequestTile.new),
          ],
        );
      },
    );
  }

  static String _greeting(L10n l, String name) {
    final h = DateTime.now().hour;
    if (h < 12) return l.greetingMorning(name);
    if (h < 17) return l.greetingAfternoon(name);
    return l.greetingEvening(name);
  }
}

/// The headline number on the brand ground, stripe underneath.
class _Hero extends StatelessWidget {
  const _Hero({required this.active, required this.label});

  final int active;
  final String label;

  @override
  Widget build(BuildContext context) {
    const fg = Color(0xFFF2F2F0);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: const Color(0xFF17181B),
        borderRadius: BorderRadius.circular(Radii.xl),
        // Barely there in light mode; in dark mode it is what separates the
        // brand card from the page.
        border: Border.all(color: context.colors.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$active',
                  style: context.text.displaySmall?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(label,
                    style: context.text.titleSmall?.copyWith(
                      color: fg.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w400,
                    )),
                const SizedBox(height: Space.md),
                const CmykStripe(width: 96, height: 4, gap: 5, onDark: true),
              ],
            ),
          ),
          const InmoreMark(height: 44, onDark: true),
        ],
      ),
    );
  }
}

/// How many open jobs sit at each stage: one stacked bar to see the shape,
/// then a row per stage to read the numbers.
class _Pipeline extends StatelessWidget {
  const _Pipeline({required this.snapshot});

  final OwnerSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;
    final total = snapshot.activeCount;
    final counts = snapshot.byStage;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: SizedBox(
                height: 10,
                child: total == 0
                    ? Container(color: context.colors.surfaceContainerHighest)
                    : Row(
                        children: [
                          for (final stage in RequestStatus.pipeline)
                            if ((counts[stage] ?? 0) > 0)
                              Expanded(
                                flex: counts[stage]!,
                                child: Container(color: t.stage(stage)),
                              ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: Space.md),
            for (final stage in RequestStatus.pipeline)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: t.stage(stage),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Text(stage.tr(l), style: context.text.bodyMedium),
                    ),
                    Text(
                      '${counts[stage] ?? 0}',
                      style: context.text.titleSmall?.copyWith(
                        color: (counts[stage] ?? 0) == 0
                            ? context.colors.onSurfaceVariant
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
