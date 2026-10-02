import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inmore_core/inmore_core.dart';
import 'package:inmore_ui/inmore_ui.dart';

// =============================================================================
// Stage and blocking
// =============================================================================

/// Stage and blocking are two separate controls, because they are two separate
/// columns. Marking a job "waiting on payment" must not lose the fact that it
/// is in production.
class StageCard extends ConsumerWidget {
  const StageCard({required this.request, required this.canManage, super.key});

  final RequestSummary request;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = context.tokens;
    final r = request;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StageStepper(
              status: r.status,
              onSelect: canManage && r.status.isOpen
                  ? (s) => runAction(
                        context,
                        () => ref
                            .read(requestRepositoryProvider)
                            .setStatus(r.id, s),
                        success: l.movedTo(s.tr(l)),
                      ).then((ok) {
                        if (ok) refreshRequest(ref, r.id);
                      })
                  : null,
            ),
            if (r.status.isOpen && (canManage || r.waitingOn != null)) ...[
              const SizedBox(height: Space.md),
              const Divider(),
              const SizedBox(height: Space.md),
              Row(
                children: [
                  Text(l.blockedOn,
                      style: context.text.labelLarge?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      )),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: canManage
                        ? Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              ChoiceChip(
                                label: Text(l.notBlocked),
                                avatar: Icon(Icons.play_arrow_rounded,
                                    size: 16, color: t.success),
                                selected: r.waitingOn == null,
                                showCheckmark: false,
                                onSelected: r.waitingOn == null
                                    ? null
                                    : (_) => _setWaiting(context, ref, null),
                              ),
                              for (final w in WaitingReason.values)
                                ChoiceChip(
                                  label: Text(w.tr(l)),
                                  selected: r.waitingOn == w,
                                  showCheckmark: false,
                                  selectedColor:
                                      t.danger.withValues(alpha: 0.14),
                                  onSelected: (_) => _setWaiting(
                                    context,
                                    ref,
                                    r.waitingOn == w ? null : w,
                                  ),
                                ),
                            ],
                          )
                        : Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: StatusBadge(r.waitingOn!.tr(l),
                                color: t.danger,
                                icon: Icons.pause_circle_outline_rounded),
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

  Future<void> _setWaiting(
    BuildContext context,
    WidgetRef ref,
    WaitingReason? reason,
  ) async {
    final ok = await runAction(
      context,
      () => ref.read(requestRepositoryProvider).setWaiting(request.id, reason),
    );
    if (ok) refreshRequest(ref, request.id);
  }
}

/// Ask why, then cancel. The reason is required — months from now it is the
/// only record of what happened.
Future<void> cancelRequestFlow(
  BuildContext context,
  WidgetRef ref,
  RequestSummary request,
) async {
  final l = context.l10n;
  final controller = TextEditingController();
  final reason = await showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        icon: Icon(Icons.block_rounded, color: context.colors.error),
        title: Text(l.cancelRequestTitle(request.reference)),
        content: SizedBox(
          width: 440,
          child: AppField(
            controller: controller,
            autofocus: true,
            label: l.cancelReasonLabel,
            hint: l.cancelReasonHint,
            helper: l.cancelReasonHelp,
            onChanged: (_) => setState(() {}),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.keepIt),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.colors.error,
              foregroundColor: context.colors.onError,
            ),
            onPressed: controller.text.trim().isEmpty
                ? null
                : () => Navigator.pop(context, controller.text.trim()),
            child: Text(l.cancelRequest),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
  if (reason == null || reason.isEmpty || !context.mounted) return;
  final ok = await runAction(
    context,
    () => ref.read(requestRepositoryProvider).cancel(request.id, reason),
    success: l.requestCancelled,
  );
  if (ok) refreshRequest(ref, request.id);
}

// =============================================================================
// Details
// =============================================================================

class DetailsPanel extends ConsumerWidget {
  const DetailsPanel(
      {required this.request, required this.canManage, super.key});

  final RequestSummary request;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final r = request;
    final t = context.tokens;

    return SectionCard(
      icon: Icons.info_outline_rounded,
      title: l.details,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Fact(
            label: l.supervisor,
            child: canManage
                ? _SupervisorPicker(request: r)
                : _Person(name: r.supervisorName),
          ),
          const SizedBox(height: Space.lg),
          Row(
            children: [
              Expanded(
                child: Fact(
                  label: l.neededBy,
                  child: Text(
                    r.neededBy == null ? l.notSet : Fmt.date(r.neededBy),
                    style: TextStyle(
                      color: r.isOverdue ? t.danger : null,
                      fontWeight: r.isOverdue ? FontWeight.w600 : null,
                    ),
                  ),
                ),
              ),
              Expanded(
                child:
                    Fact(label: l.created, child: Text(Fmt.date(r.createdAt))),
              ),
            ],
          ),
          const SizedBox(height: Space.lg),
          Fact(
            label: l.customer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserText(r.customerName,
                    style: context.text.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w500)),
                if (r.customerCompany != null)
                  UserText(r.customerCompany!, style: context.text.bodySmall),
                if (r.customerPhone != null)
                  Text(r.customerPhone!,
                      textDirection: TextDirection.ltr,
                      style: context.text.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: Space.lg),
          Fact(label: l.source, child: Text(r.source.tr(l))),
        ],
      ),
    );
  }
}

class _Person extends StatelessWidget {
  const _Person({required this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    if (name == null) {
      return Text(context.l10n.nobodyYet,
          style: TextStyle(color: context.tokens.warning));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InitialsAvatar(name!, size: 24),
        const SizedBox(width: Space.sm),
        Flexible(child: UserText(name!)),
      ],
    );
  }
}

class _SupervisorPicker extends ConsumerWidget {
  const _SupervisorPicker({required this.request});

  final RequestSummary request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final staff = ref.watch(activeEmployeesProvider).valueOrNull ?? const [];
    final supervisors =
        staff.where((e) => e.role.canManageRequests).toList(growable: false);

    return MenuAnchor(
      menuChildren: [
        for (final e in supervisors)
          MenuItemButton(
            leadingIcon: InitialsAvatar(e.fullName, size: 22),
            trailingIcon: e.id == request.supervisorId
                ? const Icon(Icons.check_rounded, size: 16)
                : null,
            onPressed: () => _set(context, ref, e.id),
            child: UserText(e.fullName),
          ),
        if (request.supervisorId != null) ...[
          const Divider(),
          MenuItemButton(
            leadingIcon: const Icon(Icons.person_off_outlined, size: 18),
            onPressed: () => _set(context, ref, null),
            child: Text(l.nobodyYet),
          ),
        ],
      ],
      builder: (context, controller, _) => InkWell(
        borderRadius: BorderRadius.circular(Radii.sm),
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: _Person(name: request.supervisorName)),
              const SizedBox(width: 4),
              Icon(Icons.expand_more_rounded,
                  size: 18, color: context.colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _set(BuildContext context, WidgetRef ref, String? id) async {
    if (id == request.supervisorId) return;
    final ok = await runAction(
      context,
      () => ref.read(requestRepositoryProvider).setSupervisor(request.id, id),
      success: context.l10n.supervisorUpdated,
    );
    if (ok) refreshRequest(ref, request.id);
  }
}

// =============================================================================
// Money summary
// =============================================================================

class MoneyPanel extends ConsumerWidget {
  const MoneyPanel({required this.requestId, super.key});

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

          // Nothing agreed yet: the balance is just the negative of what was
          // paid, which would read as nonsense. Say what is actually true.
          if (!f.hasApprovedQuotation) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MoneyLine(label: l.paid, value: Fmt.money(f.paidTotal)),
                const SizedBox(height: Space.sm),
                Text(
                  f.paidTotal > 0 ? l.paidInAdvance : l.noApprovedQuotation,
                  style: context.text.bodySmall,
                ),
              ],
            );
          }

          final settled = f.balance <= 0;
          final ratio = f.approvedTotal == 0
              ? 0.0
              : (f.paidTotal / f.approvedTotal).clamp(0.0, 1.0);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MoneyLine(label: l.approved, value: Fmt.money(f.approvedTotal)),
              const SizedBox(height: 6),
              _MoneyLine(label: l.paid, value: Fmt.money(f.paidTotal)),
              const SizedBox(height: Space.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 6,
                  color: settled ? t.success : t.info,
                ),
              ),
              const SizedBox(height: Space.md),
              _MoneyLine(
                label: l.balance,
                value: Fmt.money(f.balance),
                strong: true,
                colour: settled ? t.success : t.danger,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MoneyLine extends StatelessWidget {
  const _MoneyLine({
    required this.label,
    required this.value,
    this.strong = false,
    this.colour,
  });

  final String label;
  final String value;
  final bool strong;
  final Color? colour;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style:
                  strong ? context.text.titleSmall : context.text.bodyMedium),
        ),
        Text(
          value,
          style: (strong ? context.text.titleMedium : context.text.bodyMedium)
              ?.copyWith(
            color: colour,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Items
// =============================================================================

class ItemsPanel extends ConsumerWidget {
  const ItemsPanel({required this.request, required this.canManage, super.key});

  final RequestSummary request;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final items = ref.watch(requestItemsProvider(request.id));
    final t = context.tokens;

    return SectionCard(
      icon: Icons.inventory_2_outlined,
      title: l.productsTitle,
      child: AsyncView(
        value: items,
        compact: true,
        onRetry: () => ref.invalidate(requestItemsProvider(request.id)),
        builder: (list) {
          if (list.isEmpty) {
            return Text(l.nothingListed, style: context.text.bodySmall);
          }
          return Column(
            children: [
              for (var i = 0; i < list.length; i++) ...[
                if (i > 0) const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Index('${list[i].position}'),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            UserText(list[i].name,
                                style: context.text.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w500)),
                            if (list[i].specs != null)
                              UserText(list[i].specs!,
                                  style: context.text.bodySmall),
                          ],
                        ),
                      ),
                      const SizedBox(width: Space.md),
                      SizedBox(
                        width: 110,
                        child: UserText(list[i].quantityLabel,
                            style: context.text.bodyMedium),
                      ),
                      SizedBox(
                        width: 110,
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: StatusBadge(
                            list[i].status.tr(l),
                            color: t.item(list[i].status),
                          ),
                        ),
                      ),
                      if (canManage)
                        IconButton(
                          tooltip: l.remove,
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 18),
                          onPressed: () => _remove(context, ref, list[i]),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    RequestItem item,
  ) async {
    final l = context.l10n;
    final sure = await confirm(
      context,
      title: l.removeItemTitle(item.name),
      body: l.removeItemBody,
      confirmLabel: l.remove,
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!sure || !context.mounted) return;
    final ok = await runAction(
      context,
      () => ref.read(requestRepositoryProvider).removeItem(item.id),
      success: l.itemRemoved,
    );
    if (ok) refreshRequest(ref, request.id);
  }
}

class _Index extends StatelessWidget {
  const _Index(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.colors.surfaceContainerHigh,
          shape: BoxShape.circle,
        ),
        child: Text(text, style: context.text.labelSmall),
      );
}

// =============================================================================
// Tasks
// =============================================================================

/// The supervisor owns the request; these are the people doing the work.
/// A partner is just another executor.
class TasksPanel extends ConsumerWidget {
  const TasksPanel({required this.request, required this.canManage, super.key});

  final RequestSummary request;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final tasks = ref.watch(requestTasksProvider(request.id));
    final t = context.tokens;

    return SectionCard(
      icon: Icons.handyman_outlined,
      title: l.workTitle,
      actions: [
        if (request.status.isOpen)
          TextButton.icon(
            onPressed: () => _addTask(context, ref),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: Text(canManage ? l.assignWork : l.addMyTask),
          ),
      ],
      child: AsyncView(
        value: tasks,
        compact: true,
        onRetry: () => ref.invalidate(requestTasksProvider(request.id)),
        builder: (list) {
          if (list.isEmpty) {
            return Text(l.nobodyOnThis, style: context.text.bodySmall);
          }
          return Column(
            children: [
              for (var i = 0; i < list.length; i++) ...[
                if (i > 0) const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
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
                            Row(
                              children: [
                                Flexible(
                                  child: UserText(list[i].title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.text.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w500)),
                                ),
                                const SizedBox(width: Space.sm),
                                StatusBadge(list[i].type.tr(l)),
                              ],
                            ),
                            Text(
                              _executor(list[i], l),
                              style: context.text.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: Space.md),
                      SizedBox(
                        width: 120,
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: StatusBadge(list[i].status.tr(l),
                              color: t.task(list[i].status), dot: true),
                        ),
                      ),
                      SizedBox(
                        width: 110,
                        child: Text(
                          list[i].duration != null
                              ? l.took(l.duration(list[i].duration))
                              : (list[i].dueAt != null
                                  ? l.dueOn(Fmt.dayMonth(list[i].dueAt))
                                  : '—'),
                          style: context.text.bodySmall?.copyWith(
                            color: list[i].isOverdue ? t.danger : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  String _executor(TaskSummary t, L10n l) {
    final name = t.assigneeName ?? t.partnerName ?? l.unassigned;
    return t.isExternal ? l.externalName(name) : name;
  }

  Future<void> _addTask(BuildContext context, WidgetRef ref) async {
    final items = ref.read(requestItemsProvider(request.id)).valueOrNull ?? [];
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _TaskDialog(requestId: request.id, items: items),
    );
    if (created ?? false) refreshRequest(ref, request.id);
  }
}

class _TaskDialog extends ConsumerStatefulWidget {
  const _TaskDialog({required this.requestId, required this.items});

  final String requestId;
  final List<RequestItem> items;

  @override
  ConsumerState<_TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends ConsumerState<_TaskDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  TaskType _type = TaskType.design;
  String? _assigneeId;
  String? _partnerId;
  String? _itemId;
  bool _external = false;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final me = ref.watch(currentEmployeeProvider).valueOrNull;
    final canManage = me?.role.canManageRequests ?? false;
    final staff = ref.watch(activeEmployeesProvider).valueOrNull ?? [];
    final partners = ref.watch(partnersProvider).valueOrNull ?? [];

    return AlertDialog(
      title: Text(canManage ? l.assignWork : l.addMyTask),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppField(
                  controller: _title,
                  autofocus: true,
                  label: l.whatNeedsDoing,
                  hint: l.taskTitleHint,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? l.required : null,
                ),
                const SizedBox(height: Space.md),
                DropdownButtonFormField<TaskType>(
                  initialValue: _type,
                  decoration: InputDecoration(labelText: l.kindOfWork),
                  items: [
                    for (final t in TaskType.values)
                      DropdownMenuItem(value: t, child: Text(t.tr(l))),
                  ],
                  onChanged: (t) => setState(() => _type = t ?? _type),
                ),
                if (widget.items.isNotEmpty) ...[
                  const SizedBox(height: Space.md),
                  DropdownButtonFormField<String?>(
                    initialValue: _itemId,
                    decoration: InputDecoration(labelText: l.forWhichProduct),
                    items: [
                      DropdownMenuItem(
                          value: null, child: Text(l.wholeRequest)),
                      for (final i in widget.items)
                        DropdownMenuItem(value: i.id, child: UserText(i.name)),
                    ],
                    onChanged: (v) => setState(() => _itemId = v),
                  ),
                ],
                if (canManage) ...[
                  const SizedBox(height: Space.sm),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.externalPartner),
                    value: _external,
                    onChanged: (v) => setState(() {
                      _external = v;
                      _assigneeId = null;
                      _partnerId = null;
                      if (v) _type = TaskType.external;
                    }),
                  ),
                  if (_external)
                    DropdownButtonFormField<String>(
                      initialValue: _partnerId,
                      decoration: InputDecoration(labelText: l.partner),
                      items: [
                        for (final p in partners)
                          DropdownMenuItem(
                              value: p.id, child: UserText(p.name)),
                      ],
                      onChanged: (v) => setState(() => _partnerId = v),
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: _assigneeId,
                      decoration: InputDecoration(labelText: l.who),
                      items: [
                        for (final e in staff)
                          DropdownMenuItem(
                            value: e.id,
                            child: Text('${e.fullName} · ${e.role.tr(l)}'),
                          ),
                      ],
                      onChanged: (v) => setState(() => _assigneeId = v),
                    ),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(top: Space.md),
                    child: Text(l.assignedToYou, style: context.text.bodySmall),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: _busy ? null : () => _save(me),
          child: Text(l.add),
        ),
      ],
    );
  }

  Future<void> _save(Employee? me) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    final canManage = me?.role.canManageRequests ?? false;
    final ok = await runAction(
      context,
      () => ref.read(taskRepositoryProvider).create(
            requestId: widget.requestId,
            type: _type,
            title: _title.text,
            requestItemId: _itemId,
            // A non-supervisor may only create work for themselves, which is
            // also what the database allows.
            assigneeId: canManage ? (_external ? null : _assigneeId) : me?.id,
            partnerId: canManage && _external ? _partnerId : null,
          ),
      success: context.l10n.workAdded,
    );
    if (mounted) {
      setState(() => _busy = false);
      if (ok) Navigator.pop(context, true);
    }
  }
}
