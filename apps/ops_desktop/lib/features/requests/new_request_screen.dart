import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inmore_core/inmore_core.dart';
import 'package:inmore_ui/inmore_ui.dart';

import '../customers/customers_screen.dart';

/// True while the new-request form holds something worth asking about before
/// leaving. The router's `onExit` reads it.
final newRequestDirtyProvider = StateProvider<bool>((ref) => false);

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
  void initState() {
    super.initState();
    _title.addListener(_markDirty);
    _notes.addListener(_markDirty);
    // A fresh form has nothing to lose. Deferred: providers cannot change
    // while the tree is building.
    Future.microtask(() {
      if (mounted) ref.read(newRequestDirtyProvider.notifier).state = false;
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _markDirty() {
    final dirty = _customer != null ||
        _title.text.trim().isNotEmpty ||
        _notes.text.trim().isNotEmpty ||
        _neededBy != null ||
        _items.isNotEmpty;
    if (ref.read(newRequestDirtyProvider) != dirty) {
      ref.read(newRequestDirtyProvider.notifier).state = dirty;
    }
  }

  void _update(VoidCallback change) {
    setState(change);
    _markDirty();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Column(
      children: [
        PageHeader(
          leading: IconButton(
            tooltip: l.close,
            icon: const Icon(Icons.close_rounded),
            onPressed: () => context.go('/'),
          ),
          title: l.newRequestTitle,
          subtitle: l.newRequestSubtitle,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 24),
            child: Align(
              alignment: AlignmentDirectional.topStart,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _customerCard(context),
                    const SizedBox(height: Space.lg),
                    _requestCard(context),
                    const SizedBox(height: Space.lg),
                    _productsCard(context),
                  ],
                ),
              ),
            ),
          ),
        ),
        _ActionBar(
          canSave: _customer != null && !_busy,
          busy: _busy,
          onCancel: () => context.go('/'),
          onSave: _save,
        ),
      ],
    );
  }

  Widget _customerCard(BuildContext context) {
    final l = context.l10n;
    return SectionCard(
      icon: Icons.person_outline_rounded,
      title: l.sectionCustomer,
      actions: [
        TextButton.icon(
          onPressed: () async {
            final created = await showCustomerDialog(context);
            if (created != null) _update(() => _customer = created);
          },
          icon: const Icon(Icons.person_add_alt_rounded, size: 16),
          label: Text(l.newCustomer),
        ),
      ],
      child: _CustomerPicker(
        selected: _customer,
        onSelected: (c) => _update(() => _customer = c),
        onClear: () => _update(() => _customer = null),
      ),
    );
  }

  Widget _requestCard(BuildContext context) {
    final l = context.l10n;
    return SectionCard(
      icon: Icons.description_outlined,
      title: l.sectionRequest,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: AppField(
                  controller: _title,
                  label: l.fieldTitle,
                  hint: l.titleHint,
                ),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                flex: 2,
                child: InkWell(
                  borderRadius: BorderRadius.circular(Radii.md),
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: l.fieldNeededBy,
                      prefixIcon: const Icon(Icons.event_outlined, size: 18),
                      suffixIcon: _neededBy == null
                          ? null
                          : IconButton(
                              tooltip: l.clear,
                              icon: const Icon(Icons.close_rounded, size: 16),
                              onPressed: () => _update(() => _neededBy = null),
                            ),
                    ),
                    child: Text(
                      _neededBy == null ? l.notSet : Fmt.date(_neededBy),
                      style: _neededBy == null
                          ? context.text.bodyLarge
                              ?.copyWith(color: context.colors.onSurfaceVariant)
                          : context.text.bodyLarge,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          AppField(
            controller: _notes,
            maxLines: 3,
            label: l.fieldNotes,
            hint: l.notesHint,
          ),
        ],
      ),
    );
  }

  Widget _productsCard(BuildContext context) {
    final l = context.l10n;
    return SectionCard(
      icon: Icons.inventory_2_outlined,
      title: l.sectionProducts,
      subtitle: l.productsHint,
      actions: [
        TextButton.icon(
          onPressed: _addItem,
          icon: const Icon(Icons.add_rounded, size: 16),
          label: Text(l.addProduct),
        ),
      ],
      child: _items.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.sm),
              child: Text(l.noProductsYet, style: context.text.bodySmall),
            )
          : Column(
              children: [
                for (var i = 0; i < _items.length; i++) ...[
                  if (i > 0) const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Space.sm),
                    child: Row(
                      children: [
                        _Number(i + 1),
                        const SizedBox(width: Space.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              UserText(_items[i].name,
                                  style: context.text.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w500)),
                              if (_items[i].specs != null &&
                                  _items[i].specs!.isNotEmpty)
                                UserText(_items[i].specs!,
                                    style: context.text.bodySmall),
                            ],
                          ),
                        ),
                        UserText(
                          [
                            Fmt.qty(_items[i].quantity),
                            if (_items[i].unit != null) _items[i].unit!,
                          ].join(' '),
                          style: context.text.bodyMedium,
                        ),
                        const SizedBox(width: Space.sm),
                        IconButton(
                          tooltip: l.remove,
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 18),
                          onPressed: () => _update(() => _items.removeAt(i)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
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
    if (picked != null) _update(() => _neededBy = picked);
  }

  Future<void> _addItem() async {
    final item = await showDialog<NewRequestItem>(
      context: context,
      builder: (_) => const ProductDialog(),
    );
    if (item != null) _update(() => _items.add(item));
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
      // Saved: nothing left to lose, so leaving must not ask.
      ref.read(newRequestDirtyProvider.notifier).state = false;
      if (mounted) {
        showDone(context, context.l10n.requestCreated(created.number));
        context.go('/requests/${created.id}');
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.canSave,
    required this.busy,
    required this.onCancel,
    required this.onSave,
  });

  final bool canSave;
  final bool busy;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerLowest,
        border: Border(top: BorderSide(color: context.colors.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: [
            if (!canSave && !busy)
              Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 16, color: context.colors.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(l.chooseCustomerFirst, style: context.text.bodySmall),
                ],
              ),
            const Spacer(),
            TextButton(
              onPressed: busy ? null : onCancel,
              child: Text(l.cancel),
            ),
            const SizedBox(width: Space.sm),
            FilledButton.icon(
              onPressed: canSave ? onSave : null,
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded, size: 18),
              label: Text(l.createRequest),
            ),
          ],
        ),
      ),
    );
  }
}

class _Number extends StatelessWidget {
  const _Number(this.n);

  final int n;

  @override
  Widget build(BuildContext context) => Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.colors.surfaceContainerHigh,
          shape: BoxShape.circle,
        ),
        child: Text('$n', style: context.text.labelMedium),
      );
}

class _CustomerPicker extends ConsumerStatefulWidget {
  const _CustomerPicker({
    required this.selected,
    required this.onSelected,
    required this.onClear,
  });

  final Customer? selected;
  final ValueChanged<Customer> onSelected;
  final VoidCallback onClear;

  @override
  ConsumerState<_CustomerPicker> createState() => _CustomerPickerState();
}

class _CustomerPickerState extends ConsumerState<_CustomerPicker> {
  String _query = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (widget.selected != null) {
      final c = widget.selected!;
      return Container(
        padding: const EdgeInsets.all(Space.md),
        decoration: BoxDecoration(
          color: context.colors.secondaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Row(
          children: [
            InitialsAvatar(c.name, size: 36),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UserText(c.name,
                      style: context.text.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  Text(
                    [
                      if (c.company != null) c.company!,
                      if (c.phone != null) c.phone!,
                    ].join('  ·  '),
                    style: context.text.bodySmall,
                  ),
                ],
              ),
            ),
            TextButton(onPressed: widget.onClear, child: Text(l.change)),
          ],
        ),
      );
    }

    final results = ref.watch(customerSearchProvider(_query));
    return Column(
      children: [
        TextField(
          autofocus: true,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded, size: 18),
            hintText: l.findCustomerHint,
          ),
          onChanged: (v) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 250), () {
              if (mounted) setState(() => _query = v);
            });
          },
        ),
        const SizedBox(height: Space.sm),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240),
          child: AsyncView(
            value: results,
            compact: true,
            onRetry: () => ref.invalidate(customerSearchProvider(_query)),
            builder: (list) => list.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(Space.md),
                    child: Text(l.noMatchCreateFirst,
                        style: context.text.bodySmall),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: list.length,
                    itemBuilder: (context, i) => ListTile(
                      dense: true,
                      leading: InitialsAvatar(list[i].name, size: 28),
                      title: UserText(list[i].displayLine),
                      subtitle: list[i].phone == null
                          ? null
                          : Text(list[i].phone!,
                              textDirection: TextDirection.ltr),
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
///
/// Used on the new-request form and on a request's Products panel; given
/// [initial], it edits that product instead of adding one.
class ProductDialog extends ConsumerStatefulWidget {
  const ProductDialog({this.initial, super.key});

  final RequestItem? initial;

  @override
  ConsumerState<ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends ConsumerState<ProductDialog> {
  static String _plain(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toString();

  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name);
  // Plain digits, not Fmt.qty: "5,000" would not parse back.
  late final _quantity =
      TextEditingController(text: _plain(widget.initial?.quantity ?? 1));
  late final _unit = TextEditingController(text: widget.initial?.unit);
  late final _specs = TextEditingController(text: widget.initial?.specs);
  late String? _productId = widget.initial?.productId;

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
    final l = context.l10n;
    final products = ref.watch(productsProvider);

    return AlertDialog(
      title: Text(widget.initial == null ? l.addProduct : l.editProduct),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                products.when(
                  data: (list) => DropdownMenu<Product?>(
                    expandedInsets: EdgeInsets.zero,
                    label: Text('${l.fromCatalog} (${l.optional})'),
                    leadingIcon: const Icon(Icons.category_outlined, size: 18),
                    dropdownMenuEntries: [
                      DropdownMenuEntry(value: null, label: l.somethingElse),
                      ...list.map(
                          (p) => DropdownMenuEntry(value: p, label: p.name)),
                    ],
                    onSelected: (p) => setState(() {
                      _productId = p?.id;
                      if (p != null) {
                        _name.text = p.name;
                        if (p.defaultUnit != null) _unit.text = p.defaultUnit!;
                      }
                    }),
                  ),
                  loading: () => const CmykProgressBar(),
                  error: (e, _) => ErrorState(
                    error: e,
                    compact: true,
                    onRetry: () => ref.invalidate(productsProvider),
                  ),
                ),
                const SizedBox(height: Space.md),
                AppField(
                  controller: _name,
                  label: l.fieldProduct,
                  hint: l.productHint,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? l.required : null,
                ),
                const SizedBox(height: Space.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppField(
                        controller: _quantity,
                        keyboardType: TextInputType.number,
                        fixedDirection: TextDirection.ltr,
                        label: l.fieldQuantity,
                        validator: (v) {
                          final q = double.tryParse(v ?? '');
                          return (q == null || q <= 0) ? l.enterQuantity : null;
                        },
                      ),
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: AppField(
                        controller: _unit,
                        label: l.fieldUnit,
                        hint: l.unitHint,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.md),
                AppField(
                  controller: _specs,
                  maxLines: 2,
                  label: l.fieldSpec,
                  hint: l.specHint,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            Navigator.pop(
              context,
              NewRequestItem(
                name: _name.text,
                quantity: double.parse(_quantity.text),
                productId: _productId,
                unit: _unit.text,
                specs: _specs.text,
              ),
            );
          },
          child: Text(widget.initial == null ? l.add : l.save),
        ),
      ],
    );
  }
}
