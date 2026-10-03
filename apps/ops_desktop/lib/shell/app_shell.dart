import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inmore_core/inmore_core.dart';
import 'package:inmore_ui/inmore_ui.dart';

import 'command_palette.dart';
import 'refresh.dart';
import 'tour.dart';

/// Whether the sidebar is folded to icons. Remembered on this PC.
final sidebarCollapsedProvider = StateProvider<bool>(
  (ref) => ref.read(sharedPreferencesProvider).getBool(_collapsedKey) ?? false,
);
const _collapsedKey = 'shell.collapsed';

/// The persistent frame: sidebar, offline banner, keyboard shortcuts, and the
/// live connection that keeps every screen current.
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
    // Opens the realtime channel for whoever is signed in; closes it on
    // sign-out.
    ref.watch(realtimeSyncProvider);

    return employee.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () => const BrandLoader(),
      error: (error, _) => _AccountProblem(error: error),
      data: (me) {
        if (me == null) return const BrandLoader();
        // The first time this person signs in on this computer, walk them
        // round the shell.
        return TourAutoStart(
          employee: me,
          child: ConnectionWatcher(
            onRefresh: refreshAll,
            child: _Shortcuts(
              employee: me,
              child: Scaffold(
                body: Row(
                  children: [
                    _Sidebar(employee: me),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: Column(
                        children: [
                          const OfflineBanner(),
                          Expanded(child: child),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Ctrl+K to find a request, Ctrl+N for a new one, F5 to refresh, F1 for
/// help.
class _Shortcuts extends ConsumerWidget {
  const _Shortcuts({required this.employee, required this.child});

  final Employee employee;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
            showCommandPalette(context),
        if (employee.role.canManageRequests)
          const SingleActivator(LogicalKeyboardKey.keyN, control: true): () =>
              context.go('/requests/new'),
        const SingleActivator(LogicalKeyboardKey.f1): () => context.go('/help'),
        const SingleActivator(LogicalKeyboardKey.f5): () => refreshAll(ref),
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): () =>
            refreshAll(ref),
      },
      child: Focus(autofocus: true, child: child),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.employee});

  final Employee employee;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final collapsed = ref.watch(sidebarCollapsedProvider);
    final location = GoRouterState.of(context).matchedLocation;
    final manages = employee.role.canManageRequests;
    final myWorkCount = ref.watch(myWorkProvider).valueOrNull?.length ?? 0;

    void toggle() {
      final next = !collapsed;
      ref.read(sidebarCollapsedProvider.notifier).state = next;
      ref.read(sharedPreferencesProvider).setBool(_collapsedKey, next);
    }

    final items = [
      _NavItem(
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard_rounded,
        label: manages ? l.navBoard : l.navMyWork,
        path: '/',
        anchor: TourKeys.home,
        badge: manages ? null : myWorkCount,
      ),
      if (manages)
        _NavItem(
          icon: Icons.task_alt_outlined,
          selectedIcon: Icons.task_alt_rounded,
          label: l.navMyWork,
          path: '/work',
          anchor: TourKeys.myWork,
          badge: myWorkCount,
        ),
      _NavItem(
        icon: Icons.people_outline_rounded,
        selectedIcon: Icons.people_rounded,
        label: l.navCustomers,
        path: '/customers',
        anchor: TourKeys.customers,
      ),
      _NavItem(
        icon: Icons.inventory_2_outlined,
        selectedIcon: Icons.inventory_2_rounded,
        label: l.navInventory,
        path: '/inventory',
        anchor: TourKeys.inventory,
      ),
      // Money. The nav hides it; RLS is what actually stops it.
      if (employee.role.canSeeMoney) ...[
        _NavItem(
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long_rounded,
          label: l.navExpenses,
          path: '/expenses',
          anchor: TourKeys.expenses,
        ),
        _NavItem(
          icon: Icons.table_chart_outlined,
          selectedIcon: Icons.table_chart_rounded,
          label: l.navReports,
          path: '/reports',
          anchor: TourKeys.reports,
        ),
      ],
      if (manages)
        _NavItem(
          icon: Icons.badge_outlined,
          selectedIcon: Icons.badge_rounded,
          label: l.navStaff,
          path: '/staff',
          anchor: TourKeys.staff,
        ),
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: collapsed ? 76 : 248,
      color: context.colors.surfaceContainerLow,
      child: ClipRect(
        child: OverflowBox(
          alignment: AlignmentDirectional.topStart,
          minWidth: collapsed ? 76 : 248,
          maxWidth: collapsed ? 76 : 248,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Brand(collapsed: collapsed),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: KeyedSubtree(
                  key: TourKeys.search,
                  child: _SearchButton(collapsed: collapsed),
                ),
              ),
              const SizedBox(height: Space.md),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final item in items)
                      _NavTile(
                        item: item,
                        selected: location == item.path ||
                            (item.path == '/' &&
                                location.startsWith('/requests')),
                        collapsed: collapsed,
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _NavTile(
                  item: _NavItem(
                    icon: Icons.help_outline_rounded,
                    selectedIcon: Icons.help_rounded,
                    label: l.navHelp,
                    path: '/help',
                    anchor: TourKeys.help,
                  ),
                  selected: location == '/help',
                  collapsed: collapsed,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _NavTile(
                  item: _NavItem(
                    icon: collapsed
                        ? Icons.keyboard_double_arrow_right_rounded
                        : Icons.keyboard_double_arrow_left_rounded,
                    selectedIcon: Icons.keyboard_double_arrow_left_rounded,
                    label: collapsed ? l.expandSidebar : l.collapseSidebar,
                    path: '',
                  ),
                  selected: false,
                  collapsed: collapsed,
                  onTap: toggle,
                  mirrorIcon: true,
                ),
              ),
              const Divider(height: 17, indent: 12, endIndent: 12),
              KeyedSubtree(
                key: TourKeys.account,
                child: _Account(employee: employee, collapsed: collapsed),
              ),
              const SizedBox(height: Space.sm),
            ],
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.collapsed});

  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(collapsed ? 22 : 20, 22, 16, 18),
      child: Row(
        children: [
          const InmoreMark(height: 28),
          if (!collapsed) ...[
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.appName, style: context.text.titleMedium),
                  Text(l.opsTagline,
                      style: context.text.labelSmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SearchButton extends StatelessWidget {
  const _SearchButton({required this.collapsed});

  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    if (collapsed) {
      return IconButton(
        tooltip: '${l.searchEverything}  (Ctrl K)',
        onPressed: () => showCommandPalette(context),
        icon: const Icon(Icons.search_rounded),
      );
    }
    return Material(
      color: c.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: BorderSide(color: c.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: () => showCommandPalette(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              Icon(Icons.search_rounded, size: 18, color: c.onSurfaceVariant),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(l.searchEverything,
                    style: context.text.bodyMedium
                        ?.copyWith(color: c.onSurfaceVariant)),
              ),
              const KeyCap('Ctrl K'),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.path,
    this.badge,
    this.anchor,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String path;
  final int? badge;

  /// Set when the tour points at this item.
  final GlobalKey? anchor;
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.selected,
    required this.collapsed,
    this.onTap,
    this.mirrorIcon = false,
  });

  final _NavItem item;
  final bool selected;
  final bool collapsed;
  final VoidCallback? onTap;

  /// Arrows point the other way in a right-to-left layout.
  final bool mirrorIcon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = selected ? c.onSecondaryContainer : c.onSurfaceVariant;
    final badge = item.badge ?? 0;

    Widget icon =
        Icon(selected ? item.selectedIcon : item.icon, size: 20, color: fg);
    if (mirrorIcon && Directionality.of(context) == TextDirection.rtl) {
      icon = Transform.flip(flipX: true, child: icon);
    }
    if (collapsed && badge > 0) {
      icon = Badge(
        label: Text('$badge'),
        backgroundColor: c.secondary,
        textColor: c.onSecondary,
        child: icon,
      );
    }

    final tile = Material(
      color: selected ? c.secondaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(Radii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: onTap ?? () => context.go(item.path),
        child: SizedBox(
          height: 42,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 12),
            child: Row(
              mainAxisAlignment: collapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                icon,
                if (!collapsed) ...[
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Text(
                      item.label,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyMedium?.copyWith(
                        color: selected ? c.onSecondaryContainer : c.onSurface,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (badge > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 1),
                      decoration: BoxDecoration(
                        color: selected
                            ? c.surfaceContainerLowest
                            : c.secondaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$badge',
                          style: context.text.labelSmall
                              ?.copyWith(color: c.onSecondaryContainer)),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    final padded = Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: collapsed ? Tooltip(message: item.label, child: tile) : tile,
    );
    return item.anchor == null
        ? padded
        : KeyedSubtree(key: item.anchor, child: padded);
  }
}

class _Account extends ConsumerWidget {
  const _Account({required this.employee, required this.collapsed});

  final Employee employee;
  final bool collapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: MenuAnchor(
        alignmentOffset: const Offset(0, 4),
        menuChildren: [
          MenuItemButton(
            leadingIcon: const Icon(Icons.tune_rounded, size: 18),
            onPressed: () => showSettingsDialog(context),
            child: Text(l.settings),
          ),
          MenuItemButton(
            leadingIcon: const Icon(Icons.keyboard_outlined, size: 18),
            onPressed: () => _showShortcuts(context),
            child: Text(l.shortcutsTitle),
          ),
          MenuItemButton(
            leadingIcon: const Icon(Icons.help_outline_rounded, size: 18),
            onPressed: () => context.go('/help'),
            child: Text(l.helpCenter),
          ),
          MenuItemButton(
            leadingIcon: const Icon(Icons.explore_outlined, size: 18),
            onPressed: () => startTour(context, ref),
            child: Text(l.takeTheTour),
          ),
          const Divider(),
          MenuItemButton(
            leadingIcon: const Icon(Icons.logout_rounded, size: 18),
            onPressed: () => ref.read(sessionRepositoryProvider).signOut(),
            child: Text(l.signOut),
          ),
        ],
        builder: (context, controller, _) => InkWell(
          borderRadius: BorderRadius.circular(Radii.md),
          onTap: () =>
              controller.isOpen ? controller.close() : controller.open(),
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: collapsed ? 0 : 8, vertical: 8),
            child: Row(
              mainAxisAlignment: collapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                InitialsAvatar(employee.fullName, size: 34),
                if (!collapsed) ...[
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        UserText(employee.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w500)),
                        Text(employee.role.tr(l),
                            style: context.text.labelSmall?.copyWith(
                              color: context.colors.onSurfaceVariant,
                            )),
                      ],
                    ),
                  ),
                  Icon(Icons.unfold_more_rounded,
                      size: 18, color: context.colors.onSurfaceVariant),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showShortcuts(BuildContext context) {
    final l = context.l10n;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.shortcutsTitle),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (keys, label) in [
                ('Ctrl K', l.shortcutSearch),
                ('Ctrl N', l.shortcutNewRequest),
                ('F5', l.shortcutRefresh),
                ('F1', l.shortcutHelp),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(child: Text(label)),
                      KeyCap(keys),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.close),
          ),
        ],
      ),
    );
  }
}

Future<void> showSettingsDialog(BuildContext context) => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.settings),
        content: const SizedBox(width: 400, child: SettingsPanel()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.close),
          ),
        ],
      ),
    );

/// Shown when the profile cannot be loaded — most often an account the owner
/// has not activated yet, which is a normal state, not a crash.
class _AccountProblem extends ConsumerWidget {
  const _AccountProblem({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final e = AppError.from(error);
    return Scaffold(
      body: EmptyState(
        icon: error is InactiveAccountException
            ? Icons.lock_clock_outlined
            : e.icon,
        title: l.accountProblemTitle,
        body: e.message(l),
        action: Wrap(
          spacing: Space.sm,
          children: [
            if (e.isRetryable)
              FilledButton.tonal(
                onPressed: () => ref.invalidate(currentEmployeeProvider),
                child: Text(l.retry),
              ),
            OutlinedButton(
              onPressed: () => ref.read(sessionRepositoryProvider).signOut(),
              child: Text(l.signOut),
            ),
          ],
        ),
      ),
    );
  }
}
