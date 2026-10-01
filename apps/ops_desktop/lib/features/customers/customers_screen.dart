import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inmore_core/inmore_core.dart';

import '../../widgets/common.dart';

final _queryProvider = StateProvider<String>((ref) => '');

class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(_queryProvider);
    final results = ref.watch(customerSearchProvider(query));
    final me = ref.watch(currentEmployeeProvider).valueOrNull;
    final canAdd = me != null && me.role != EmployeeRole.production;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        actions: [
          if (canAdd)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                onPressed: () => showCustomerDialog(context, ref),
                icon: const Icon(Icons.person_add_alt, size: 18),
                label: const Text('New customer'),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 18),
                hintText: 'Name, company, or phone in any format',
                helperText:
                    'Phone matching ignores spaces, dashes and the +974 prefix.',
              ),
              onChanged: (v) => ref.read(_queryProvider.notifier).state = v,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: AsyncView(
              value: results,
              builder: (customers) {
                if (customers.isEmpty) {
                  return const Center(child: EmptyNote('No customers found.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: customers.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final c = customers[i];
                    return ListTile(
                      title: Text(c.name),
                      subtitle: Text([
                        if (c.company != null && c.company!.isNotEmpty)
                          c.company!,
                        if (c.phone != null && c.phone!.isNotEmpty) c.phone!,
                        if (c.email != null && c.email!.isNotEmpty) c.email!,
                      ].join('  ·  ')),
                      trailing: canAdd
                          ? IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () =>
                                  showCustomerDialog(context, ref, existing: c),
                            )
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

Future<Customer?> showCustomerDialog(
  BuildContext context,
  WidgetRef ref, {
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
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name);
  late final TextEditingController _phone =
      TextEditingController(text: widget.existing?.phone);
  late final TextEditingController _company =
      TextEditingController(text: widget.existing?.company);
  late final TextEditingController _email =
      TextEditingController(text: widget.existing?.email);
  late final TextEditingController _notes =
      TextEditingController(text: widget.existing?.notes);

  String _phoneValue = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _phoneValue = widget.existing?.phone ?? '';
  }

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
    final isEdit = widget.existing != null;

    return AlertDialog(
      title: Text(isEdit ? 'Edit customer' : 'New customer'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  onChanged: (v) => setState(() => _phoneValue = v),
                ),
                _DuplicateWarning(
                  phone: _phoneValue,
                  excludeId: widget.existing?.id,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _company,
                  decoration: const InputDecoration(labelText: 'Company'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notes,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(isEdit ? 'Save' : 'Create'),
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
      if (mounted) Navigator.pop(context, saved);
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
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 16, color: Colors.orange),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${others.length} customer'
                  '${others.length == 1 ? '' : 's'} already on this number: '
                  '${others.map((c) => c.displayLine).join('; ')}',
                  style: Theme.of(context).textTheme.bodySmall,
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
