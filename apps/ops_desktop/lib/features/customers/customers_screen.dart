import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inmore_core/inmore_core.dart';
import 'package:inmore_ui/inmore_ui.dart';

final _queryProvider = StateProvider<String>((ref) => '');

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  late final _search = TextEditingController(text: ref.read(_queryProvider));
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      ref.read(_queryProvider.notifier).state = v;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final query = ref.watch(_queryProvider);
    final results = ref.watch(customerSearchProvider(query));
    final me = ref.watch(currentEmployeeProvider).valueOrNull;
    // Mirrors customers_insert / customers_update: designers may add a
    // customer (they create requests too), only supervisors and the owner
    // may change one.
    final canAdd = me != null && me.role != EmployeeRole.production;
    final canEdit = me != null && me.role.canManageRequests;

    return Column(
      children: [
        PageHeader(
          title: l.customersTitle,
          subtitle: l.customersSubtitle,
          actions: [
            if (canAdd)
              FilledButton.icon(
                onPressed: () => showCustomerDialog(context),
                icon: const Icon(Icons.person_add_alt_rounded, size: 18),
                label: Text(l.newCustomer),
              ),
          ],
          bottom: Align(
            alignment: AlignmentDirectional.centerStart,
            child: SizedBox(
              width: 520,
              child: TextField(
                controller: _search,
                autofocus: true,
                onChanged: _onChanged,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  hintText: l.customerSearchHint,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: AsyncView(
            value: results,
            onRetry: () => ref.invalidate(customerSearchProvider(query)),
            builder: (customers) {
              if (customers.isEmpty) {
                return EmptyState(
                  icon: Icons.person_search_outlined,
                  title: l.noCustomersFound,
                  body: l.noCustomersFoundBody,
                  action: canAdd
                      ? OutlinedButton.icon(
                          onPressed: () => showCustomerDialog(context),
                          icon: const Icon(Icons.person_add_alt_rounded,
                              size: 18),
                          label: Text(l.newCustomer),
                        )
                      : null,
                );
              }
              return ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 32),
                children: [
                  Card(
                    child: Column(
                      children: [
                        for (var i = 0; i < customers.length; i++) ...[
                          if (i > 0) const Divider(),
                          _CustomerRow(
                            customer: customers[i],
                            canEdit: canEdit,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CustomerRow extends StatelessWidget {
  const _CustomerRow({required this.customer, required this.canEdit});

  final Customer customer;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = customer;
    final muted = context.text.bodySmall;

    return InkWell(
      onTap: canEdit
          ? () => showCustomerDialog(context, existing: customer)
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 12),
        child: Row(
          children: [
            InitialsAvatar(c.name, size: 36),
            const SizedBox(width: Space.md),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UserText(c.name,
                      style: context.text.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w500)),
                  if (c.company != null && c.company!.isNotEmpty)
                    UserText(c.company!, style: muted),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: c.phone == null || c.phone!.isEmpty
                  ? Text('—', style: muted)
                  : Row(
                      children: [
                        Icon(Icons.phone_outlined,
                            size: 14, color: context.colors.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text(c.phone!,
                            textDirection: TextDirection.ltr,
                            style: context.text.bodyMedium),
                      ],
                    ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                c.email ?? '',
                overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.ltr,
                style: muted,
              ),
            ),
            if (canEdit)
              IconButton(
                tooltip: l.editCustomer,
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: () => showCustomerDialog(context, existing: c),
              ),
          ],
        ),
      ),
    );
  }
}

Future<Customer?> showCustomerDialog(
  BuildContext context, {
  Customer? existing,
}) =>
    showDialog<Customer>(
      context: context,
      builder: (_) => _CustomerDialog(existing: existing),
    );

class _CustomerDialog extends ConsumerStatefulWidget {
  const _CustomerDialog({this.existing});

  final Customer? existing;

  @override
  ConsumerState<_CustomerDialog> createState() => _CustomerDialogState();
}

class _CustomerDialogState extends ConsumerState<_CustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _phone = TextEditingController(text: widget.existing?.phone);
  late final _company = TextEditingController(text: widget.existing?.company);
  late final _email = TextEditingController(text: widget.existing?.email);
  late final _notes = TextEditingController(text: widget.existing?.notes);

  late String _phoneValue = widget.existing?.phone ?? '';
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _company.dispose();
    _email.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isEdit = widget.existing != null;

    return AlertDialog(
      title: Text(isEdit ? l.editCustomer : l.newCustomer),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                  label: l.fieldPhone,
                  keyboardType: TextInputType.phone,
                  fixedDirection: TextDirection.ltr,
                  onChanged: (v) => setState(() => _phoneValue = v),
                ),
                _DuplicateWarning(
                  phone: _phoneValue,
                  excludeId: widget.existing?.id,
                ),
                const SizedBox(height: Space.md),
                AppField(controller: _company, label: l.fieldCompany),
                const SizedBox(height: Space.md),
                AppField(
                  controller: _email,
                  label: l.fieldEmail,
                  keyboardType: TextInputType.emailAddress,
                  fixedDirection: TextDirection.ltr,
                ),
                const SizedBox(height: Space.md),
                AppField(controller: _notes, label: l.fieldNotes, maxLines: 3),
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
          onPressed: _busy ? null : _save,
          child: Text(isEdit ? l.save : l.create),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    final repo = ref.read(customerRepositoryProvider);
    try {
      final saved = widget.existing == null
          ? await repo.create(
              name: _name.text,
              phone: _phone.text,
              company: _company.text,
              email: _email.text,
              notes: _notes.text,
            )
          : await repo.update(
              widget.existing!.id,
              name: _name.text,
              phone: _phone.text,
              company: _company.text,
              email: _email.text,
              notes: _notes.text,
            );
      ref.invalidate(customerSearchProvider);
      if (mounted) {
        showDone(context, context.l10n.customerSaved);
        Navigator.pop(context, saved);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// Warns, never blocks. Shared numbers are real — a company switchboard, a
/// family business — so this is information, not a validation error.
class _DuplicateWarning extends ConsumerWidget {
  const _DuplicateWarning({required this.phone, this.excludeId});

  final String phone;
  final String? excludeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (phone.trim().length < 6) return const SizedBox.shrink();

    final dupes = ref.watch(duplicatePhoneProvider(phone));
    return dupes.maybeWhen(
      data: (list) {
        final others =
            list.where((c) => c.id != excludeId).toList(growable: false);
        if (others.isEmpty) return const SizedBox.shrink();
        final warning = context.tokens.warning;
        return Container(
          margin: const EdgeInsets.only(top: Space.sm),
          padding: const EdgeInsets.all(Space.md),
          decoration: BoxDecoration(
            color: warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: warning),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  context.l10n.duplicatePhone(
                    others.length,
                    others.map((c) => c.displayLine).join(
                          Localizations.localeOf(context).languageCode == 'ar'
                              ? '، '
                              : '; ',
                        ),
                  ),
                  style: context.text.bodySmall
                      ?.copyWith(color: context.colors.onSurface),
                ),
              ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
