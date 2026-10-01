import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inmore_core/inmore_core.dart';

import '../../widgets/common.dart';

// =============================================================================
// Quotations
// =============================================================================

/// Quotations are verbal here — nothing is emailed. "Presented" means told to
/// the customer, by whatever channel; the system records the fact.
///
/// A revision is never an edit: it supersedes and creates the next version, so
/// the history of the negotiation survives.
class QuotationsPanel extends ConsumerWidget {
  const QuotationsPanel({required this.request, super.key});

  final RequestSummary request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotes = ref.watch(requestQuotationsProvider(request.id));

    return SectionCard(
      title: 'Quotations',
      subtitle: 'Spoken, not sent — this records what was said',
      actions: [
        TextButton.icon(
          onPressed: () => _price(context, ref),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Price the work'),
        ),
      ],
      child: AsyncView(
        value: quotes,
        builder: (list) {
          if (list.isEmpty) return const EmptyNote('Nothing priced yet.');
          return Column(
            children: [
              for (final q in list) _QuotationTile(request: request, entry: q),
            ],
          );
        },
      ),
    );
  }

  Future<void> _price(BuildContext context, WidgetRef ref) async {
    final items = ref.read(requestItemsProvider(request.id)).valueOrNull ?? [];
    if (items.isEmpty) {
      showError(context, 'Add a product to the request before pricing it.');
      return;
    }
    final done = await showDialog<bool>(
      context: context,
      builder: (_) => _PricingDialog(requestId: request.id, items: items),
    );
    if (done ?? false) refreshRequest(ref, request.id);
  }
}

class _QuotationTile extends ConsumerWidget {
  const _QuotationTile({required this.request, required this.entry});

  final RequestSummary request;
  final QuotationWithLines entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = entry.quotation;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 48,
                child: Text(q.versionLabel, style: theme.textTheme.titleSmall),
              ),
              StatusChip(q.status.label,
                  color: quotationColour(q.status, scheme)),
              const SizedBox(width: 12),
              Text(Fmt.money(q.total), style: theme.textTheme.titleSmall),
              if (q.discount > 0) ...[
                const SizedBox(width: 8),
                Text('after ${Fmt.money(q.discount)} off',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ],
              const Spacer(),
              if (q.status == QuotationStatus.draft)
                TextButton(
                  onPressed: () =>
                      _set(context, ref, QuotationStatus.presented),
                  child: const Text('Told the customer'),
                ),
              if (q.status == QuotationStatus.presented) ...[
                TextButton(
                  onPressed: () => _set(context, ref, QuotationStatus.approved),
                  child: const Text('Approved'),
                ),
                TextButton(
                  onPressed: () => _set(context, ref, QuotationStatus.rejected),
                  child: const Text('Rejected'),
                ),
              ],
              if (q.status.isLive && q.status != QuotationStatus.draft)
                TextButton(
                  onPressed: () => _revise(context, ref),
                  child: const Text('Revise'),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 48, top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in entry.lines)
                  Text(
                    '${Fmt.qty(line.quantity)} × ${Fmt.amount(line.unitPrice)}'
                    '  =  ${Fmt.amount(line.lineTotal)}',
                    style: theme.textTheme.bodySmall,
                  ),
                Text(
                  q.presentedAt != null
                      ? 'Presented ${Fmt.date(q.presentedAt)}'
                      : 'Draft, ${Fmt.date(q.createdAt)}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const Divider(height: 20),
        ],
      ),
    );
  }

  Future<void> _set(
    BuildContext context,
    WidgetRef ref,
    QuotationStatus status,
  ) async {
    // Approving is refused by the database if one of these items is already
    // covered by another approved quotation — the error says which.
    final ok = await runAction(
      context,
      () => ref
          .read(quotationRepositoryProvider)
          .setStatus(entry.quotation.id, status),
      success: 'Marked ${status.label.toLowerCase()}',
    );
    if (ok) refreshRequest(ref, request.id);
  }

  Future<void> _revise(BuildContext context, WidgetRef ref) async {
    final items = ref.read(requestItemsProvider(request.id)).valueOrNull ?? [];
    final done = await showDialog<bool>(
      context: context,
      builder: (_) => _PricingDialog(
        requestId: request.id,
        items: items,
        reviseFrom: entry,
      ),
    );
    if (done ?? false) refreshRequest(ref, request.id);
  }
}

class _PricingDialog extends ConsumerStatefulWidget {
  const _PricingDialog({
    required this.requestId,
    required this.items,
    this.reviseFrom,
  });

  final String requestId;
  final List<RequestItem> items;
  final QuotationWithLines? reviseFrom;

  @override
  ConsumerState<_PricingDialog> createState() => _PricingDialogState();
}

class _PricingDialogState extends ConsumerState<_PricingDialog> {
  final Map<String, TextEditingController> _prices = {};
  final _discount = TextEditingController(text: '0');
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    for (final item in widget.items) {
      final existing = widget.reviseFrom?.lineFor(item.id);
      _prices[item.id] = TextEditingController(
        text: existing == null ? '' : existing.unitPrice.toString(),
      );
    }
    if (widget.reviseFrom != null) {
      _discount.text = widget.reviseFrom!.quotation.discount.toString();
    }
  }

  @override
  void dispose() {
    for (final c in _prices.values) {
      c.dispose();
    }
    _discount.dispose();
    super.dispose();
  }

  double get _subtotal {
    var total = 0.0;
    for (final item in widget.items) {
      final price = double.tryParse(_prices[item.id]!.text);
      if (price != null) total += price * item.quantity;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final discount = double.tryParse(_discount.text) ?? 0;

    return AlertDialog(
      title: Text(widget.reviseFrom == null
          ? 'Price the work'
          : 'Revise v${widget.reviseFrom!.quotation.version}'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Leave a product blank to quote it separately later.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              for (final item in widget.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name),
                            Text(item.quantityLabel,
                                style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 130,
                        child: TextField(
                          controller: _prices[item.id],
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'Unit price',
                            prefixText: 'QAR ',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      SizedBox(
                        width: 110,
                        child: Text(
                          () {
                            final p = double.tryParse(_prices[item.id]!.text);
                            return p == null
                                ? '—'
                                : Fmt.amount(p * item.quantity);
                          }(),
                          textAlign: TextAlign.right,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 24),
              Row(
                children: [
                  const Expanded(child: Text('Discount')),
                  SizedBox(
                    width: 130,
                    child: TextField(
                      controller: _discount,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        isDense: true,
                        prefixText: 'QAR ',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total', style: theme.textTheme.titleSmall),
                  Text(
                    Fmt.money((_subtotal - discount).clamp(0, double.infinity)),
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
              Text(
                'The database recalculates this when it saves — what you see '
                'here is a preview.',
                style: theme.textTheme.bodySmall,
              ),
            ],
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
          child: Text(widget.reviseFrom == null ? 'Create' : 'Create v+1'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final lines = <NewQuotationLine>[];
    for (final item in widget.items) {
      final price = double.tryParse(_prices[item.id]!.text);
      if (price != null) {
        lines.add(NewQuotationLine(requestItemId: item.id, unitPrice: price));
      }
    }
    if (lines.isEmpty) {
      showError(context, 'Put a price on at least one product.');
      return;
    }

    setState(() => _busy = true);
    final repo = ref.read(quotationRepositoryProvider);
    final discount = double.tryParse(_discount.text) ?? 0;

    final ok = await runAction(
      context,
      () async {
        if (widget.reviseFrom == null) {
          await repo.create(
            requestId: widget.requestId,
            lines: lines,
            discount: discount,
          );
        } else {
          await repo.revise(
            quotationId: widget.reviseFrom!.quotation.id,
            lines: lines,
            discount: discount,
          );
        }
      },
      success: 'Quotation saved',
    );

    if (mounted) {
      setState(() => _busy = false);
      if (ok) Navigator.pop(context, true);
    }
  }
}

// =============================================================================
// Payments
// =============================================================================

class PaymentsPanel extends ConsumerWidget {
  const PaymentsPanel({required this.request, super.key});

  final RequestSummary request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payments = ref.watch(requestPaymentsProvider(request.id));
    final theme = Theme.of(context);

    return SectionCard(
      title: 'Payments',
      actions: [
        TextButton.icon(
          onPressed: () => _record(context, ref),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Record payment'),
        ),
      ],
      child: AsyncView(
        value: payments,
        builder: (list) {
          if (list.isEmpty) return const EmptyNote('Nothing received yet.');
          return Column(
            children: [
              for (final p in list)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 140,
                        child: Text(Fmt.money(p.amount),
                            style: theme.textTheme.bodyMedium),
                      ),
                      SizedBox(width: 130, child: StatusChip(p.kind.label)),
                      SizedBox(
                        width: 130,
                        child: Text(p.method.label,
                            style: theme.textTheme.bodySmall),
                      ),
                      Expanded(
                        child: Text(Fmt.date(p.paidAt),
                            style: theme.textTheme.bodySmall),
                      ),
                      if (p.reference != null)
                        Text(p.reference!, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Payments cannot be edited or deleted. A mistake is '
                  'corrected by recording the opposite.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _record(BuildContext context, WidgetRef ref) async {
    final done = await showDialog<bool>(
      context: context,
      builder: (_) => _PaymentDialog(requestId: request.id),
    );
    if (done ?? false) refreshRequest(ref, request.id);
  }
}

class _PaymentDialog extends ConsumerStatefulWidget {
  const _PaymentDialog({required this.requestId});

  final String requestId;

  @override
  ConsumerState<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends ConsumerState<_PaymentDialog> {
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  PaymentMethod _method = PaymentMethod.cash;
  PaymentKind _kind = PaymentKind.partial;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record a payment'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: 'QAR ',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PaymentMethod>(
              initialValue: _method,
              decoration: const InputDecoration(labelText: 'How'),
              items: PaymentMethod.values
                  .map((m) => DropdownMenuItem(value: m, child: Text(m.label)))
                  .toList(),
              onChanged: (m) => setState(() => _method = m ?? _method),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PaymentKind>(
              initialValue: _kind,
              decoration: const InputDecoration(
                labelText: 'What it is',
                helperText:
                    'A label only — whether the job is settled is worked out '
                    'from the total.',
              ),
              items: PaymentKind.values
                  .map((k) => DropdownMenuItem(value: k, child: Text(k.label)))
                  .toList(),
              onChanged: (k) => setState(() => _kind = k ?? _kind),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reference,
              decoration: const InputDecoration(
                labelText: 'Reference',
                hintText: 'Receipt or transfer number',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: const Text('Record'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text);
    if (amount == null || amount <= 0) {
      showError(context, 'Enter an amount.');
      return;
    }
    setState(() => _busy = true);
    final ok = await runAction(
      context,
      () => ref.read(paymentRepositoryProvider).record(
            requestId: widget.requestId,
            amount: amount,
            method: _method,
            kind: _kind,
            reference:
                _reference.text.trim().isEmpty ? null : _reference.text.trim(),
          ),
      success: 'Payment recorded',
    );
    if (mounted) {
      setState(() => _busy = false);
      if (ok) Navigator.pop(context, true);
    }
  }
}
