import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inmore_core/inmore_core.dart';
import 'package:inmore_ui/inmore_ui.dart';

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
    final l = context.l10n;
    final feed = ref.watch(requestActivityProvider(requestId));

    return SectionCard(
      icon: Icons.history_rounded,
      title: l.historyTitle,
      child: AsyncView(
        value: feed,
        compact: true,
        onRetry: () => ref.invalidate(requestActivityProvider(requestId)),
        builder: (entries) {
          if (entries.isEmpty) {
            return Text(l.nothingRecorded, style: context.text.bodySmall);
          }
          return Column(
            children: [
              for (var i = 0; i < entries.length; i++)
                TimelineEntry(entry: entries[i], last: i == entries.length - 1),
            ],
          );
        },
      ),
    );
  }
}
