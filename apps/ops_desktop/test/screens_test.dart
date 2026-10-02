import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:inmore_core/inmore_core.dart';
import 'package:inmore_ui/inmore_ui.dart';
import 'package:inmore_ui/testing.dart';
import 'package:ops_desktop/features/auth/login_screen.dart';
import 'package:ops_desktop/features/board/board_screen.dart';
import 'package:ops_desktop/features/customers/customers_screen.dart';
import 'package:ops_desktop/features/export/export_screen.dart';
import 'package:ops_desktop/features/requests/new_request_screen.dart';
import 'package:ops_desktop/features/requests/request_detail_screen.dart';
import 'package:ops_desktop/features/work/my_work_screen.dart';
import 'package:ops_desktop/shell/app_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Draws every screen with sample data, in both languages and both themes.
///
/// Two jobs. It fails on any layout overflow — the usual way an Arabic label
/// that is longer than its English one breaks a row. And it writes each frame
/// to `build/screenshots/` so a change can be looked at without a database.
///
///   flutter test test/screens_test.dart
void main() {
  setUpAll(loadAppFonts);

  final cases = [
    ('/login', const Locale('en'), ThemeMode.light),
    ('/login', const Locale('ar'), ThemeMode.dark),
    ('/', const Locale('en'), ThemeMode.light),
    ('/', const Locale('en'), ThemeMode.dark),
    ('/', const Locale('ar'), ThemeMode.light),
    ('/requests/r1042', const Locale('en'), ThemeMode.light),
    ('/requests/r1042', const Locale('ar'), ThemeMode.dark),
    ('/requests/r1042', const Locale('ar'), ThemeMode.light),
    ('/work', const Locale('en'), ThemeMode.light),
    ('/work', const Locale('ar'), ThemeMode.light),
    ('/customers', const Locale('en'), ThemeMode.light),
    ('/requests/new', const Locale('ar'), ThemeMode.light),
    ('/reports', const Locale('en'), ThemeMode.dark),
  ];

  for (final (location, locale, mode) in cases) {
    final name = 'desktop${location.replaceAll('/', '_')}'
        '_${locale.languageCode}_${mode.name}';

    testWidgets(name, (tester) async {
      tester.view
        ..physicalSize = const Size(1440, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final key = GlobalKey();

      await tester.pumpWidget(ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith(
              () => _Fixed(AppSettings(themeMode: mode, locale: locale))),
          currentUserIdProvider.overrideWithValue(Sample.supervisor.id),
          currentEmployeeProvider
              .overrideWith((ref) async => Sample.supervisor),
          realtimeSyncProvider.overrideWith((ref) {}),
          connectivityProvider.overrideWith((ref) => Stream.value(true)),
          boardProvider.overrideWith((ref) async => Sample.requests),
          myWorkProvider.overrideWith((ref) async => Sample.tasks),
          customerSearchProvider
              .overrideWith((ref, q) async => Sample.customers),
          activeEmployeesProvider.overrideWith((ref) async => Sample.staff),
          productsProvider.overrideWith((ref) async => const []),
          partnersProvider.overrideWith((ref) async => const []),
          requestProvider
              .overrideWith((ref, id) async => Sample.requests.first),
          requestItemsProvider.overrideWith((ref, id) async => Sample.items),
          requestFinancialsProvider
              .overrideWith((ref, id) async => Sample.financials),
          requestTasksProvider
              .overrideWith((ref, id) async => Sample.tasks.take(2).toList()),
          requestQuotationsProvider
              .overrideWith((ref, id) async => Sample.quotations),
          requestPaymentsProvider
              .overrideWith((ref, id) async => Sample.payments),
          requestActivityProvider
              .overrideWith((ref, id) async => Sample.activity),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            final settings = ref.watch(settingsProvider);
            return RepaintBoundary(
              key: key,
              child: MaterialApp.router(
                debugShowCheckedModeBanner: false,
                theme: InmoreTheme.light(dense: true),
                darkTheme: InmoreTheme.dark(dense: true),
                themeMode: settings.themeMode,
                locale: settings.locale,
                supportedLocales: supportedLocales,
                localizationsDelegates: L10n.localizationsDelegates,
                builder: (context, child) {
                  syncFormatting(Localizations.localeOf(context));
                  return child!;
                },
                routerConfig: _router(location),
              ),
            );
          },
        ),
      ));

      // Let the overridden futures resolve; the progress bars animate
      // forever, so settle by time rather than pumpAndSettle.
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
      await tester.runAsync(() => savePng(boundary, name));
    });
  }
}

GoRouter _router(String location) => GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        ShellRoute(
          builder: (_, __, child) => AppShell(child: child),
          routes: [
            GoRoute(path: '/', builder: (_, __) => const BoardScreen()),
            GoRoute(path: '/work', builder: (_, __) => const MyWorkScreen()),
            GoRoute(
                path: '/customers',
                builder: (_, __) => const CustomersScreen()),
            GoRoute(path: '/reports', builder: (_, __) => const ExportScreen()),
            GoRoute(
                path: '/requests/new',
                builder: (_, __) => const NewRequestScreen()),
            GoRoute(
              path: '/requests/:id',
              builder: (_, s) =>
                  RequestDetailScreen(requestId: s.pathParameters['id']!),
            ),
          ],
        ),
      ],
    );

class _Fixed extends SettingsController {
  _Fixed(this.value);

  final AppSettings value;

  @override
  AppSettings build() => value;
}
