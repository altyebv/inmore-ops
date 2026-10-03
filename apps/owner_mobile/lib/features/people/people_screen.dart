import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inmore_core/inmore_core.dart';
import 'package:inmore_ui/inmore_ui.dart';

import '../../data/cached.dart';
import '../../widgets/owner_page.dart';
import '../request/request_screen.dart';

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
    final l = context.l10n;
    final people = ref.watch(peopleProvider);

    return AsyncView(
      value: people,
      onRetry: () => refreshOwner(ref),
      loading: const OwnerPageSkeleton(figures: false),
      builder: (cached) => OwnerPage(
        title: l.peopleTitle,
        subtitle: l.peopleSubtitle,
        cached: cached,
        children: [
          if (cached.value.isEmpty)
            EmptyState(
              icon: Icons.free_breakfast_outlined,
              title: l.noOpenWork,
            )
          else
            for (final w in cached.value)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.sm),
                child: _PersonCard(workload: w),
              ),
        ],
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.workload});

  final Workload workload;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;
    final name = workload.isUnassigned ? l.unassigned : workload.name;

    return Card(
      child: Theme(
        // ExpansionTile draws its own dividers; the card already has edges.
        data: context.theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: Space.lg),
          leading: workload.isUnassigned
              ? CircleAvatar(
                  radius: 18,
                  backgroundColor: t.warning.withValues(alpha: 0.14),
                  child: Icon(Icons.person_off_outlined,
                      size: 18, color: t.warning),
                )
              : InitialsAvatar(name, size: 36),
          title: UserText(name, style: context.text.titleSmall),
          // The late count sits under the name rather than in `trailing`,
          // which would replace the expand arrow.
          subtitle: Wrap(
            spacing: Space.sm,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                [
                  l.openCount(workload.tasks.length),
                  if (workload.inProgressCount > 0)
                    l.inProgressCount(workload.inProgressCount),
                ].join(' · '),
                style: context.text.bodySmall,
              ),
              if (workload.overdueCount > 0)
                StatusBadge(
                  l.lateCount(workload.overdueCount),
                  color: t.danger,
                  icon: Icons.schedule_rounded,
                ),
            ],
          ),
          children: [
            for (final task in workload.tasks)
              ListTile(
                dense: true,
                contentPadding:
                    const EdgeInsetsDirectional.only(start: 68, end: Space.lg),
                title: UserText(task.title, style: context.text.bodyMedium),
                subtitle: Text(
                  '#${task.requestNumber} · ${task.customerName}',
                  style: context.text.bodySmall,
                ),
                trailing: StatusBadge(
                  task.status.tr(l),
                  color: task.isOverdue ? t.danger : t.task(task.status),
                  dot: true,
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => RequestScreen(requestId: task.requestId),
                  ),
                ),
              ),
            const SizedBox(height: Space.sm),
          ],
        ),
      ),
    );
  }
}
