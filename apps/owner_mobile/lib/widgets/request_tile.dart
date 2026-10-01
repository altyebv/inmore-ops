import 'package:flutter/material.dart';
import 'package:inmore_core/inmore_core.dart';

import '../features/request/request_screen.dart';
import 'common.dart';

/// One request in a list. Read-only: tapping opens the detail, nothing else.
class RequestTile extends StatelessWidget {
  const RequestTile(this.request, {super.key});

  final RequestSummary request;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => RequestScreen(requestId: request.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(request.reference, style: theme.textTheme.labelMedium),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      request.customerName,
                      style: theme.textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (request.title != null)
                Text(
                  request.title!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  Pill(
                    request.status.label,
                    colour: stageColour(request.status, scheme),
                  ),
                  if (request.waitingOn != null)
                    Pill(
                      request.waitingOn!.label,
                      colour: Colors.red,
                      icon: Icons.pause_circle_outline,
                    ),
                  if (request.isOverdue)
                    Pill(
                      'Overdue',
                      colour: scheme.error,
                      icon: Icons.schedule,
                    ),
                  if (request.needsSupervisor)
                    const Pill(
                      'Nobody assigned',
                      colour: Colors.deepOrange,
                      icon: Icons.person_off_outlined,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    request.supervisorName ?? 'No supervisor',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    request.neededBy != null
                        ? 'Due ${Fmt.date(request.neededBy)}'
                        : Fmt.date(request.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: request.isOverdue
                          ? scheme.error
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
