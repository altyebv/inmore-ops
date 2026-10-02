part of 'panels.dart';

/// The partner list, with a way to add one on the spot — a hosted project
/// starts with none, and the first external job is when someone needs one.
class _PartnerPicker extends ConsumerWidget {
  const _PartnerPicker({
    required this.partners,
    required this.value,
    required this.onChanged,
  });

  final List<Partner> partners;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            // Keyed on the list, so a partner added a moment ago can be the
            // selected value.
            key: ValueKey('${partners.length}/$value'),
            initialValue: partners.any((p) => p.id == value) ? value : null,
            decoration: InputDecoration(labelText: l.partner),
            items: [
              for (final p in partners)
                DropdownMenuItem(value: p.id, child: UserText(p.name)),
            ],
            validator: (v) => v == null ? l.required : null,
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: Space.sm),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: IconButton.outlined(
            tooltip: l.newPartner,
            icon: const Icon(Icons.add_business_outlined, size: 20),
            onPressed: () async {
              final created = await showDialog<Partner>(
                context: context,
                builder: (_) => const _PartnerDialog(),
              );
              if (created == null) return;
              ref.invalidate(partnersProvider);
              await ref.read(partnersProvider.future);
              onChanged(created.id);
            },
          ),
        ),
      ],
    );
  }
}

class _PartnerDialog extends ConsumerStatefulWidget {
  const _PartnerDialog();

  @override
  ConsumerState<_PartnerDialog> createState() => _PartnerDialogState();
}

class _PartnerDialogState extends ConsumerState<_PartnerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _contact = TextEditingController();
  final _phone = TextEditingController();
  final _services = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    _phone.dispose();
    _services.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.newPartner),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppField(
                controller: _name,
                autofocus: true,
                label: l.fieldName,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? l.required : null,
              ),
              const SizedBox(height: Space.md),
              AppField(controller: _contact, label: l.fieldContact),
              const SizedBox(height: Space.md),
              AppField(
                controller: _phone,
                label: l.fieldPhone,
                keyboardType: TextInputType.phone,
                fixedDirection: TextDirection.ltr,
              ),
              const SizedBox(height: Space.md),
              AppField(controller: _services, label: l.fieldServices),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(l.save),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    String? blank(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    try {
      final partner = await ref.read(catalogRepositoryProvider).createPartner(
            name: _name.text,
            contactName: blank(_contact),
            phone: blank(_phone),
            services: blank(_services),
          );
      if (mounted) {
        showDone(context, context.l10n.partnerAdded);
        Navigator.pop(context, partner);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// What a supervisor can do to one piece of work: move it along (the only
/// way an external partner's job ever gets marked done), give it to someone
/// else, record what a partner charged, or call it off.
class _TaskMenu extends ConsumerWidget {
  const _TaskMenu({required this.task});

  final TaskSummary task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final canSeeMoney =
        ref.watch(currentEmployeeProvider).valueOrNull?.role.canSeeMoney ??
            false;

    return MenuAnchor(
      menuChildren: [
        for (final s in const [
          TaskStatus.todo,
          TaskStatus.inProgress,
          TaskStatus.blocked,
          TaskStatus.done,
        ])
          if (s != task.status)
            MenuItemButton(
              leadingIcon:
                  Icon(Icons.circle, size: 10, color: context.tokens.task(s)),
              onPressed: () => _set(context, ref, s),
              child: Text(s.tr(l)),
            ),
        const Divider(),
        MenuItemButton(
          leadingIcon: const Icon(Icons.swap_horiz_rounded, size: 18),
          onPressed: () => _reassign(context, ref),
          child: Text(l.reassign),
        ),
        if (task.isExternal && canSeeMoney)
          MenuItemButton(
            leadingIcon: const Icon(Icons.receipt_outlined, size: 18),
            onPressed: () => _cost(context, ref),
            child: Text(l.recordCost),
          ),
        const Divider(),
        MenuItemButton(
          leadingIcon:
              Icon(Icons.block_rounded, size: 18, color: context.colors.error),
          onPressed: () => _cancel(context, ref),
          child:
              Text(l.cancelTask, style: TextStyle(color: context.colors.error)),
        ),
      ],
      builder: (context, controller, _) => IconButton(
        tooltip: l.moreActions,
        icon: const Icon(Icons.more_vert_rounded, size: 18),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }

  Future<void> _set(BuildContext context, WidgetRef ref, TaskStatus s) async {
    final l = context.l10n;
    final ok = await runAction(
      context,
      () => ref.read(taskRepositoryProvider).setStatus(task.id, s),
      success: l.markedStatus(s.tr(l)),
    );
    if (ok) _refresh(ref);
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final sure = await confirm(
      context,
      title: l.cancelTaskTitle(task.title),
      body: l.cancelTaskBody,
      confirmLabel: l.cancelTask,
      cancelLabel: l.keepIt,
      destructive: true,
      icon: Icons.block_rounded,
    );
    if (sure && context.mounted) {
      await _set(context, ref, TaskStatus.cancelled);
    }
  }

  Future<void> _reassign(BuildContext context, WidgetRef ref) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _ReassignDialog(task: task),
    );
    if ((changed ?? false) && context.mounted) {
      showDone(context, context.l10n.taskUpdated);
      _refresh(ref);
    }
  }

  Future<void> _cost(BuildContext context, WidgetRef ref) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _CostDialog(task: task),
    );
    if ((saved ?? false) && context.mounted) {
      showDone(context, context.l10n.costRecorded);
      _refresh(ref);
    }
  }

  void _refresh(WidgetRef ref) {
    refreshRequest(ref, task.requestId);
    ref.invalidate(myWorkProvider);
  }
}

class _ReassignDialog extends ConsumerStatefulWidget {
  const _ReassignDialog({required this.task});

  final TaskSummary task;

  @override
  ConsumerState<_ReassignDialog> createState() => _ReassignDialogState();
}

class _ReassignDialogState extends ConsumerState<_ReassignDialog> {
  final _formKey = GlobalKey<FormState>();
  late bool _external = widget.task.isExternal;
  late String? _assigneeId = widget.task.assigneeId;
  late String? _partnerId = widget.task.partnerId;
  var _busy = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final staff = ref.watch(activeEmployeesProvider).valueOrNull ?? [];
    final partners = ref.watch(partnersProvider).valueOrNull ?? [];
    return AlertDialog(
      title: Text(l.reassignTitle(widget.task.title)),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.externalPartner),
                value: _external,
                onChanged: (v) => setState(() => _external = v),
              ),
              if (_external)
                _PartnerPicker(
                  partners: partners,
                  value: _partnerId,
                  onChanged: (v) => setState(() => _partnerId = v),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: staff.any((e) => e.id == _assigneeId)
                      ? _assigneeId
                      : null,
                  decoration: InputDecoration(labelText: l.who),
                  items: [
                    for (final e in staff)
                      DropdownMenuItem(
                        value: e.id,
                        child: Text('${e.fullName} · ${e.role.tr(l)}'),
                      ),
                  ],
                  validator: (v) => v == null ? l.required : null,
                  onChanged: (v) => setState(() => _assigneeId = v),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(l.save),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      // One executor at a time: the database refuses both.
      await ref.read(taskRepositoryProvider).assign(
            widget.task.id,
            employeeId: _external ? null : _assigneeId,
            partnerId: _external ? _partnerId : null,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// What an external partner charged. Kept apart from the task so designers and
/// production never see it; one figure per task, replaced if recorded again.
class _CostDialog extends ConsumerStatefulWidget {
  const _CostDialog({required this.task});

  final TaskSummary task;

  @override
  ConsumerState<_CostDialog> createState() => _CostDialogState();
}

class _CostDialogState extends ConsumerState<_CostDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  var _busy = false;

  @override
  void initState() {
    super.initState();
    // Recording again replaces the figure, so start from the current one.
    ref.read(taskRepositoryProvider).cost(widget.task.id).then((v) {
      if (mounted && v != null && _amount.text.isEmpty) {
        _amount.text =
            v == v.roundToDouble() ? v.toInt().toString() : v.toString();
      }
    }).ignore();
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.costTitle(widget.task.partnerName ?? l.partner)),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: AppField(
            controller: _amount,
            autofocus: true,
            label: l.amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            fixedDirection: TextDirection.ltr,
            validator: (v) {
              final a = double.tryParse(v ?? '');
              return (a == null || a < 0) ? l.enterAmount : null;
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(l.record),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(taskRepositoryProvider)
          .recordCost(widget.task.id, double.parse(_amount.text));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
