import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inmore_core/inmore_core.dart';
import 'package:inmore_ui/inmore_ui.dart';

import '../../widgets/suggest_field.dart';

/// The month being looked at, as its first day. Kept outside the screen so
/// coming back to Expenses returns to the same month.
final expenseMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

/// What the shop spends, a month at a time, against what came in.
///
/// Two kinds: day-to-day (fuel, materials, a courier) and monthly fixed costs
/// (rent, salaries) — the second kind can be copied forward a month at a
/// time. An expense is corrected by editing it or voiding it with a reason;
/// it is never deleted, and every step is in the history (migration 013).
/// Owner and supervisors only: it's money.
class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  bool _showVoid = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;
    final month = ref.watch(expenseMonthProvider);
    final expenses = ref.watch(expensesForMonthProvider(month));
    final received = ref
            .watch(paymentsForMonthProvider(month))
            .valueOrNull
            ?.fold<double>(0, (s, p) => s + p.amount) ??
        0;
    final now = DateTime.now();
    final isThisMonth = month.year == now.year && month.month == now.month;

    void go(int delta) => ref.read(expenseMonthProvider.notifier).state =
        DateTime(month.year, month.month + delta);

    return Column(
      children: [
        PageHeader(
          title: l.expensesTitle,
          subtitle: l.expensesSubtitle,
          actions: [
            OutlinedButton.icon(
              onPressed: () => _copyMonthly(month),
              icon: const Icon(Icons.event_repeat_rounded, size: 18),
              label: Text(l.copyMonthly),
            ),
            const SizedBox(width: Space.sm),
            FilledButton.icon(
              onPressed: () => showExpenseDialog(context, month: month),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(l.addExpense),
            ),
          ],
          bottom: Row(
            children: [
              IconButton(
                tooltip: l.previousMonth,
                onPressed: () => go(-1),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              SizedBox(
                width: 160,
                child: Text(Fmt.month(month),
                    textAlign: TextAlign.center,
                    style: context.text.titleMedium),
              ),
              IconButton(
                tooltip: l.nextMonth,
                onPressed: () => go(1),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
              if (!isThisMonth)
                TextButton(
                  onPressed: () => ref
                      .read(expenseMonthProvider.notifier)
                      .state = DateTime(now.year, now.month),
                  child: Text(l.thisMonth),
                ),
              const Spacer(),
              FilterChip(
                label: Text(l.showVoided),
                selected: _showVoid,
                onSelected: (v) => setState(() => _showVoid = v),
              ),
            ],
          ),
        ),
        Expanded(
          child: AsyncView(
            value: expenses,
            onRetry: () => ref.invalidate(expensesForMonthProvider(month)),
            builder: (all) {
              final live = all.where((e) => !e.isVoid).toList();
              final total = live.fold<double>(0, (s, e) => s + e.amount);
              final fixed = live
                  .where((e) => e.isMonthly)
                  .fold<double>(0, (s, e) => s + e.amount);
              final net = received - total;
              final shown = _showVoid ? all : live;

              return ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 32),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: FigureTile(
                          value: Fmt.moneyShort(total),
                          label: l.spentThisMonth,
                          icon: Icons.payments_outlined,
                        ),
                      ),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: FigureTile(
                          value: Fmt.moneyShort(fixed),
                          label: l.monthlyFixed,
                          icon: Icons.event_repeat_rounded,
                        ),
                      ),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: FigureTile(
                          value: Fmt.moneyShort(total - fixed),
                          label: l.dayToDay,
                          icon: Icons.today_outlined,
                        ),
                      ),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: FigureTile(
                          value: Fmt.moneyShort(received),
                          label: l.receivedThisMonth,
                          icon: Icons.south_west_rounded,
                          color: t.success,
                        ),
                      ),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: Tooltip(
                          message: l.netHint,
                          child: FigureTile(
                            value: Fmt.moneyShort(net),
                            label: l.netThisMonth,
                            icon: Icons.balance_rounded,
                            color: net < 0 ? t.danger : t.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.lg),
                  if (shown.isEmpty)
                    Card(
                      child: EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: l.noExpenses,
                        body: l.noExpensesHint,
                        compact: true,
                        action: OutlinedButton.icon(
                          onPressed: () =>
                              showExpenseDialog(context, month: month),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: Text(l.addExpense),
                        ),
                      ),
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: _ByDay(expenses: shown)),
                        const SizedBox(width: Space.lg),
                        Expanded(
                          flex: 2,
                          child: _ByCategory(expenses: live, total: total),
                        ),
                      ],
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _copyMonthly(DateTime month) async {
    final previous = DateTime(month.year, month.month - 1);
    final added = await showDialog<int>(
      context: context,
      builder: (_) => _CopyMonthlyDialog(from: previous, to: month),
    );
    if (added != null && added > 0 && mounted) {
      showDone(context, context.l10n.expensesAdded(added));
      ref
        ..invalidate(expensesForMonthProvider(month))
        ..invalidate(expenseCategoriesProvider);
    }
  }
}

class _ByDay extends StatelessWidget {
  const _ByDay({required this.expenses});

  final List<Expense> expenses;

  @override
  Widget build(BuildContext context) {
    final days = <DateTime, List<Expense>>{};
    for (final e in expenses) {
      days.putIfAbsent(e.spentOn, () => []).add(e);
    }
    final keys = days.keys.toList()..sort((a, b) => b.compareTo(a));
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final d in keys) ...[
            Container(
              color: context.colors.surfaceContainerLow,
              padding:
                  const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 8),
              child: Row(
                children: [
                  Text(Fmt.date(d),
                      style: context.text.labelMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(
                    Fmt.money(days[d]!
                        .where((e) => !e.isVoid)
                        .fold<double>(0, (s, e) => s + e.amount)),
                    style: context.text.labelMedium,
                  ),
                ],
              ),
            ),
            for (final e in days[d]!) _ExpenseRow(expense: e),
          ],
        ],
      ),
    );
  }
}

class _ExpenseRow extends ConsumerWidget {
  const _ExpenseRow({required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final e = expense;
    final muted = context.text.bodySmall;
    final strike = e.isVoid
        ? const TextStyle(decoration: TextDecoration.lineThrough)
        : null;
    final detail = [
      if (e.description != null) e.description!,
      if (e.paidTo != null) e.paidTo!,
      e.method.tr(l),
      if (e.reference != null) e.reference!,
    ].join(' · ');

    return InkWell(
      onTap: e.isVoid ? null : () => showExpenseDialog(context, existing: e),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: UserText(e.category,
                            style: context.text.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w500)
                                .merge(strike)),
                      ),
                      if (e.isMonthly) ...[
                        const SizedBox(width: Space.sm),
                        StatusBadge(l.monthlyBadge,
                            color: context.tokens.info,
                            icon: Icons.event_repeat_rounded),
                      ],
                      if (e.isVoid) ...[
                        const SizedBox(width: Space.sm),
                        StatusBadge(l.voidBadge, color: context.tokens.neutral),
                      ],
                    ],
                  ),
                  UserText(
                    e.isVoid ? '${l.voidReason}: ${e.voidReason}' : detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: muted,
                  ),
                ],
              ),
            ),
            Text(Fmt.money(e.amount),
                style: context.text.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600)
                    .merge(strike)),
            SizedBox(
              width: 48,
              child: e.isVoid
                  ? null
                  : MenuAnchor(
                      menuChildren: [
                        MenuItemButton(
                          leadingIcon:
                              const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () =>
                              showExpenseDialog(context, existing: e),
                          child: Text(l.edit),
                        ),
                        MenuItemButton(
                          leadingIcon: Icon(Icons.block_rounded,
                              size: 18, color: context.colors.error),
                          onPressed: () => _void(context, ref),
                          child: Text(l.voidExpense,
                              style: TextStyle(color: context.colors.error)),
                        ),
                      ],
                      builder: (context, controller, _) => IconButton(
                        tooltip: l.moreActions,
                        icon: const Icon(Icons.more_vert_rounded, size: 18),
                        onPressed: () => controller.isOpen
                            ? controller.close()
                            : controller.open(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _void(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final reason = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.block_rounded, color: context.colors.error),
        title: Text(l.voidExpenseTitle),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${expense.category} · ${Fmt.money(expense.amount)}',
                    style: context.text.titleSmall),
                const SizedBox(height: Space.sm),
                Text(l.voidExpenseBody, style: context.text.bodyMedium),
                const SizedBox(height: Space.md),
                AppField(
                  controller: reason,
                  autofocus: true,
                  label: l.voidReason,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? l.required : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.keepIt),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: context.colors.error,
                foregroundColor: context.colors.onError),
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(context, true);
              }
            },
            child: Text(l.voidExpense),
          ),
        ],
      ),
    );
    final text = reason.text;
    reason.dispose();
    if (go != true || !context.mounted) return;
    final ok = await runAction(
      context,
      () => ref.read(expenseRepositoryProvider).voidExpense(expense.id, text),
      success: l.expenseVoided,
    );
    if (ok) ref.invalidate(expensesForMonthProvider);
  }
}

class _ByCategory extends StatelessWidget {
  const _ByCategory({required this.expenses, required this.total});

  final List<Expense> expenses;
  final double total;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final sums = <String, double>{};
    for (final e in expenses) {
      sums[e.category] = (sums[e.category] ?? 0) + e.amount;
    }
    final keys = sums.keys.toList()
      ..sort((a, b) => sums[b]!.compareTo(sums[a]!));
    return SectionCard(
      icon: Icons.donut_small_outlined,
      title: l.byCategory,
      child: Column(
        children: [
          for (final k in keys)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: UserText(k, style: context.text.bodyMedium)),
                      Text(Fmt.money(sums[k]),
                          style: context.text.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      SizedBox(
                        width: 48,
                        child: Text(
                          total == 0
                              ? ''
                              : '${(sums[k]! / total * 100).round()}%',
                          textAlign: TextAlign.end,
                          style: context.text.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : sums[k]! / total,
                      minHeight: 6,
                      color: context.colors.primary,
                      backgroundColor: context.colors.surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Add an expense (dated within [month] by default) or edit [existing].
Future<void> showExpenseDialog(
  BuildContext context, {
  Expense? existing,
  DateTime? month,
}) =>
    showDialog<void>(
      context: context,
      builder: (_) => _ExpenseDialog(existing: existing, month: month),
    );

class _ExpenseDialog extends ConsumerStatefulWidget {
  const _ExpenseDialog({this.existing, this.month});

  final Expense? existing;
  final DateTime? month;

  @override
  ConsumerState<_ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends ConsumerState<_ExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _category = TextEditingController(text: widget.existing?.category);
  late final _amount = TextEditingController(
      text: widget.existing == null ? '' : _plain(widget.existing!.amount));
  late final _paidTo = TextEditingController(text: widget.existing?.paidTo);
  late final _description =
      TextEditingController(text: widget.existing?.description);
  late final _reference =
      TextEditingController(text: widget.existing?.reference);
  late DateTime _date = widget.existing?.spentOn ?? _defaultDate();
  late PaymentMethod _method = widget.existing?.method ?? PaymentMethod.cash;
  late bool _monthly = widget.existing?.isMonthly ?? false;
  var _busy = false;

  /// Today, unless the screen is showing another month — then its first day.
  DateTime _defaultDate() {
    final now = DateTime.now();
    final m = widget.month;
    if (m == null || (m.year == now.year && m.month == now.month)) {
      return DateTime(now.year, now.month, now.day);
    }
    return m;
  }

  @override
  void dispose() {
    for (final c in [_category, _amount, _paidTo, _description, _reference]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final used = ref.watch(expenseCategoriesProvider).valueOrNull ?? const [];
    final categories =
        {...used, ...l.expenseCategoryDefaults.split('|')}.toList();

    return AlertDialog(
      title: Text(widget.existing == null ? l.addExpense : l.editExpense),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: l.fieldDate,
                          prefixIcon:
                              const Icon(Icons.event_outlined, size: 18),
                        ),
                        child: InkWell(
                          onTap: _pickDate,
                          child: Text(Fmt.date(_date)),
                        ),
                      ),
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: AppField(
                        controller: _amount,
                        autofocus: widget.existing == null,
                        label: '${l.amount} (${Fmt.currency})',
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        fixedDirection: TextDirection.ltr,
                        validator: (v) {
                          final a = double.tryParse((v ?? '').trim());
                          return (a == null || a <= 0) ? l.enterAmount : null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.md),
                SuggestField(
                  controller: _category,
                  label: l.fieldCategory,
                  options: categories,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? l.required : null,
                ),
                const SizedBox(height: Space.md),
                Row(
                  children: [
                    Expanded(
                      child:
                          AppField(controller: _paidTo, label: l.fieldPaidTo),
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: DropdownButtonFormField<PaymentMethod>(
                        isExpanded: true,
                        initialValue: _method,
                        decoration: InputDecoration(labelText: l.fieldMethod),
                        items: [
                          for (final m in PaymentMethod.values)
                            DropdownMenuItem(value: m, child: Text(m.tr(l))),
                        ],
                        onChanged: (m) =>
                            setState(() => _method = m ?? _method),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.md),
                AppField(controller: _description, label: l.fieldDescription),
                const SizedBox(height: Space.md),
                AppField(
                  controller: _reference,
                  label: '${l.reference} (${l.optional})',
                ),
                const SizedBox(height: Space.sm),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.monthlyCost),
                  subtitle: Text(l.monthlyCostHint),
                  value: _monthly,
                  onChanged: (v) => setState(() => _monthly = v),
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
          onPressed: _busy ? null : _save,
          child: Text(widget.existing == null ? l.record : l.save),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l = context.l10n;
    setState(() => _busy = true);
    final repo = ref.read(expenseRepositoryProvider);
    final amount = double.parse(_amount.text.trim());
    final ok = await runAction(
      context,
      () => widget.existing == null
          ? repo.record(
              spentOn: _date,
              category: _category.text,
              amount: amount,
              method: _method,
              isMonthly: _monthly,
              description: _description.text,
              paidTo: _paidTo.text,
              reference: _reference.text,
            )
          : repo.update(
              widget.existing!.id,
              spentOn: _date,
              category: _category.text,
              amount: amount,
              method: _method,
              isMonthly: _monthly,
              description: _description.text,
              paidTo: _paidTo.text,
              reference: _reference.text,
            ),
      success: widget.existing == null ? l.expenseRecorded : l.expenseUpdated,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      ref
        ..invalidate(expensesForMonthProvider)
        ..invalidate(expenseCategoriesProvider);
      Navigator.pop(context);
    }
  }
}

/// Last month's monthly costs, ticked and editable, to add to this month.
/// Ones already recorded this month (same category and payee) start unticked.
class _CopyMonthlyDialog extends ConsumerStatefulWidget {
  const _CopyMonthlyDialog({required this.from, required this.to});

  final DateTime from;
  final DateTime to;

  @override
  ConsumerState<_CopyMonthlyDialog> createState() => _CopyMonthlyDialogState();
}

class _CopyMonthlyDialogState extends ConsumerState<_CopyMonthlyDialog> {
  final Map<String, TextEditingController> _amounts = {};
  final Set<String> _ticked = {};
  bool _primed = false;
  var _busy = false;

  @override
  void dispose() {
    for (final c in _amounts.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final last = ref.watch(expensesForMonthProvider(widget.from));
    final current = ref.watch(expensesForMonthProvider(widget.to)).valueOrNull;

    return AlertDialog(
      title: Text(l.copyMonthlyTitle(Fmt.month(widget.from))),
      content: SizedBox(
        width: 540,
        child: AsyncView(
          value: last,
          onRetry: () => ref.invalidate(expensesForMonthProvider(widget.from)),
          builder: (all) {
            final monthly = all.where((e) => e.isMonthly && !e.isVoid).toList();
            if (monthly.isEmpty) {
              return Text(l.copyMonthlyNone(Fmt.month(widget.from)));
            }
            if (!_primed && current != null) {
              _primed = true;
              for (final e in monthly) {
                _amounts[e.id] = TextEditingController(text: _plain(e.amount));
                final already = current.any((c) =>
                    !c.isVoid &&
                    c.isMonthly &&
                    c.category == e.category &&
                    c.paidTo == e.paidTo);
                if (!already) _ticked.add(e.id);
              }
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.copyMonthlyBody(Fmt.month(widget.to)),
                    style: context.text.bodyMedium),
                const SizedBox(height: Space.md),
                for (final e in monthly)
                  if (_amounts[e.id] != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _ticked.contains(e.id),
                            onChanged: (v) => setState(() => v == true
                                ? _ticked.add(e.id)
                                : _ticked.remove(e.id)),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                UserText(e.category,
                                    style: context.text.bodyMedium),
                                if (e.paidTo != null)
                                  UserText(e.paidTo!,
                                      style: context.text.bodySmall),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 140,
                            child: AppField(
                              controller: _amounts[e.id]!,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              fixedDirection: TextDirection.ltr,
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: _busy || _ticked.isEmpty ? null : () => _add(last.value!),
          child: Text(l.copyMonthlyAdd(_ticked.length)),
        ),
      ],
    );
  }

  Future<void> _add(List<Expense> all) async {
    setState(() => _busy = true);
    final repo = ref.read(expenseRepositoryProvider);
    var added = 0;
    try {
      for (final e in all.where((e) => _ticked.contains(e.id))) {
        final amount = double.tryParse(_amounts[e.id]!.text.trim());
        if (amount == null || amount <= 0) continue;
        final day = e.spentOn.day
            .clamp(1, DateTime(widget.to.year, widget.to.month + 1, 0).day);
        await repo.record(
          spentOn: DateTime(widget.to.year, widget.to.month, day),
          category: e.category,
          amount: amount,
          method: e.method,
          isMonthly: true,
          description: e.description,
          paidTo: e.paidTo,
        );
        added++;
      }
      if (mounted) Navigator.pop(context, added);
    } catch (err) {
      if (!mounted) return;
      showError(context, err);
      // Whatever went in before the failure is in; let the screen show it.
      if (added > 0) {
        Navigator.pop(context, added);
      } else {
        setState(() => _busy = false);
      }
    }
  }
}

/// 1200 rather than 1200.0 in an edit field.
String _plain(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();
