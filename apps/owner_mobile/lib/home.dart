import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inmore_core/inmore_core.dart';

import 'features/attention/attention_screen.dart';
import 'features/money/money_screen.dart';
import 'features/overview/overview_screen.dart';
import 'features/people/people_screen.dart';

/// Four tabs, answering the four questions the owner actually asks:
/// what is happening, what needs me, where is the money, who is on what.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentEmployeeProvider).valueOrNull;

    // Money is owner and supervisor only. The tab is hidden for anyone else,
    // and RLS is what actually enforces it — the queries behind that tab come
    // back empty regardless.
    final showMoney = me?.role.canSeeMoney ?? false;

    final pages = <Widget>[
      const OverviewScreen(),
      const AttentionScreen(),
      if (showMoney) const MoneyScreen(),
      const PeopleScreen(),
    ];

    final destinations = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.insights_outlined),
        selectedIcon: Icon(Icons.insights),
        label: 'Overview',
      ),
      const NavigationDestination(
        icon: Icon(Icons.priority_high_outlined),
        selectedIcon: Icon(Icons.priority_high),
        label: 'Attention',
      ),
      if (showMoney)
        const NavigationDestination(
          icon: Icon(Icons.payments_outlined),
          selectedIcon: Icon(Icons.payments),
          label: 'Money',
        ),
      const NavigationDestination(
        icon: Icon(Icons.people_outline),
        selectedIcon: Icon(Icons.people),
        label: 'People',
      ),
    ];

    final index = _tab.clamp(0, pages.length - 1);

    return Scaffold(
      body: SafeArea(child: pages[index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        destinations: destinations,
        onDestinationSelected: (i) => setState(() => _tab = i),
      ),
    );
  }
}
