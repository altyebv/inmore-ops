import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inmore_core/inmore_core.dart';
import 'package:inmore_ui/inmore_ui.dart';

import 'data/cached.dart';
import 'features/attention/attention_screen.dart';
import 'features/money/money_screen.dart';
import 'features/overview/overview_screen.dart';
import 'features/people/people_screen.dart';

/// Which tab is showing. A provider so the overview's "Blocked" tile can jump
/// straight to Attention.
final homeTabProvider = StateProvider<int>((ref) => 0);

/// Four tabs, answering the four questions the owner actually asks:
/// what is happening, what needs me, where is the money, who is on what.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final employee = ref.watch(currentEmployeeProvider);
    final me = employee.valueOrNull;
    // Live updates while signed in; torn down on sign-out.
    ref.watch(realtimeSyncProvider);

    // An account that is not active reads nothing: every list comes back
    // empty, which looks exactly like a quiet day. Say so instead. Only this
    // error — a profile that failed to load offline must still fall through
    // to the saved overview.
    if (employee.error is InactiveAccountException) {
      return const _AccountInactive();
    }

    // Money is owner and supervisor only. The tab is hidden for anyone else,
    // and RLS is what actually enforces it — the queries behind that tab come
    // back empty regardless.
    final showMoney = me?.role.canSeeMoney ?? false;
    final attention =
        ref.watch(overviewProvider).valueOrNull?.value.attention.length ?? 0;

    final pages = <Widget>[
      const OverviewScreen(),
      const AttentionScreen(),
      if (showMoney) const MoneyScreen(),
      const PeopleScreen(),
    ];

    final destinations = <NavigationDestination>[
      NavigationDestination(
        icon: const Icon(Icons.insights_outlined),
        selectedIcon: const Icon(Icons.insights_rounded),
        label: l.tabOverview,
      ),
      NavigationDestination(
        icon: Badge(
          isLabelVisible: attention > 0,
          label: Text('$attention'),
          child: const Icon(Icons.notification_important_outlined),
        ),
        selectedIcon: Badge(
          isLabelVisible: attention > 0,
          label: Text('$attention'),
          child: const Icon(Icons.notification_important_rounded),
        ),
        label: l.tabAttention,
      ),
      if (showMoney)
        NavigationDestination(
          icon: const Icon(Icons.account_balance_wallet_outlined),
          selectedIcon: const Icon(Icons.account_balance_wallet_rounded),
          label: l.tabMoney,
        ),
      NavigationDestination(
        icon: const Icon(Icons.groups_outlined),
        selectedIcon: const Icon(Icons.groups_rounded),
        label: l.tabPeople,
      ),
    ];

    final index = ref.watch(homeTabProvider).clamp(0, pages.length - 1);

    return ConnectionWatcher(
      onRefresh: (ref) => refreshOwner(ref),
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const OfflineBanner(),
              // IndexedStack keeps each tab's scroll position when switching.
              Expanded(child: IndexedStack(index: index, children: pages)),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          destinations: destinations,
          onDestinationSelected: (i) =>
              ref.read(homeTabProvider.notifier).state = i,
        ),
      ),
    );
  }
}

/// Signed in, but the owner has not activated the account (or has switched it
/// off since).
class _AccountInactive extends ConsumerWidget {
  const _AccountInactive();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: EmptyState(
          icon: Icons.lock_clock_outlined,
          title: l.accountProblemTitle,
          body: l.accountInactive,
          action: Wrap(
            spacing: Space.sm,
            children: [
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
      ),
    );
  }
}
