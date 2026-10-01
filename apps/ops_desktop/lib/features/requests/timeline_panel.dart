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
          Expanded(child: Text(activityDescription(entry))),
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

