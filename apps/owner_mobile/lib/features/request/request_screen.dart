import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inmore_core/inmore_core.dart';
import 'package:inmore_ui/inmore_ui.dart';

/// One request, read-only.
///
/// The owner's app never writes. That keeps it small, and it keeps the
/// operational record owned by the people doing the work — if the owner could
/// move a status from his phone, the history would stop reflecting who
/// actually did what.
class RequestScreen extends ConsumerWidget {
  const RequestScreen({required this.requestId, super.key});

  final String requestId;

  void _refresh(WidgetRef ref) {
    ref
      ..invalidate(requestProvider(requestId))
      ..invalidate(requestItemsProvider(requestId))
      ..invalidate(requestFinancialsProvider(requestId))
      ..invalidate(requestTasksProvider(requestId))
      ..invalidate(requestActivityProvider(requestId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = ref.watch(requestProvider(requestId));
    final me = ref.watch(currentEmployeeProvider).valueOrNull;
    final canSeeMoney = me?.role.canSeeMoney ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(request.valueOrNull?.reference ?? ''),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const OfflineBanner(),
            Expanded(
              child: AsyncView(
                value: request,
                onRetry: () => _refresh(ref),
                builder: (r) => RefreshIndicator(
                  onRefresh: () async {
                    _refresh(ref);
                    await ref
                        .read(requestProvider(requestId).future)
                        .catchError((_) => r);
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    children: [
                      _Header(request: r),
                      const SizedBox(height: Space.md),
                      _Facts(request: r),
                      if (canSeeMoney) ...[
                        const SizedBox(height: Space.md),
                        _Money(requestId: requestId),
                      ],
                      const SizedBox(height: Space.md),
                      _Items(requestId: requestId),
                      const SizedBox(height: Space.md),
                      _Work(requestId: requestId),
                      const SizedBox(height: Space.md),
                      _History(requestId: requestId),
                    ],
                  ),
                ),
              ),
            ),
          ],
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
    final l = context.l10n;
    final t = context.tokens;
    final r = request;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UserText(r.customerName, style: context.text.titleLarge),
            if (r.customerCompany != null)
              UserText(r.customerCompany!,
                  style: context.text.bodyMedium
                      ?.copyWith(color: context.colors.onSurfaceVariant)),
            if (r.title != null) ...[
              const SizedBox(height: Space.sm),
              UserText(r.title!, style: context.text.bodyLarge),
            ],
            const SizedBox(height: Space.lg),
            StageStepper(status: r.status, compact: true),
            if (r.waitingOn != null || r.isOverdue || r.needsSupervisor) ...[
              const SizedBox(height: Space.md),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (r.waitingOn != null)
                    StatusBadge(r.waitingOn!.tr(l),
                        color: t.danger,
                        icon: Icons.pause_circle_outline_rounded),
                  if (r.isOverdue)
                    StatusBadge(l.flagOverdue,
                        color: t.danger, icon: Icons.schedule_rounded),
                  if (r.needsSupervisor)
                    StatusBadge(l.nobodyAssigned,
                        color: t.warning, icon: Icons.person_off_outlined),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Facts extends StatelessWidget {
  const _Facts({required this.request});

  final RequestSummary request;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final r = request;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Fact(
                    label: l.supervisor,
                    child: r.supervisorName == null
                        ? Text(l.nobodyYet,
                            style: TextStyle(color: context.tokens.warning))
                        : UserText(r.supervisorName!),
                  ),
                ),
                Expanded(
                  child:
                      Fact(label: l.opened, child: Text(Fmt.date(r.createdAt))),
                ),
              ],
            ),
            if (r.neededBy != null || r.customerPhone != null) ...[
              const SizedBox(height: Space.lg),
              Row(
                children: [
                  Expanded(
                    child: Fact(
                      label: l.neededBy,
                      child: Text(
                        r.neededBy == null ? l.notSet : Fmt.date(r.neededBy),
                        style: TextStyle(
                          color: r.isOverdue ? context.tokens.danger : null,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Fact(
                      label: l.phone,
                      child: Text(r.customerPhone ?? '—',
                          textDirection: TextDirection.ltr),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Money extends ConsumerWidget {
  const _Money({required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final fin = ref.watch(requestFinancialsProvider(requestId));
    final t = context.tokens;

    return SectionCard(
      icon: Icons.account_balance_wallet_outlined,
      title: l.moneyTitle,
      child: AsyncView(
        value: fin,
        compact: true,
        onRetry: () => ref.invalidate(requestFinancialsProvider(requestId)),
        builder: (f) {
          if (f == null) {
            return Text(l.notAvailable, style: context.text.bodySmall);
          }
          if (!f.hasApprovedQuotation) {
            // "Nothing approved", not "not priced": a quotation may well have
            // been given to the customer and be sitting with them. Telling
            // the owner it has no price would send him chasing a supervisor
            // who has already done the work.
            return Text(
              f.paidTotal > 0
                  ? l.paidInAdvanceAmount(Fmt.money(f.paidTotal))
                  : l.noApprovedQuotation,
              style: context.text.bodyMedium,
            );
          }
          final ratio = f.approvedTotal == 0
              ? 0.0
              : (f.paidTotal / f.approvedTotal).clamp(0.0, 1.0);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Fact(
                      label: l.approved,
                      child: Text(Fmt.money(f.approvedTotal),
                          style: context.text.titleSmall),
                    ),
                  ),
                  Expanded(
                    child: Fact(
                      label: l.stillOwed,
                      child: Text(
                        Fmt.money(f.balance),
                        style: context.text.titleSmall?.copyWith(
                          color: f.balance > 0 ? t.danger : t.success,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 6,
                  color: f.balance > 0 ? t.info : t.success,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Items extends ConsumerWidget {
  const _Items({required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final items = ref.watch(requestItemsProvider(requestId));

    return SectionCard(
      icon: Icons.inventory_2_outlined,
      title: l.whatTheyAskedFor,
      child: AsyncView(
        value: items,
        compact: true,
        onRetry: () => ref.invalidate(requestItemsProvider(requestId)),
        builder: (list) => list.isEmpty
            ? Text(l.nothingListed, style: context.text.bodySmall)
            : Column(
                children: [
                  for (var i = 0; i < list.length; i++) ...[
                    if (i > 0) const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                UserText(list[i].name,
                                    style: context.text.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w500)),
                                UserText(list[i].quantityLabel,
                                    style: context.text.bodySmall),
                                if (list[i].specs != null)
                                  UserText(list[i].specs!,
                                      style: context.text.bodySmall),
                              ],
                            ),
                          ),
                          const SizedBox(width: Space.sm),
                          StatusBadge(list[i].status.tr(l),
                              color: context.tokens.item(list[i].status)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _Work extends ConsumerWidget {
  const _Work({required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final tasks = ref.watch(requestTasksProvider(requestId));
    final t = context.tokens;

    return SectionCard(
      icon: Icons.handyman_outlined,
      title: l.whoIsOnIt,
      child: AsyncView(
        value: tasks,
        compact: true,
        onRetry: () => ref.invalidate(requestTasksProvider(requestId)),
        builder: (list) => list.isEmpty
            ? Text(l.nobodyAssigned, style: context.text.bodySmall)
            : Column(
                children: [
                  for (var i = 0; i < list.length; i++) ...[
                    if (i > 0) const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          InitialsAvatar(
                            list[i].assigneeName ?? list[i].partnerName ?? '?',
                            size: 32,
                          ),
                          const SizedBox(width: Space.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                UserText(list[i].title,
                                    style: context.text.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w500)),
                                Text(
                                  _executor(list[i], l),
                                  style: context.text.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          StatusBadge(
                            list[i].duration != null
                                ? l.duration(list[i].duration)
                                : list[i].status.tr(l),
                            color: list[i].isOverdue
                                ? t.danger
                                : t.task(list[i].status),
                            dot: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  String _executor(TaskSummary t, L10n l) {
    final name = t.assigneeName ?? t.partnerName ?? l.unassigned;
    return t.isExternal ? l.externalName(name) : name;
  }
}

class _History extends ConsumerWidget {
  const _History({required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final feed = ref.watch(requestActivityProvider(requestId));

    return SectionCard(
      icon: Icons.history_rounded,
      title: l.whatHappened,
      child: AsyncView(
        value: feed,
        compact: true,
        onRetry: () => ref.invalidate(requestActivityProvider(requestId)),
        builder: (entries) => entries.isEmpty
            ? Text(l.nothingRecorded, style: context.text.bodySmall)
            : Column(
                children: [
                  for (var i = 0; i < entries.length; i++)
                    TimelineEntry(
                      entry: entries[i],
                      last: i == entries.length - 1,
                    ),
                ],
              ),
      ),
    );
  }
}
