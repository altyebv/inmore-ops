import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inmore_core/inmore_core.dart';

import '../../widgets/common.dart';
import '../customers/customers_screen.dart';

/// Create a request and its items in one go.
///
/// The whole form is one database call, so a failure cannot leave an empty
/// request behind — which is the kind of junk row that makes people stop
/// trusting the list.
class NewRequestScreen extends ConsumerStatefulWidget {
  const NewRequestScreen({super.key});

  @override
  ConsumerState<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends ConsumerState<NewRequestScreen> {
  Customer? _customer;
  final _title = TextEditingController();
  final _notes = TextEditingController();
  DateTime? _neededBy;
  final List<NewRequestItem> _items = [];
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('New request'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/'),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              SectionCard(
                title: 'Customer',
                actions: [
                  TextButton.icon(
                    onPressed: () async {
                      final created = await showCustomerDialog(context, ref);
                      if (created != null) {
                        setState(() => _customer = created);
                      }
                    },
                    icon: const Icon(Icons.person_add_alt, size: 16),
                    label: const Text('New'),
                  ),
                ],
                child: _CustomerPicker(
                  selected: _customer,
                  onSelected: (c) => setState(() => _customer = c),
                ),
              ),
              SectionCard(
                title: 'Request',
                child: Column(
                  children: [
                    TextField(
                      controller: _title,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        hintText: 'Cafe opening pack',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _pickDate,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Needed by',
                              ),
                              child: Text(_neededBy == null
                                  ? 'Not set'
                                  : Fmt.date(_neededBy)),
                            ),
                          ),
                        ),
                        if (_neededBy != null)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() => _neededBy = null),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notes,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        hintText: 'What the customer actually said',
                      ),
                    ),
                  ],
                ),
              ),
              SectionCard(
                title: 'Products',
                subtitle:
                    'A request can hold as many as the customer asked for',
                actions: [
                  TextButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add product'),
                  ),
                ],
                child: _items.isEmpty
                    ? const EmptyNote(
                        'No products yet. A request can be saved without them — '
                        'knowing what was asked for matters even when the detail '
                        'comes later.')
                    : Column(
                        children: [
                          for (var i = 0; i < _items.length; i++)
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                radius: 12,
                                child: Text('${i + 1}',
                                    style: theme.textTheme.labelSmall),
                              ),
                              title: Text(_items[i].name),
                              subtitle: Text([
                                Fmt.qty(_items[i].quantity),
                                if (_items[i].unit != null) _items[i].unit!,
                                if (_items[i].specs != null) _items[i].specs!,
                              ].join('  ·  ')),
                              trailing: IconButton(
                                icon:
                                    const Icon(Icons.delete_outline, size: 18),
                                onPressed: () =>
                                    setState(() => _items.removeAt(i)),
                              ),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _busy ? null : () => context.go('/'),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: (_customer == null || _busy) ? null : _save,
                    child: const Text('Create request'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _neededBy ?? now.add(const Duration(days: 7)),
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _neededBy = picked);
  }

  Future<void> _addItem() async {
    final item = await showDialog<NewRequestItem>(
      context: context,
      builder: (_) => const _ItemDialog(),
    );
    if (item != null) setState(() => _items.add(item));
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final created = await ref.read(requestRepositoryProvider).create(
            customerId: _customer!.id,
            title: _title.text,
            notes: _notes.text,
            neededBy: _neededBy,
            items: _items,
          );
      ref.invalidate(boardProvider);
      if (mounted) {
        showDone(context, 'Request #${created.number} created');
        context.go('/requests/${created.id}');
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _CustomerPicker extends ConsumerStatefulWidget {
  const _CustomerPicker({required this.selected, required this.onSelected});

  final Customer? selected;
  final ValueChanged<Customer> onSelected;

  @override
  ConsumerState<_CustomerPicker> createState() => _CustomerPickerState();
}

class _CustomerPickerState extends ConsumerState<_CustomerPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    if (widget.selected != null) {
      final c = widget.selected!;
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.person_outline),
        title: Text(c.name),
        subtitle: Text([
          if (c.company != null) c.company!,
          if (c.phone != null) c.phone!,
        ].join('  ·  ')),
        trailing: TextButton(
          onPressed: () => setState(() => _query = ''),
          child: const Text('Change'),
        ),
        onTap: () => setState(() => _query = ''),
      );
    }

    final results = ref.watch(customerSearchProvider(_query));
    return Column(
      children: [
        TextField(
          autofocus: true,
          decoration: const InputDecoration(
            isDense: true,
            prefixIcon: Icon(Icons.search, size: 18),
            hintText: 'Find a customer by name, company or phone',
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          child: AsyncView(
            value: results,
            builder: (list) => list.isEmpty
                ? const EmptyNote('No match. Create the customer first.')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: list.length,
                    itemBuilder: (context, i) => ListTile(
                      dense: true,
                      title: Text(list[i].displayLine),
                      subtitle:
                          list[i].phone == null ? null : Text(list[i].phone!),
                      onTap: () => widget.onSelected(list[i]),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

/// Catalog product or free text — the catalog exists to make the common cases
/// countable later, not to stop anyone entering "500 custom printed boxes".
class _ItemDialog extends ConsumerStatefulWidget {
  const _ItemDialog();

  @override
  ConsumerState<_ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends ConsumerState<_ItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _unit = TextEditingController();
  final _specs = TextEditingController();
  Product? _product;

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _unit.dispose();
    _specs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);

    return AlertDialog(
      title: const Text('Add product'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                products.maybeWhen(
                  data: (list) => DropdownMenu<Product?>(
                    width: 428,
                    label: const Text('From the catalog (optional)'),
                    dropdownMenuEntries: [
                      const DropdownMenuEntry(
                          value: null, label: 'Something else'),
                      ...list.map(
                          (p) => DropdownMenuEntry(value: p, label: p.name)),
                    ],
                    onSelected: (p) => setState(() {
                      _product = p;
                      if (p != null) {
                        _name.text = p.name;
                        if (p.defaultUnit != null) _unit.text = p.defaultUnit!;
                      }
                    }),
                  ),
                  orElse: () => const LinearProgressIndicator(),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Product',
                    hintText: '500 custom printed boxes',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _quantity,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Quantity'),
                        validator: (v) {
                          final q = double.tryParse(v ?? '');
                          return (q == null || q <= 0)
                              ? 'Enter a quantity'
                              : null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _unit,
                        decoration: const InputDecoration(
                            labelText: 'Unit', hintText: 'pcs'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _specs,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Spec',
                    hintText: 'Size, colours, material, finishing',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            Navigator.pop(
              context,
              NewRequestItem(
                name: _name.text,
                quantity: double.parse(_quantity.text),
                productId: _product?.id,
                unit: _unit.text,
                specs: _specs.text,
              ),
            );
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
