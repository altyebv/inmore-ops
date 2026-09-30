import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inmore_core/inmore_core.dart';

/// The landing screen. Empty in step 0 — requests arrive in step 2.
///
/// It reads `v_request_summary` rather than `requests` so that the money
/// boundary never has to be remembered at the call site: that view has no money
/// columns in it at all.
class BoardScreen extends ConsumerWidget {
  const BoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final employee = ref.watch(currentEmployeeProvider).valueOrNull;
    final isStaffSide = !(employee?.role.canManageRequests ?? false);

    return Scaffold(
      appBar: AppBar(
        title: Text(isStaffSide ? 'My Work' : 'Work board'),
        actions: [
          if (!isStaffSide)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                onPressed: null, // step 2
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New request'),
              ),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inbox_outlined,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                employee == null
                    ? 'Nothing here yet'
                    : 'Nothing here yet, ${employee.shortName}',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                isStaffSide
                    ? 'Tasks assigned to you will appear here.'
                    : 'Open requests will appear here once request creation '
                        'lands in step 2.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
