import 'package:flutter/material.dart';
import 'package:inmore_core/inmore_core.dart';

import '../l10n/labels.dart';
import '../theme/tokens.dart';

/// One event: a coloured node on a vertical rail, the sentence, who and when.
class TimelineEntry extends StatelessWidget {
  const TimelineEntry({required this.entry, this.last = false, super.key});

  final ActivityEntry entry;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (icon, colour) = _style(context, entry.eventType);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: colour.withValues(alpha: 0.13),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 14, color: colour),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: context.colors.outlineVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 3, bottom: last ? 0 : Space.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(activityDescription(entry, l),
                      style: context.text.bodyMedium),
                  const SizedBox(height: 2),
                  Text(
                    '${entry.actorName} · ${l.stamp(entry.occurredAt)}',
                    style: context.text.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static (IconData, Color) _style(BuildContext context, String event) {
    final t = context.tokens;
    if (event.startsWith('payment')) {
      return (Icons.payments_outlined, t.success);
    }
    if (event.startsWith('quotation')) {
      return (Icons.request_quote_outlined, t.stageQuotation);
    }
    if (event.startsWith('task')) return (Icons.handyman_outlined, t.info);
    if (event.startsWith('item')) {
      return (Icons.inventory_2_outlined, t.stageDesign);
    }
    if (event.contains('waiting_set')) {
      return (Icons.pause_circle_outline_rounded, t.danger);
    }
    if (event.contains('cancel')) return (Icons.block_rounded, t.danger);
    if (event.contains('complete')) return (Icons.flag_rounded, t.success);
    if (event.contains('status_changed')) {
      return (Icons.arrow_forward_rounded, t.stageProduction);
    }
    return (Icons.circle_outlined, t.neutral);
  }
}
