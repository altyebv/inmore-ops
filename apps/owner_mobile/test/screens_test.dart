import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inmore_core/inmore_core.dart';
import 'package:inmore_ui/inmore_ui.dart';
import 'package:inmore_ui/testing.dart';
import 'package:owner_mobile/data/snapshot_store.dart';
import 'package:owner_mobile/features/auth/login_screen.dart';
import 'package:owner_mobile/features/request/request_screen.dart';
import 'package:owner_mobile/home.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Draws every screen of the owner's app with sample data, in both languages
/// and both themes, at a typical phone size. Fails on any layout overflow and
/// writes each frame to `build/screenshots/`.
///
///   flutter test test/screens_test.dart
void main() {
  setUpAll(loadAppFonts);

  final cases = <(String, Widget Function(), int, Locale, ThemeMode)>[
    ('login', LoginScreen.new, 0, const Locale('en'), ThemeMode.light),
    ('login', LoginScreen.new, 0, const Locale('ar'), ThemeMode.dark),
    ('overview', HomeScreen.new, 0, const Locale('en'), ThemeMode.light),
    ('overview', HomeScreen.new, 0, const Locale('ar'), ThemeMode.dark),
    ('overview', HomeScreen.new, 0, const Locale('ar'), ThemeMode.light),
    ('attention', HomeScreen.new, 1, const Locale('ar'), ThemeMode.light),
    ('login', LoginScreen.new, 0, const Locale('ar'), ThemeMode.light),
    ('attention', HomeScreen.new, 1, const Locale('en'), ThemeMode.light),
    ('money', HomeScreen.new, 2, const Locale('ar'), ThemeMode.light),
    ('people', HomeScreen.new, 3, const Locale('en'), ThemeMode.dark),
    (
      'request',
      () => const RequestScreen(requestId: 'r1042'),
      0,
      const Locale('en'),
      ThemeMode.light
    ),
    (
      'request',
      () => const RequestScreen(requestId: 'r1042'),
      0,
      const Locale('ar'),
      ThemeMode.dark
    ),
  ];

  for (final (screen, build, tab, locale, mode) in cases) {
    final name = 'mobile_${screen}_${locale.languageCode}_${mode.name}';

    testWidgets(name, (tester) async {
      tester.view
        ..physicalSize = const Size(390 * 2, 844 * 2)
        ..devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final key = GlobalKey();

      await tester.pumpWidget(ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentUserIdProvider.overrideWithValue(Sample.owner.id),
          currentEmployeeProvider.overrideWith((ref) async => Sample.owner),
          realtimeSyncProvider.overrideWith((ref) {}),
          connectivityProvider.overrideWith((ref) => Stream.value(true)),
          snapshotStoreProvider.overrideWithValue(_MemoryStore()),
          homeTabProvider.overrideWith((ref) => tab),
          ownerSnapshotProvider.overrideWith((ref) async => Sample.snapshot),
          moneySnapshotProvider.overrideWith((ref) async => Sample.money),
          workloadProvider.overrideWith((ref) async => Sample.workload),
          requestProvider
              .overrideWith((ref, id) async => Sample.requests.first),
          requestItemsProvider.overrideWith((ref, id) async => Sample.items),
          requestFinancialsProvider
              .overrideWith((ref, id) async => Sample.financials),
          requestTasksProvider
              .overrideWith((ref, id) async => Sample.tasks.take(2).toList()),
          requestActivityProvider
              .overrideWith((ref, id) async => Sample.activity),
        ],
        child: RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: InmoreTheme.light(),
            darkTheme: InmoreTheme.dark(),
            themeMode: mode,
            locale: locale,
            supportedLocales: supportedLocales,
            localizationsDelegates: L10n.localizationsDelegates,
            builder: (context, child) {
              syncFormatting(Localizations.localeOf(context));
              return child!;
            },
            home: build(),
          ),
        ),
      ));

      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Decode the logo before capturing: image loads finish outside the
      // test's fake clock, so without this the mark is sometimes missing.
      await tester.runAsync(() async {
        for (final e in find.byType(Image).evaluate()) {
          await precacheImage((e.widget as Image).image, e);
        }
      });
      await tester.pump();

      final boundary =
          tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
      await tester.runAsync(() => savePng(boundary, name, pixelRatio: 2));
    });
  }
}

/// Nothing saved, nothing kept — every case starts cold.
class _MemoryStore extends SnapshotStore {
  _MemoryStore() : super(const FlutterSecureStorage());

  @override
  Future<SavedSnapshot?> read(String userId, String name) async => null;

  @override
  Future<void> write(
    String userId,
    String name,
    Map<String, dynamic> data,
  ) async {}

  @override
  Future<void> clear() async {}
}
