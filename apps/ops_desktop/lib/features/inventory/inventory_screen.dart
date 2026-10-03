import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inmore_core/inmore_core.dart';
import 'package:inmore_ui/inmore_ui.dart';

import '../../widgets/suggest_field.dart';

/// Stock, recorded by hand: what came in, what went out, what a count found.
///
/// Not linked to requests yet. The figure on hand is the database's sum of
/// the movement ledger, so it can never disagree with its own history; a
/// mistake is corrected with the opposite movement or a stock count.
///
/// Who can do what mirrors migration 013: managers add and edit items and
/// count stock, production records in and out, designers look. Cost and value
/// only reach those who see money.
class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _search = TextEditingController();
  String? _category;
  bool _lowOnly = false;
  bool _archived = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final role = ref.watch(currentEmployeeProvider).valueOrNull?.role;
    final manages = role?.canManageRequests ?? false;
    final money = role?.canSeeMoney ?? false;
    final items = ref.watch(inventoryProvider(_archived));
    final costs = money
        ? (ref.watch(inventoryCostsProvider).valueOrNull ?? const {})
        : const <String, double>{};
    final categories = {
      for (final i in items.valueOrNull ?? const <InventoryItem>[])
        if (i.category != null) i.category!,
    }.toList()
      ..sort();

    return Column(
      children: [
        PageHeader(
          title: l.inventoryTitle,
          subtitle: l.inventorySubtitle,
          actions: [
            if (manages)
              FilledButton.icon(
                onPressed: () => showStockItemDialog(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(l.addStockItem),
              ),
          ],
          bottom: Wrap(
            spacing: Space.md,
            runSpacing: Space.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 320,
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    hintText: l.searchHint,
                  ),
                ),
              ),
              if (categories.isNotEmpty)
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String?>(
                    isExpanded: true,
                    initialValue: _category,
                    decoration: InputDecoration(labelText: l.fieldCategory),
                    items: [
                      DropdownMenuItem(
                          value: null, child: Text(l.allCategories)),
                      for (final c in categories)
                        DropdownMenuItem(value: c, child: UserText(c)),
                    ],
                    onChanged: (v) => setState(() => _category = v),
                  ),
                ),
              FilterChip(
                label: Text(l.lowStockOnly),
                selected: _lowOnly,
                onSelected: (v) => setState(() => _lowOnly = v),
              ),
              if (manages)
                FilterChip(
                  label: Text(l.showArchived),
                  selected: _archived,
                  onSelected: (v) => setState(() => _archived = v),
                ),
            ],
          ),
        ),
        Expanded(
          child: AsyncView(
            value: items,
            onRetry: () => ref.invalidate(inventoryProvider(_archived)),
            builder: (all) {
              if (all.isEmpty) {
                return EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: l.noStockItems,
                  body: l.noStockItemsHint,
                  action: manages
                      ? OutlinedButton.icon(
                          onPressed: () => showStockItemDialog(context),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: Text(l.addStockItem),
                        )
                      : null,
                );
              }
              final q = _search.text.trim().toLowerCase();
              final shown = [
                for (final i in all)
                  if ((_category == null || i.category == _category) &&
                      (!_lowOnly || i.isLow || i.isOut) &&
                      (q.isEmpty ||
                          i.name.toLowerCase().contains(q) ||
                          (i.code?.toLowerCase().contains(q) ?? false) ||
                          (i.category?.toLowerCase().contains(q) ?? false)))
                    i,
              ];
              final active = all.where((i) => i.isActive).toList();
              final value = active.fold<double>(
                  0,
                  (s, i) =>
                      s + (costs[i.id] ?? 0) * (i.onHand > 0 ? i.onHand : 0));

              return ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 32),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: FigureTile(
                          value: '${active.length}',
                          label: l.stockItemsCount,
                          icon: Icons.inventory_2_outlined,
                        ),
                      ),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: FigureTile(
                          value:
                              '${active.where((i) => i.isLow && !i.isOut).length}',
                          label: l.runningLow,
                          icon: Icons.trending_down_rounded,
                          color: context.tokens.warning,
                          onTap: () => setState(() => _lowOnly = true),
                        ),
                      ),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: FigureTile(
                          value: '${active.where((i) => i.isOut).length}',
                          label: l.outOfStock,
                          icon: Icons.remove_shopping_cart_outlined,
                          color: context.tokens.danger,
                          onTap: () => setState(() => _lowOnly = true),
                        ),
                      ),
                      if (money) ...[
                        const SizedBox(width: Space.md),
                        Expanded(
                          child: FigureTile(
                            value: Fmt.moneyShort(value),
                            label: l.stockValue,
                            icon: Icons.account_balance_wallet_outlined,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: Space.lg),
                  Card(
                    child: shown.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(Space.xl),
                            child: Center(child: Text(l.noStockMatch)),
                          )
                        : Column(
                            children: [
                              _HeaderRow(money: money),
                              for (final i in shown) ...[
                                const Divider(),
                                _ItemRow(
                                  item: i,
                                  cost: costs[i.id],
                                  money: money,
                                  manages: manages,
                                  records: role != null &&
                                      role != EmployeeRole.designer,
                                ),
                              ],
                            ],
                          ),
                  ),
                  const SizedBox(height: Space.lg),
                  const _RecentMovements(),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.money});

  final bool money;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.text.labelSmall
        ?.copyWith(color: context.colors.onSurfaceVariant);
    Widget cell(String t, int flex, {bool end = false}) => Expanded(
          flex: flex,
          child: Text(t,
              style: s, textAlign: end ? TextAlign.end : TextAlign.start),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, 12, Space.lg, 10),
      child: Row(
        children: [
          cell(l.colItem, 5),
          cell(l.colInStock, 3, end: true),
          cell(l.colReorderAt, 2, end: true),
          const SizedBox(width: Space.lg),
          cell(l.colLocation, 3),
          if (money) ...[
            cell(l.colUnitCost, 2, end: true),
            cell(l.colValue, 2, end: true),
          ],
          cell(l.colLastMovement, 2, end: true),
          const SizedBox(width: 144),
        ],
      ),
    );
  }
}

class _ItemRow extends ConsumerWidget {
  const _ItemRow({
    required this.item,
    required this.cost,
    required this.money,
    required this.manages,
    required this.records,
  });

  final InventoryItem item;
  final double? cost;
  final bool money;
  final bool manages;

  /// May record stock in and out (managers and production).
  final bool records;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = context.tokens;
    final i = item;
    final muted = context.text.bodySmall;
    final qtyColour = i.isOut ? t.danger : (i.isLow ? t.warning : null);
    final sub = [i.code, i.category].whereType<String>().join(' · ');

    return InkWell(
      onTap: () => showItemHistory(context, i),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 10),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: UserText(i.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w500)),
                      ),
                      if (!i.isActive) ...[
                        const SizedBox(width: Space.sm),
                        StatusBadge(l.archived, color: t.neutral),
                      ],
                    ],
                  ),
                  if (sub.isNotEmpty) UserText(sub, style: muted),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (i.isOut || i.isLow) ...[
                    StatusBadge(i.isOut ? l.outBadge : l.lowBadge,
                        color: qtyColour, dot: true),
                    const SizedBox(width: Space.sm),
                  ],
                  Text(Fmt.qty(i.onHand),
                      style: context.text.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600, color: qtyColour)),
                  const SizedBox(width: 4),
                  UserText(i.unit, style: muted),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(i.reorderLevel > 0 ? Fmt.qty(i.reorderLevel) : '—',
                  textAlign: TextAlign.end, style: muted),
            ),
            const SizedBox(width: Space.lg),
            Expanded(
              flex: 3,
              child: UserText(i.location ?? '—',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: muted),
            ),
            if (money) ...[
              Expanded(
                flex: 2,
                child: Text(cost == null ? '—' : Fmt.amount(cost),
                    textAlign: TextAlign.end, style: muted),
              ),
              Expanded(
                flex: 2,
                child: Text(
                    cost == null
                        ? '—'
                        : Fmt.amount(cost! * (i.onHand > 0 ? i.onHand : 0)),
                    textAlign: TextAlign.end,
                    style: context.text.bodyMedium),
              ),
            ],
            Expanded(
              flex: 2,
              child: Text(Fmt.dayMonth(i.lastMovedAt),
                  textAlign: TextAlign.end, style: muted),
            ),
            SizedBox(
              width: 144,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (records && i.isActive) ...[
                    IconButton(
                      tooltip: l.receiveStock,
                      icon: Icon(Icons.add_circle_outline_rounded,
                          size: 20, color: t.success),
                      onPressed: () => showMovementDialog(
                          context, i, StockMovementKind.stockIn),
                    ),
                    IconButton(
                      tooltip: l.takeOutStock,
                      icon: const Icon(Icons.remove_circle_outline_rounded,
                          size: 20),
                      onPressed: i.isOut
                          ? null
                          : () => showMovementDialog(
                              context, i, StockMovementKind.stockOut),
                    ),
                  ],
                  _ItemMenu(item: i, manages: manages, cost: cost),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemMenu extends ConsumerWidget {
  const _ItemMenu({required this.item, required this.manages, this.cost});

  final InventoryItem item;
  final bool manages;
  final double? cost;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.history_rounded, size: 18),
          onPressed: () => showItemHistory(context, item),
          child: Text(l.stockHistory),
        ),
        if (manages && item.isActive)
          MenuItemButton(
            leadingIcon: const Icon(Icons.fact_check_outlined, size: 18),
            onPressed: () =>
                showMovementDialog(context, item, StockMovementKind.adjust),
            child: Text(l.stockCount),
          ),
        if (manages) ...[
          MenuItemButton(
            leadingIcon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: () =>
                showStockItemDialog(context, existing: item, cost: cost),
            child: Text(l.editStockItem),
          ),
          const Divider(),
          MenuItemButton(
            leadingIcon: Icon(
                item.isActive
                    ? Icons.archive_outlined
                    : Icons.unarchive_outlined,
                size: 18),
            onPressed: () async {
              final ok = await runAction(
                context,
                () => ref
                    .read(inventoryRepositoryProvider)
                    .setActive(item.id, !item.isActive),
                success: item.isActive ? l.itemArchived : l.itemRestored,
              );
              if (ok) ref.invalidate(inventoryProvider);
            },
            child: Text(item.isActive ? l.archiveItem : l.restoreItem),
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
}

class _RecentMovements extends ConsumerWidget {
  const _RecentMovements();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final moves = ref.watch(stockMovementsProvider(null));
    final list =
        (moves.valueOrNull ?? const <StockMovement>[]).take(12).toList();
    return SectionCard(
      icon: Icons.swap_vert_rounded,
      title: l.recentMovements,
      child: list.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.md),
              child: Text(l.noMovements, style: context.text.bodySmall),
            )
          : Column(
              children: [
                for (final m in list) _MovementLine(m, showItem: true),
              ],
            ),
    );
  }
}

class _MovementLine extends StatelessWidget {
  const _MovementLine(this.m, {this.showItem = false});

  final StockMovement m;
  final bool showItem;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;
    final colour = m.quantity > 0 ? t.success : context.colors.onSurface;
    final icon = switch (m.kind) {
      StockMovementKind.stockIn => Icons.add_circle_outline_rounded,
      StockMovementKind.stockOut => Icons.remove_circle_outline_rounded,
      StockMovementKind.adjust => Icons.fact_check_outlined,
    };
    final sign = m.quantity > 0 ? '+' : '−';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.colors.onSurfaceVariant),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserText(
                  showItem ? '${m.itemName} · ${m.kind.tr(l)}' : m.kind.tr(l),
                  style: context.text.bodyMedium,
                ),
                Text(
                  [
                    l.stamp(m.movedAt),
                    if (m.recordedByName != null) l.byName(m.recordedByName!),
                    if (m.note != null) m.note!,
                  ].join(' · '),
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
          Text('$sign${Fmt.qty(m.quantity.abs())} ${m.unit}',
              textDirection: TextDirection.ltr,
              style: context.text.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600, color: colour)),
        ],
      ),
    );
  }
}

/// One item's ledger, newest first.
Future<void> showItemHistory(BuildContext context, InventoryItem item) =>
    showDialog<void>(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final l = context.l10n;
          final moves = ref.watch(stockMovementsProvider(item.id));
          return AlertDialog(
            title: Text(l.itemHistoryTitle(item.name)),
            content: SizedBox(
              width: 520,
              height: 420,
              child: AsyncView(
                value: moves,
                onRetry: () => ref.invalidate(stockMovementsProvider(item.id)),
                builder: (list) => list.isEmpty
                    ? Center(child: Text(l.noMovements))
                    : ListView(
                        children: [for (final m in list) _MovementLine(m)],
                      ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l.close),
              ),
            ],
          );
        },
      ),
    );

/// Receive, take out, or count. A count asks for what is actually on the
/// shelf and records the difference.
Future<void> showMovementDialog(
  BuildContext context,
  InventoryItem item,
  StockMovementKind kind,
) =>
    showDialog<void>(
      context: context,
      builder: (_) => _MovementDialog(item: item, kind: kind),
    );

class _MovementDialog extends ConsumerStatefulWidget {
  const _MovementDialog({required this.item, required this.kind});

  final InventoryItem item;
  final StockMovementKind kind;

  @override
  ConsumerState<_MovementDialog> createState() => _MovementDialogState();
}

class _MovementDialogState extends ConsumerState<_MovementDialog> {
  final _formKey = GlobalKey<FormState>();
  final _qty = TextEditingController();
  final _note = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _qty.dispose();
    _note.dispose();
    super.dispose();
  }

  double? get _entered => double.tryParse(_qty.text.trim());

  double? get _after {
    final q = _entered;
    if (q == null) return null;
    return switch (widget.kind) {
      StockMovementKind.stockIn => widget.item.onHand + q,
      StockMovementKind.stockOut => widget.item.onHand - q,
      StockMovementKind.adjust => q,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final i = widget.item;
    final count = widget.kind == StockMovementKind.adjust;
    final after = _after;
    final title = switch (widget.kind) {
      StockMovementKind.stockIn => l.receiveTitle(i.name),
      StockMovementKind.stockOut => l.takeOutTitle(i.name),
      StockMovementKind.adjust => l.countTitle(i.name),
    };
    final noteLabel = switch (widget.kind) {
      StockMovementKind.stockIn => l.movementNoteIn,
      StockMovementKind.stockOut => l.movementNoteOut,
      StockMovementKind.adjust => l.movementNoteCount,
    };

    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.inStockNow('${Fmt.qty(i.onHand)} ${i.unit}'),
                  style: context.text.bodyMedium),
              const SizedBox(height: Space.md),
              AppField(
                controller: _qty,
                autofocus: true,
                label: count ? l.countedField : l.fieldQuantity,
                suffix: Text(i.unit),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                fixedDirection: TextDirection.ltr,
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  final q = double.tryParse((v ?? '').trim());
                  if (q == null || q < 0 || (!count && q == 0)) {
                    return l.enterQuantity;
                  }
                  return null;
                },
              ),
              if (after != null) ...[
                const SizedBox(height: Space.sm),
                Text(l.afterThis('${Fmt.qty(after)} ${i.unit}'),
                    style: context.text.bodySmall?.copyWith(
                        color: after < 0 ? context.tokens.danger : null)),
              ],
              const SizedBox(height: Space.md),
              AppField(controller: _note, label: noteLabel),
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
          child: Text(l.record),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l = context.l10n;
    final q = _entered!;
    if (widget.kind == StockMovementKind.adjust && q == widget.item.onHand) {
      showDone(context, l.countMatches);
      Navigator.pop(context);
      return;
    }
    setState(() => _busy = true);
    final ok = await runAction(
      context,
      () => ref.read(inventoryRepositoryProvider).record(
            itemId: widget.item.id,
            kind: widget.kind,
            quantity: q,
            countedOnHand: q,
            currentOnHand: widget.item.onHand,
            note: _note.text,
          ),
      success: l.stockRecorded,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      ref
        ..invalidate(inventoryProvider)
        ..invalidate(stockMovementsProvider);
      Navigator.pop(context);
    }
  }
}

/// Add or edit a stock item. Unit cost appears only for those who see money,
/// and is stored apart from the item (it's money; the item isn't).
Future<void> showStockItemDialog(
  BuildContext context, {
  InventoryItem? existing,
  double? cost,
}) =>
    showDialog<void>(
      context: context,
      builder: (_) => _StockItemDialog(existing: existing, cost: cost),
    );

class _StockItemDialog extends ConsumerStatefulWidget {
  const _StockItemDialog({this.existing, this.cost});

  final InventoryItem? existing;
  final double? cost;

  @override
  ConsumerState<_StockItemDialog> createState() => _StockItemDialogState();
}

class _StockItemDialogState extends ConsumerState<_StockItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _code = TextEditingController(text: widget.existing?.code);
  late final _category = TextEditingController(text: widget.existing?.category);
  late final _unit = TextEditingController(text: widget.existing?.unit);
  late final _reorder = TextEditingController(
      text: widget.existing == null || widget.existing!.reorderLevel == 0
          ? ''
          : Fmt.qty(widget.existing!.reorderLevel).replaceAll(',', ''));
  late final _location = TextEditingController(text: widget.existing?.location);
  late final _notes = TextEditingController(text: widget.existing?.notes);
  late final _cost = TextEditingController(
      text: widget.cost == null ? '' : widget.cost!.toString());
  var _busy = false;

  @override
  void dispose() {
    for (final c in [
      _name,
      _code,
      _category,
      _unit,
      _reorder,
      _location,
      _notes,
      _cost
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final money =
        ref.watch(currentEmployeeProvider).valueOrNull?.role.canSeeMoney ??
            false;
    final categories = {
      for (final i in ref.watch(inventoryProvider(true)).valueOrNull ??
          const <InventoryItem>[])
        if (i.category != null) i.category!,
    }.toList();
    final units = l.unitDefaults.split('|');

    return AlertDialog(
      title: Text(widget.existing == null ? l.addStockItem : l.editStockItem),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
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
                Row(
                  children: [
                    Expanded(
                        child: AppField(controller: _code, label: l.fieldCode)),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: SuggestField(
                        controller: _category,
                        label: l.fieldCategory,
                        options: categories,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.md),
                Row(
                  children: [
                    Expanded(
                      child: SuggestField(
                          controller: _unit,
                          label: l.fieldUnit,
                          options: units),
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: AppField(
                        controller: _reorder,
                        label: l.fieldReorderLevel,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        fixedDirection: TextDirection.ltr,
                        validator: (v) => (v == null ||
                                v.trim().isEmpty ||
                                (double.tryParse(v.trim()) ?? -1) >= 0)
                            ? null
                            : l.enterQuantity,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child:
                      Text(l.fieldReorderHint, style: context.text.bodySmall),
                ),
                const SizedBox(height: Space.md),
                AppField(controller: _location, label: l.fieldLocation),
                if (money) ...[
                  const SizedBox(height: Space.md),
                  AppField(
                    controller: _cost,
                    label: '${l.fieldUnitCost} (${Fmt.currency})',
                    helper: l.unitCostHint,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    fixedDirection: TextDirection.ltr,
                    validator: (v) => (v == null ||
                            v.trim().isEmpty ||
                            (double.tryParse(v.trim()) ?? -1) >= 0)
                        ? null
                        : l.enterAmount,
                  ),
                ],
                const SizedBox(height: Space.md),
                AppField(controller: _notes, label: l.fieldNotes, maxLines: 2),
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
            onPressed: _busy ? null : () => _save(money), child: Text(l.save)),
      ],
    );
  }

  Future<void> _save(bool money) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    final repo = ref.read(inventoryRepositoryProvider);
    final reorder = double.tryParse(_reorder.text.trim()) ?? 0;
    final ok = await runAction(
      context,
      () async {
        var id = widget.existing?.id;
        if (id == null) {
          id = await repo.createItem(
            name: _name.text,
            unit: _unit.text,
            code: _code.text,
            category: _category.text,
            reorderLevel: reorder,
            location: _location.text,
            notes: _notes.text,
          );
        } else {
          await repo.updateItem(
            id,
            name: _name.text,
            unit: _unit.text,
            code: _code.text,
            category: _category.text,
            reorderLevel: reorder,
            location: _location.text,
            notes: _notes.text,
          );
        }
        if (money) {
          final cost = double.tryParse(_cost.text.trim());
          if (cost != widget.cost) await repo.setCost(id, cost);
        }
      },
      success: context.l10n.itemSaved,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      ref
        ..invalidate(inventoryProvider)
        ..invalidate(inventoryCostsProvider);
      Navigator.pop(context);
    }
  }
}
