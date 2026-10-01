import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inmore_core/inmore_core.dart';

import '../../widgets/common.dart';

/// The request's history, newest first.
///
/// Every entry was written by a database trigger, so this is what actually
/// happened rather than what a screen remembered to record. A designer sees
/// the same story with the quotation and payment entries absent — the read
/// policy filters them out rather than blanking them.
class TimelinePanel extends ConsumerWidget {
  const TimelinePanel({required this.requestId, super.key});

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(requestActivityProvider(requestId));

    return SectionCard(
      title: 'History',
      child: AsyncView(
        value: feed,
        builder: (entries) {
          if (entries.isEmpty) return const EmptyNote('Nothing recorded yet.');
          return Column(
            children: [for (final e in entries) _Entry(entry: e)],
          );
        },
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({required this.entry});

  final ActivityEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(_icon(entry.eventType),
                size: 15, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(describe(entry))),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: Text(entry.actorName,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
                overflow: TextOverflow.ellipsis),
          ),
          SizedBox(
            width: 140,
            child: Text(Fmt.timelineStamp(entry.occurredAt),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }

  static IconData _icon(String eventType) {
    if (eventType.startsWith('payment')) return Icons.payments_outlined;
    if (eventType.startsWith('quotation')) return Icons.request_quote_outlined;
    if (eventType.startsWith('task')) return Icons.check_circle_outline;
    if (eventType.startsWith('item')) return Icons.inventory_2_outlined;
    if (eventType.contains('waiting')) return Icons.pause_circle_outline;
    if (eventType.contains('cancel')) return Icons.block;
    if (eventType.contains('complete')) return Icons.flag_outlined;
    return Icons.circle_outlined;
  }
}

/// Turn an event row into a sentence.
///
/// Deliberately reads the stored `from`/`to` rather than re-deriving anything:
/// the log is the record, and a description that disagrees with it would be
/// worse than a terse one.
String describe(ActivityEntry e) {
  String enumLabel(String? wire) {
    if (wire == null) return '—';
    return wire
        .split('_')
        .map((w) =>
            w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }

  final money = e.metadata['amount'];
  final moneyText =
      money == null ? '' : ' ${Fmt.money(num.tryParse('$money'))}';

  return switch (e.eventType) {
    'request.created' => 'Request created',
    'request.status_changed' =>
      'Moved from ${enumLabel(e.fromValue)} to ${enumLabel(e.toValue)}',
    'request.waiting_set' => 'Blocked: waiting on ${enumLabel(e.toValue)}',
    'request.waiting_cleared' => 'Unblocked',
    'request.supervisor_changed' => 'Supervisor changed',
    'request.completed' => 'Request completed',
    'request.cancelled' =>
      'Request cancelled — ${e.metadata['reason'] ?? 'no reason given'}',
    'request.reopened' => 'Reopened from ${enumLabel(e.fromValue)}',
    'item.added' => 'Added ${e.toValue}',
    'item.removed' => 'Removed ${e.fromValue}',
    'item.decision_changed' =>
      '${e.metadata['item'] ?? 'Item'}: ${enumLabel(e.toValue).toLowerCase()}',
    'quotation.created' => 'Quotation v${e.toValue} drafted',
    'quotation.presented' => 'Quotation told to the customer$moneyText',
    'quotation.approved' => 'Customer approved$moneyText',
    'quotation.rejected' => 'Customer rejected$moneyText',
    'quotation.superseded' => 'Quotation replaced by a new version',
    'task.created' => 'Work added: ${e.toValue}',
    'task.assigned' => 'Work assigned',
    'task.partner_assigned' => 'Sent to an external partner',
    'task.status_changed' => 'Work ${enumLabel(e.toValue).toLowerCase()}',
    'task.completed' => 'Work finished',
    'task_cost.recorded' => 'External cost recorded$moneyText',
    'payment.recorded' =>
      'Payment received$moneyText (${enumLabel('${e.metadata['method']}')})',
    'customer.created' => 'Customer created',
    'customer.updated' => 'Customer details updated',
    _ => e.eventType,
  };
}
