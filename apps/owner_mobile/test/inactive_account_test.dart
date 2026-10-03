import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inmore_core/inmore_core.dart';
import 'package:inmore_ui/inmore_ui.dart';
import 'package:inmore_ui/testing.dart';
import 'package:owner_mobile/home.dart';

/// An inactive account reads nothing through RLS, so without this the phone
/// shows an empty overview and no reason why.
void main() {
  setUpAll(loadAppFonts);

  testWidgets('an inactive account is told so, not shown an empty overview',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue('someone'),
        currentEmployeeProvider.overrideWith(
            (ref) async => throw const InactiveAccountException()),
        realtimeSyncProvider.overrideWith((ref) {}),
        connectivityProvider.overrideWith((ref) => Stream.value(true)),
        ownerSnapshotProvider.overrideWith((ref) async => const OwnerSnapshot(
            open: [], completedThisWeek: [], arrivedThisWeek: [])),
        moneySnapshotProvider.overrideWith((ref) async => Sample.money),
        workloadProvider.overrideWith((ref) async => const <Workload>[]),
      ],
      child: const MaterialApp(
        supportedLocales: supportedLocales,
        localizationsDelegates: L10n.localizationsDelegates,
        home: HomeScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    final l = lookupL10n(const Locale('en'));
    expect(find.text(l.accountInactive), findsOneWidget);
    expect(find.text(l.signOut), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
