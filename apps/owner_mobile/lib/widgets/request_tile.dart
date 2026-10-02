import 'package:flutter/material.dart';
import 'package:inmore_core/inmore_core.dart';
import 'package:inmore_ui/inmore_ui.dart';

import '../features/request/request_screen.dart';

/// One request in a list. Read-only: tapping opens the detail, nothing else.
///
/// The coloured edge is the stage, so a list can be scanned for "how much is
/// in production" without reading a word.
class RequestTile extends StatelessWidget {
  const RequestTile(this.request, {super.key});

  final RequestSummary request;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;
    final c = context.colors;
    final r = request;

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Card(
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => RequestScreen(requestId: r.id),
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: t.stage(r.status)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(r.reference,
                                style: context.text.labelLarge
                                    ?.copyWith(color: c.onSurfaceVariant)),
                            const SizedBox(width: Space.sm),
                            Expanded(
                              child: UserText(
                                r.customerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.text.titleSmall,
                              ),
                            ),
                            if (r.neededBy != null)
                              Text(
                                Fmt.dayMonth(r.neededBy),
                                style: context.text.labelMedium?.copyWith(
                                  color: r.isOverdue
                                      ? t.danger
                                      : c.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                        if (r.title != null) ...[
                          const SizedBox(height: 2),
                          UserText(
                            r.title!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodySmall,
                          ),
                        ],
                        const SizedBox(height: Space.sm),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            StatusBadge(r.status.tr(l),
                                color: t.stage(r.status), dot: true),
                            if (r.waitingOn != null)
                              StatusBadge(r.waitingOn!.tr(l),
                                  color: t.danger,
                                  icon: Icons.pause_circle_outline_rounded),
                            if (r.isOverdue)
                              StatusBadge(l.flagOverdue,
                                  color: t.danger,
                                  icon: Icons.schedule_rounded),
                            if (r.needsSupervisor)
                              StatusBadge(l.nobodyAssigned,
                                  color: t.warning,
                                  icon: Icons.person_off_outlined),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
