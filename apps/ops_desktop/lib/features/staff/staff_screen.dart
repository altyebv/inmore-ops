import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inmore_core/inmore_core.dart';
import 'package:inmore_ui/inmore_ui.dart';

/// Who can sign in, and as what. Owner and supervisors.
///
/// The rules live in the database (migration 013): a supervisor manages
/// everyone except the owner, nobody changes their own role or access.
/// Creating an account, resetting a password and deleting a never-used
/// account go through the staff-admin Edge Function. "Removing" someone
/// switches their access off and keeps their name on the history.
class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final me = ref.watch(currentEmployeeProvider).valueOrNull;
    final staff = ref.watch(allStaffProvider);

    return Column(
      children: [
        PageHeader(
          title: l.staffTitle,
          subtitle: l.staffSubtitle,
          actions: [
            FilledButton.icon(
              onPressed: () => _add(context, ref, me),
              icon: const Icon(Icons.person_add_alt_rounded, size: 18),
              label: Text(l.addStaff),
            ),
          ],
        ),
        Expanded(
          child: AsyncView(
            value: staff,
            onRetry: () => ref.invalidate(allStaffProvider),
            builder: (people) => ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 32),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Card(
                        child: Column(
                          children: [
                            for (var i = 0; i < people.length; i++) ...[
                              if (i > 0) const Divider(),
                              _StaffRow(person: people[i], me: me),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: Space.lg),
                    const Expanded(child: _RoleGuide()),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref, Employee? me) async {
    final created = await showDialog<(String, String, String)>(
      context: context,
      builder: (_) =>
          _AddStaffDialog(ownerMayBeChosen: me?.role == EmployeeRole.owner),
    );
    if (created == null || !context.mounted) return;
    ref
      ..invalidate(allStaffProvider)
      ..invalidate(activeEmployeesProvider);
    final (name, email, password) = created;
    await _showCredentials(context,
        title: context.l10n.accountReadyTitle,
        body: context.l10n.accountReadyBody(name),
        email: email,
        password: password);
  }
}

class _StaffRow extends ConsumerWidget {
  const _StaffRow({required this.person, required this.me});

  final Employee person;
  final Employee? me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = context.tokens;
    final p = person;
    final isMe = p.id == me?.id;
    // Mirrors employees_update / trg_employees_restrict_role.
    final ownerLocked =
        p.role == EmployeeRole.owner && me?.role != EmployeeRole.owner;
    final muted = context.text.bodySmall;

    return Opacity(
      opacity: p.isActive ? 1 : 0.6,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 12),
        child: Row(
          children: [
            InitialsAvatar(p.fullName, size: 36),
            const SizedBox(width: Space.md),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: UserText(p.fullName,
                            style: context.text.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w500)),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: Space.sm),
                        StatusBadge(l.you, color: t.info),
                      ],
                    ],
                  ),
                  Text(p.email,
                      textDirection: TextDirection.ltr,
                      overflow: TextOverflow.ellipsis,
                      style: muted),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(p.phone ?? '—',
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.start,
                  style: muted),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: StatusBadge(p.role.tr(l),
                    color: p.role == EmployeeRole.owner ? t.cmykKey : null),
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: StatusBadge(
                  p.isActive ? l.activeStatus : l.noAccess,
                  color: p.isActive ? t.success : t.neutral,
                  dot: true,
                ),
              ),
            ),
            SizedBox(
              width: 48,
              child: ownerLocked
                  ? Tooltip(
                      message: l.ownerAccountLocked,
                      child: Icon(Icons.lock_outline_rounded,
                          size: 18, color: context.colors.onSurfaceVariant),
                    )
                  : _StaffMenu(person: p, isMe: isMe, me: me),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffMenu extends ConsumerWidget {
  const _StaffMenu(
      {required this.person, required this.isMe, required this.me});

  final Employee person;
  final bool isMe;
  final Employee? me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = person;
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.edit_outlined, size: 18),
          onPressed: () => _edit(context, ref),
          child: Text(l.edit),
        ),
        if (!isMe) ...[
          MenuItemButton(
            leadingIcon: const Icon(Icons.key_rounded, size: 18),
            onPressed: () => _resetPassword(context, ref),
            child: Text(l.resetPassword),
          ),
          const Divider(),
          MenuItemButton(
            leadingIcon: Icon(
                p.isActive
                    ? Icons.person_off_outlined
                    : Icons.person_outline_rounded,
                size: 18),
            onPressed: () => _toggleAccess(context, ref),
            child: Text(p.isActive ? l.removeAccess : l.restoreAccess),
          ),
          MenuItemButton(
            leadingIcon: Icon(Icons.delete_outline_rounded,
                size: 18, color: context.colors.error),
            onPressed: () => _delete(context, ref),
            child: Text(l.deleteAccount,
                style: TextStyle(color: context.colors.error)),
          ),
        ],
      ],
      builder: (context, controller, _) => IconButton(
        tooltip: l.moreActions,
        icon: const Icon(Icons.more_vert_rounded, size: 18),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }

  void _refresh(WidgetRef ref) => ref
    ..invalidate(allStaffProvider)
    ..invalidate(activeEmployeesProvider);

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _EditStaffDialog(
        person: person,
        canChangeRole: !isMe,
        ownerMayBeChosen: me?.role == EmployeeRole.owner,
      ),
    );
    if (saved == true && context.mounted) {
      showDone(context, context.l10n.staffSaved);
      _refresh(ref);
    }
  }

  Future<void> _toggleAccess(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    if (person.isActive) {
      final sure = await confirm(
        context,
        title: l.removeAccessTitle(person.fullName),
        body: l.removeAccessBody,
        confirmLabel: l.removeAccess,
        destructive: true,
        icon: Icons.person_off_outlined,
      );
      if (!sure || !context.mounted) return;
    }
    final ok = await runAction(
      context,
      () => ref
          .read(staffRepositoryProvider)
          .setActive(person.id, !person.isActive),
      success: person.isActive ? l.accessRemoved : l.accessRestored,
    );
    if (ok) _refresh(ref);
  }

  Future<void> _resetPassword(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final sure = await confirm(
      context,
      title: l.resetPasswordTitle(person.fullName),
      body: l.resetPasswordBody,
      confirmLabel: l.resetPassword,
      icon: Icons.key_rounded,
    );
    if (!sure || !context.mounted) return;
    final password = generatePassword();
    final ok = await runAction(
      context,
      () => ref.read(staffRepositoryProvider).setPassword(person.id, password),
    );
    if (ok && context.mounted) {
      await _showCredentials(context,
          title: l.passwordResetTitle(person.fullName),
          email: person.email,
          password: password);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final sure = await confirm(
      context,
      title: l.deleteAccountTitle(person.fullName),
      body: l.deleteAccountBody,
      confirmLabel: l.deleteAccount,
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!sure || !context.mounted) return;
    final ok = await runAction(
      context,
      () => ref.read(staffRepositoryProvider).delete(person.id),
      success: l.accountDeleted,
    );
    if (ok) _refresh(ref);
  }
}

class _RoleGuide extends StatelessWidget {
  const _RoleGuide();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final rows = [
      (EmployeeRole.owner, l.roleOwnerHint),
      (EmployeeRole.supervisor, l.roleSupervisorHint),
      (EmployeeRole.designer, l.roleDesignerHint),
      (EmployeeRole.production, l.roleProductionHint),
    ];
    return SectionCard(
      icon: Icons.badge_outlined,
      title: l.whatEachRoleCan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (role, hint) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(role.tr(l),
                      style: context.text.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  Text(hint, style: context.text.bodySmall),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Readable and safe enough to read out over the phone: no 0/O or 1/l.
String generatePassword() {
  const letters = 'abcdefghjkmnpqrstuvwxyz';
  const digits = '23456789';
  final r = Random.secure();
  String pick(String s, int n) =>
      List.generate(n, (_) => s[r.nextInt(s.length)]).join();
  return 'Inmore-${pick(letters, 4)}-${pick(digits, 4)}';
}

Future<void> _showCredentials(
  BuildContext context, {
  required String title,
  required String email,
  required String password,
  String? body,
}) =>
    showDialog<void>(
      context: context,
      builder: (context) {
        final l = context.l10n;
        Widget line(String label, String value) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                      width: 140,
                      child: Text(label, style: context.text.bodySmall)),
                  Expanded(
                    child: SelectableText(value,
                        textDirection: TextDirection.ltr,
                        style: context.text.titleSmall
                            ?.copyWith(fontFamily: 'monospace')),
                  ),
                  IconButton(
                    tooltip: l.copy,
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: value));
                      showDone(context, l.copied);
                    },
                  ),
                ],
              ),
            );
        return AlertDialog(
          icon:
              Icon(Icons.verified_user_outlined, color: context.tokens.success),
          title: Text(title),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (body != null) ...[
                  Text(body, style: context.text.bodyMedium),
                  const SizedBox(height: Space.md),
                ],
                line(l.email, email),
                line(l.temporaryPassword, password),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l.close),
            ),
          ],
        );
      },
    );

class _AddStaffDialog extends ConsumerStatefulWidget {
  const _AddStaffDialog({required this.ownerMayBeChosen});

  final bool ownerMayBeChosen;

  @override
  ConsumerState<_AddStaffDialog> createState() => _AddStaffDialogState();
}

class _AddStaffDialogState extends ConsumerState<_AddStaffDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  late final _password = TextEditingController(text: generatePassword());
  EmployeeRole _role = EmployeeRole.designer;
  var _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.addStaff),
      content: SizedBox(
        width: 480,
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
              AppField(
                controller: _email,
                label: l.fieldEmail,
                keyboardType: TextInputType.emailAddress,
                fixedDirection: TextDirection.ltr,
                validator: (v) => (v == null ||
                        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch(v.trim()))
                    ? l.enterEmail
                    : null,
              ),
              const SizedBox(height: Space.md),
              Row(
                children: [
                  Expanded(
                    child: AppField(
                      controller: _phone,
                      label: '${l.fieldPhone} (${l.optional})',
                      keyboardType: TextInputType.phone,
                      fixedDirection: TextDirection.ltr,
                    ),
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: _RolePicker(
                      value: _role,
                      ownerMayBeChosen: widget.ownerMayBeChosen,
                      onChanged: (r) => setState(() => _role = r),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.md),
              AppField(
                controller: _password,
                label: l.temporaryPassword,
                helper: l.passwordMin,
                fixedDirection: TextDirection.ltr,
                suffix: IconButton(
                  tooltip: l.newPasswordButton,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  onPressed: () =>
                      setState(() => _password.text = generatePassword()),
                ),
                validator: (v) =>
                    (v == null || v.length < 8) ? l.passwordMin : null,
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
          child: Text(l.create),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    final ok = await runAction(
      context,
      () => ref.read(staffRepositoryProvider).create(
            email: _email.text,
            password: _password.text,
            fullName: _name.text,
            role: _role,
            phone: _phone.text,
          ),
      success: context.l10n.accountCreated,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      Navigator.pop(context, (
        _name.text.trim(),
        _email.text.trim().toLowerCase(),
        _password.text
      ));
    }
  }
}

class _EditStaffDialog extends ConsumerStatefulWidget {
  const _EditStaffDialog({
    required this.person,
    required this.canChangeRole,
    required this.ownerMayBeChosen,
  });

  final Employee person;
  final bool canChangeRole;
  final bool ownerMayBeChosen;

  @override
  ConsumerState<_EditStaffDialog> createState() => _EditStaffDialogState();
}

class _EditStaffDialogState extends ConsumerState<_EditStaffDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.person.fullName);
  late final _phone = TextEditingController(text: widget.person.phone);
  late EmployeeRole _role = widget.person.role;
  var _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.editStaff(widget.person.fullName)),
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
              AppField(
                controller: _phone,
                label: '${l.fieldPhone} (${l.optional})',
                keyboardType: TextInputType.phone,
                fixedDirection: TextDirection.ltr,
              ),
              if (widget.canChangeRole) ...[
                const SizedBox(height: Space.md),
                _RolePicker(
                  value: _role,
                  ownerMayBeChosen: widget.ownerMayBeChosen,
                  onChanged: (r) => setState(() => _role = r),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(onPressed: _busy ? null : _save, child: Text(l.save)),
      ],
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await ref.read(staffRepositoryProvider).updateProfile(
            widget.person.id,
            fullName: _name.text,
            phone: _phone.text,
            role: widget.canChangeRole && _role != widget.person.role
                ? _role
                : null,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _RolePicker extends StatelessWidget {
  const _RolePicker({
    required this.value,
    required this.ownerMayBeChosen,
    required this.onChanged,
  });

  final EmployeeRole value;
  final bool ownerMayBeChosen;
  final ValueChanged<EmployeeRole> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return DropdownButtonFormField<EmployeeRole>(
      isExpanded: true,
      initialValue: value,
      decoration: InputDecoration(labelText: l.fieldRole),
      items: [
        for (final r in EmployeeRole.values)
          if (r != EmployeeRole.owner || ownerMayBeChosen || value == r)
            DropdownMenuItem(value: r, child: Text(r.tr(l))),
      ],
      onChanged: (r) => onChanged(r ?? value),
    );
  }
}
