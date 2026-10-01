import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inmore_core/inmore_core.dart';

/// The persistent frame: left nav, current user, sign out.
///
/// Nav items are role-shaped. This is presentation only — a designer who
/// reached a money screen anyway would still get zero rows, because the real
/// boundary is RLS, not this list.
class AppShell extends ConsumerWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employee = ref.watch(currentEmployeeProvider);

    return employee.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => _AccountProblem(message: error.toString()),
      data: (me) {
        if (me == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return Scaffold(
          body: Row(
            children: [
              _NavRail(employee: me),
              const VerticalDivider(width: 1),
              Expanded(child: child),
            ],
          ),
        );
      },
    );
  }
}

class _NavRail extends ConsumerWidget {
  const _NavRail({required this.employee});

  final Employee employee;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final location = GoRouterState.of(context).matchedLocation;
    final manages = employee.role.canManageRequests;

    return SizedBox(
      width: 232,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Inmore', style: theme.textTheme.titleLarge),
                Text(
                  'Operations',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                _NavItem(
                  icon: Icons.dashboard_outlined,
                  label: manages ? 'Work board' : 'My work',
                  path: '/',
                  current: location,
                ),
                if (manages)
                  _NavItem(
                    icon: Icons.task_alt,
                    label: 'My work',
                    path: '/work',
                    current: location,
                  ),
                _NavItem(
                  icon: Icons.people_outline,
                  label: 'Customers',
                  path: '/customers',
                  current: location,
                ),
                // Money. The nav hides it; RLS is what actually stops it.
                if (employee.role.canSeeMoney)
                  _NavItem(
                    icon: Icons.table_chart_outlined,
                    label: 'Reports',
                    path: '/reports',
                    current: location,
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  child: Text(employee.shortName.characters.first),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee.fullName,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        employee.role.label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Sign out',
                  icon: const Icon(Icons.logout, size: 18),
                  onPressed: () =>
                      ref.read(sessionRepositoryProvider).signOut(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.path,
    required this.current,
  });

  final IconData icon;
  final String label;
  final String path;
  final String current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = current == path;
    return ListTile(
      dense: true,
      selected: selected,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      leading: Icon(icon, size: 20),
      title: Text(label, style: theme.textTheme.bodyMedium),
      onTap: () => context.go(path),
    );
  }
}

/// Shown when the profile cannot be loaded — most often an account the owner
/// has not activated yet, which is a normal state, not a crash.
class _AccountProblem extends ConsumerWidget {
  const _AccountProblem({required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_clock_outlined, size: 40),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => ref.read(sessionRepositoryProvider).signOut(),
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
