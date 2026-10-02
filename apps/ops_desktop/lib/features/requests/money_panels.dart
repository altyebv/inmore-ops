import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inmore_core/inmore_core.dart';
import 'package:inmore_ui/inmore_ui.dart';

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
    final l = context.l10n;
    final quotes = ref.watch(requestQuotationsProvider(request.id));
    final items = ref.watch(requestItemsProvider(request.id)).valueOrNull ?? [];

    return SectionCard(
      icon: Icons.request_quote_outlined,
      title: l.quotationsTitle,
      actions: [
        if (request.status.isOpen)
          TextButton.icon(
            onPressed: () => _price(context, ref),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: Text(l.priceTheWork),
          ),
      ],
      child: AsyncView(
        value: quotes,
        compact: true,
        onRetry: () => ref.invalidate(requestQuotationsProvider(request.id)),
        builder: (list) {
          if (list.isEmpty) {
            return Text(l.nothingPriced, style: context.text.bodySmall);
          }
          return Column(
            children: [
              for (var i = 0; i < list.length; i++) ...[
                if (i > 0) const Divider(),
                _QuotationTile(request: request, entry: list[i], items: items),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _price(BuildContext context, WidgetRef ref) async {
    final items =
        _priceable(ref.read(requestItemsProvider(request.id)).valueOrNull);
    if (items.isEmpty) {
      showError(context, context.l10n.addProductBeforePricing);
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
  const _QuotationTile({
    required this.request,
    required this.entry,
    required this.items,
  });

  final RequestSummary request;
  final QuotationWithLines entry;
  final List<RequestItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final q = entry.quotation;
    final t = context.tokens;
    final muted = q.status == QuotationStatus.superseded ||
        q.status == QuotationStatus.rejected;

    String itemName(String id) {
      for (final i in items) {
        if (i.id == id) return i.name;
      }
      return '—';
    }

    return Opacity(
      opacity: muted ? 0.6 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(q.versionLabel, style: context.text.labelLarge),
                ),
                const SizedBox(width: Space.sm),
                StatusBadge(q.status.tr(l),
                    color: t.quotation(q.status), dot: true),
                const SizedBox(width: Space.md),
                Text(
                  q.presentedAt != null
                      ? l.presentedOn(Fmt.date(q.presentedAt))
                      : l.draftOn(Fmt.date(q.createdAt)),
                  style: context.text.bodySmall,
                ),
                const Spacer(),
                Text(Fmt.money(q.total), style: context.text.titleMedium),
              ],
            ),
            const SizedBox(height: Space.sm),
            for (final line in entry.lines)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 4, top: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: UserText(itemName(line.requestItemId),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySmall),
                    ),
                    Text(
                      '${Fmt.qty(line.quantity)} × ${Fmt.amount(line.unitPrice)}',
                      style: context.text.bodySmall,
                    ),
                    SizedBox(
                      width: 110,
                      child: Text(
                        Fmt.amount(line.lineTotal),
                        textAlign: TextAlign.end,
                        style: context.text.bodySmall
                            ?.copyWith(color: context.colors.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
            if (q.discount > 0)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 4, top: 4),
                child: Text(l.afterDiscount(Fmt.money(q.discount)),
                    style: context.text.bodySmall),
              ),
            if (q.status.isLive && request.status.isOpen) ...[
              const SizedBox(height: Space.md),
              Wrap(
                spacing: Space.sm,
                runSpacing: Space.sm,
                children: [
                  if (q.status == QuotationStatus.draft)
                    FilledButton.tonalIcon(
                      onPressed: () =>
                          _set(context, ref, QuotationStatus.presented),
                      icon: const Icon(Icons.record_voice_over_outlined,
                          size: 16),
                      label: Text(l.toldCustomer),
                    ),
                  if (q.status == QuotationStatus.presented) ...[
                    FilledButton.icon(
                      onPressed: () =>
                          _set(context, ref, QuotationStatus.approved),
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: Text(l.markApproved),
                    ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          _set(context, ref, QuotationStatus.rejected),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: Text(l.markRejected),
                    ),
                  ],
                  if (q.status == QuotationStatus.draft)
                    TextButton.icon(
                      onPressed: () => _editDraft(context, ref),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: Text(l.editDraft),
                    ),
                  if (q.status != QuotationStatus.draft)
                    TextButton.icon(
                      onPressed: () => _revise(context, ref),
                      icon: const Icon(Icons.edit_note_rounded, size: 18),
                      label: Text(l.revise),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _set(
    BuildContext context,
    WidgetRef ref,
    QuotationStatus status,
  ) async {
    final l = context.l10n;
    final q = entry.quotation;
    // Approval fixes the price; rejection closes this version. Both are
    // worth a second look before they go into the record.
    if (status == QuotationStatus.approved) {
      final sure = await confirm(
        context,
        title: l.approveTitle(q.versionLabel),
        body: l.approveBody(Fmt.money(q.total)),
        confirmLabel: l.markApproved,
        icon: Icons.verified_outlined,
      );
      if (!sure) return;
    }
    if (!context.mounted) return;
    if (status == QuotationStatus.rejected) {
      final sure = await confirm(
        context,
        title: l.rejectTitle(q.versionLabel),
        body: l.rejectBody,
        confirmLabel: l.markRejected,
        destructive: true,
      );
      if (!sure) return;
    }
    if (!context.mounted) return;
    // Approving is refused by the database if one of these items is already
    // covered by another approved quotation — the error says which.
    final ok = await runAction(
      context,
      () => ref.read(quotationRepositoryProvider).setStatus(q.id, status),
      success: l.markedStatus(status.tr(l)),
    );
    if (ok) refreshRequest(ref, request.id);
  }

  Future<void> _revise(BuildContext context, WidgetRef ref) async {
    final done = await showDialog<bool>(
      context: context,
      builder: (_) => _PricingDialog(
        requestId: request.id,
        items: _priceable(items),
        reviseFrom: entry,
      ),
    );
    if (done ?? false) refreshRequest(ref, request.id);
  }

  /// A draft nobody has heard yet is corrected in place, not versioned.
  Future<void> _editDraft(BuildContext context, WidgetRef ref) async {
    final done = await showDialog<bool>(
      context: context,
      builder: (_) => _PricingDialog(
        requestId: request.id,
        items: _priceable(items),
        reviseFrom: entry,
        editDraft: true,
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
    this.editDraft = false,
  });

  final String requestId;
  final List<RequestItem> items;
  final QuotationWithLines? reviseFrom;

  /// With [reviseFrom] a draft: change it in place rather than issue the next
  /// version.
  final bool editDraft;

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
    final l = context.l10n;
    final discount = double.tryParse(_discount.text) ?? 0;
    final revising = widget.reviseFrom;

    return AlertDialog(
      title: Text(revising == null
          ? l.priceTheWork
          : widget.editDraft
              ? l.editDraftTitle(revising.quotation.version)
              : l.reviseTitle(revising.quotation.version)),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.leaveBlank, style: context.text.bodySmall),
              const SizedBox(height: Space.md),
              for (final item in widget.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            UserText(item.name,
                                style: context.text.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w500)),
                            UserText(item.quantityLabel,
                                style: context.text.bodySmall),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 150,
                        child: TextField(
                          controller: _prices[item.id],
                          keyboardType: TextInputType.number,
                          textDirection: TextDirection.ltr,
                          decoration: InputDecoration(
                            isDense: true,
                            labelText: l.unitPrice,
                            suffixText: Fmt.currency,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      SizedBox(
                        width: 120,
                        child: Text(
                          () {
                            final p = double.tryParse(_prices[item.id]!.text);
                            return p == null
                                ? '—'
                                : Fmt.amount(p * item.quantity);
                          }(),
                          textAlign: TextAlign.end,
                          style: context.text.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 28),
              Row(
                children: [
                  Expanded(child: Text(l.discount)),
                  SizedBox(
                    width: 150,
                    child: TextField(
                      controller: _discount,
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.ltr,
                      decoration: InputDecoration(
                        isDense: true,
                        suffixText: Fmt.currency,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 120),
                ],
              ),
              const SizedBox(height: Space.lg),
              Container(
                padding: const EdgeInsets.all(Space.md),
                decoration: BoxDecoration(
                  color: context.colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(l.total, style: context.text.titleSmall),
                    ),
                    Text(
                      Fmt.money(
                          (_subtotal - discount).clamp(0, double.infinity)),
                      style: context.text.titleLarge,
                    ),
                  ],
                ),
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
          child: Text(revising == null
              ? l.create
              : widget.editDraft
                  ? l.save
                  : l.createVersion(revising.quotation.version + 1)),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final l = context.l10n;
    final lines = <NewQuotationLine>[];
    for (final item in widget.items) {
      final price = double.tryParse(_prices[item.id]!.text);
      if (price != null) {
        lines.add(NewQuotationLine(requestItemId: item.id, unitPrice: price));
      }
    }
    if (lines.isEmpty) {
      showError(context, l.priceAtLeastOne);
      return;
    }

    setState(() => _busy = true);
    final repo = ref.read(quotationRepositoryProvider);
    final discount = double.tryParse(_discount.text) ?? 0;

    final ok = await runAction(
      context,
      () async {
        if (widget.editDraft) {
          await repo.editDraft(
            quotationId: widget.reviseFrom!.quotation.id,
            lines: lines,
            discount: discount,
          );
        } else if (widget.reviseFrom == null) {
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
      success: l.quotationSaved,
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
    final l = context.l10n;
    final payments = ref.watch(requestPaymentsProvider(request.id));

    return SectionCard(
      icon: Icons.payments_outlined,
      title: l.paymentsTitle,
      actions: [
        TextButton.icon(
          onPressed: () => _record(context, ref),
          icon: const Icon(Icons.add_rounded, size: 16),
          label: Text(l.recordPayment),
        ),
      ],
      child: AsyncView(
        value: payments,
        compact: true,
        onRetry: () => ref.invalidate(requestPaymentsProvider(request.id)),
        builder: (list) {
          if (list.isEmpty) {
            return Text(l.nothingReceived, style: context.text.bodySmall);
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < list.length; i++) ...[
                if (i > 0) const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: context.tokens.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(Radii.sm),
                        ),
                        child: Icon(_methodIcon(list[i].method),
                            size: 16, color: context.tokens.success),
                      ),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(Fmt.money(list[i].amount),
                                style: context.text.titleSmall),
                            Text(
                              [
                                list[i].method.tr(l),
                                Fmt.date(list[i].paidAt),
                                if (list[i].reference != null)
                                  list[i].reference!,
                              ].join('  ·  '),
                              style: context.text.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      StatusBadge(list[i].kind.tr(l)),
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

  static IconData _methodIcon(PaymentMethod m) => switch (m) {
        PaymentMethod.cash => Icons.payments_outlined,
        PaymentMethod.online => Icons.credit_card_rounded,
        PaymentMethod.bankTransfer => Icons.account_balance_outlined,
        PaymentMethod.cheque => Icons.receipt_long_outlined,
      };

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
  final _formKey = GlobalKey<FormState>();
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
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.recordPaymentTitle),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppField(
                controller: _amount,
                autofocus: true,
                keyboardType: TextInputType.number,
                fixedDirection: TextDirection.ltr,
                label: l.amount,
                suffix: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(Fmt.currency, style: context.text.bodyMedium),
                ),
                validator: (v) {
                  final a = double.tryParse(v ?? '');
                  return (a == null || a <= 0) ? l.enterAmount : null;
                },
              ),
              const SizedBox(height: Space.md),
              Text(l.how, style: context.text.labelLarge),
              const SizedBox(height: Space.sm),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final m in PaymentMethod.values)
                    ChoiceChip(
                      label: Text(m.tr(l)),
                      selected: _method == m,
                      onSelected: (_) => setState(() => _method = m),
                    ),
                ],
              ),
              const SizedBox(height: Space.lg),
              DropdownButtonFormField<PaymentKind>(
                initialValue: _kind,
                decoration: InputDecoration(
                  labelText: l.whatItIs,
                ),
                items: [
                  for (final k in PaymentKind.values)
                    DropdownMenuItem(value: k, child: Text(k.tr(l))),
                ],
                onChanged: (k) => setState(() => _kind = k ?? _kind),
              ),
              const SizedBox(height: Space.md),
              AppField(
                controller: _reference,
                label: l.reference,
                hint: l.referenceHint,
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
          child: Text(l.record),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l = context.l10n;
    final amount = double.parse(_amount.text);

    // Payments are permanent. One look at the figure before it is written.
    final sure = await confirm(
      context,
      title: l.confirmPaymentTitle(Fmt.money(amount)),
      body: l.confirmPaymentBody(_kind.tr(l), _method.tr(l)),
      confirmLabel: l.record,
      icon: Icons.payments_outlined,
    );
    if (!sure || !mounted) return;

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
      success: l.paymentRecorded,
    );
    if (mounted) {
      setState(() => _busy = false);
      if (ok) Navigator.pop(context, true);
    }
  }
}

/// A cancelled product is not quoted again; everything else can be.
List<RequestItem> _priceable(List<RequestItem>? items) => [
      for (final i in items ?? const <RequestItem>[])
        if (i.status != ItemStatus.cancelled) i,
    ];
