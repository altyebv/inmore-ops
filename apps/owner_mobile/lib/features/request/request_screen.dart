import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inmore_core/inmore_core.dart';

import '../../widgets/common.dart';

/// One request, read-only.
///
/// The owner's app never writes. That keeps it small, and it keeps the
/// operational record owned by the people doing the work — if the owner could
/// move a status from his phone, the history would stop reflecting who
/// actually did what.
class RequestScreen extends ConsumerWidget {
  const RequestScreen({required this.requestId, super.key});

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = ref.watch(requestProvider(requestId));
    final me = ref.watch(currentEmployeeProvider).valueOrNull;
    final canSeeMoney = me?.role.canSeeMoney ?? false;

    return Scaffold(
      appBar: AppBar(
        title: AsyncView(
          value: request,
          builder: (r) => Text(r.reference),
        ),
      ),
      body: AsyncView(
        value: request,
        builder: (r) => RefreshIndicator(
          onRefresh: () async {
            ref
              ..invalidate(requestProvider(requestId))
              ..invalidate(requestItemsProvider(requestId))
              ..invalidate(requestFinancialsProvider(requestId))
              ..invalidate(requestTasksProvider(requestId))
              ..invalidate(requestActivityProvider(requestId));
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _Header(request: r),
              if (canSeeMoney) _Money(requestId: requestId),
              _Items(requestId: requestId),
              _Work(requestId: requestId),
              _History(requestId: requestId),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.request});

  final RequestSummary request;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(request.customerName, style: theme.textTheme.headlineSmall),
        if (request.customerCompany != null)
          Text(
            request.customerCompany!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        if (request.title != null) ...[
          const SizedBox(height: 6),
          Text(request.title!, style: theme.textTheme.bodyLarge),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            Pill(
              request.status.label,
              colour: stageColour(request.status, scheme),
            ),
            if (request.waitingOn != null)
              Pill(
                request.waitingOn!.label,
                colour: Colors.red,
                icon: Icons.pause_circle_outline,
              ),
            if (request.isOverdue)
              Pill('Overdue', colour: scheme.error, icon: Icons.schedule),
          ],
        ),
        const SizedBox(height: 12),
        _Line('Supervisor', request.supervisorName ?? 'Nobody yet'),
        _Line('Opened', Fmt.date(request.createdAt)),
        if (request.neededBy != null)
          _Line('Needed by', Fmt.date(request.neededBy)),
        if (request.customerPhone != null)
          _Line('Phone', request.customerPhone!),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _Money extends ConsumerWidget {
  const _Money({required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fin = ref.watch(requestFinancialsProvider(requestId));
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading('Money'),
        AsyncView(
          value: fin,
          builder: (f) {
            if (f == null) return const Nothing('Not available.');
            if (!f.hasApprovedQuotation) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    // "Nothing approved", not "not priced": a quotation may
                    // well have been given to the customer and be sitting
                    // with them. Telling the owner it has no price would send
                    // him chasing a supervisor who has already done the work.
                    f.paidTotal > 0
                        ? '${Fmt.money(f.paidTotal)} paid in advance. Nothing '
                            'has been approved yet, so there is no balance.'
                        : 'No approved quotation yet.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              );
            }
            return Row(
              children: [
                Expanded(
                  child: Figure(
                    value: Fmt.money(f.approvedTotal),
                    label: 'Approved',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Figure(
                    value: Fmt.money(f.balance),
                    label: 'Still owed',
                    colour: f.balance > 0 ? theme.colorScheme.error : null,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Items extends ConsumerWidget {
  const _Items({required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(requestItemsProvider(requestId));
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading('What they asked for'),
        AsyncView(
          value: items,
          builder: (list) => list.isEmpty
              ? const Nothing('Nothing listed.')
              : Card(
                  child: Column(
                    children: [
                      for (final i in list)
                        ListTile(
                          dense: true,
                          title: Text(i.name),
                          subtitle: Text(
                            i.specs == null
                                ? i.quantityLabel
                                : '${i.quantityLabel} · ${i.specs}',
                            style: theme.textTheme.bodySmall,
                          ),
                          trailing: Pill(i.status.label),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _Work extends ConsumerWidget {
  const _Work({required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(requestTasksProvider(requestId));
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading('Who is on it'),
        AsyncView(
          value: tasks,
          builder: (list) => list.isEmpty
              ? const Nothing('Nobody assigned yet.')
              : Card(
                  child: Column(
                    children: [
                      for (final t in list)
                        ListTile(
                          dense: true,
                          title: Text(t.title),
                          subtitle: Text(
                            t.isExternal
                                ? '${t.executorName} (external)'
                                : t.executorName,
                            style: theme.textTheme.bodySmall,
                          ),
                          trailing: Pill(
                            t.duration != null
                                ? Fmt.duration(t.duration)
                                : t.status.label,
                            colour: t.isOverdue ? scheme.error : null,
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _History extends ConsumerWidget {
  const _History({required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(requestActivityProvider(requestId));
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading('What happened'),
        AsyncView(
          value: feed,
          builder: (entries) => entries.isEmpty
              ? const Nothing('Nothing recorded.')
              : Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Column(
                      children: [
                        for (final e in entries)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        activityDescription(e),
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                      Text(
                                        '${e.actorName} · '
                                        '${Fmt.timelineStamp(e.occurredAt)}',
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
