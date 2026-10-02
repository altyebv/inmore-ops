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
import 'package:ops_desktop/features/help/help_screen.dart';
import 'package:ops_desktop/features/requests/new_request_screen.dart';
import 'package:ops_desktop/features/requests/request_detail_screen.dart';
import 'package:ops_desktop/features/work/my_work_screen.dart';
import 'package:ops_desktop/shell/app_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Draws the desktop app at [location] with sample data, signed in as
/// [employee], at a typical 1440×900 window. No database.
///
/// [tourSeen] is true by default so screen tests show the screen, not the
/// first-run tour.
Future<SharedPreferences> pumpDesktop(
  WidgetTester tester, {
  required String location,
  required GlobalKey boundaryKey,
  Locale locale = const Locale('en'),
  ThemeMode mode = ThemeMode.light,
  Employee employee = Sample.supervisor,
  bool tourSeen = true,
  RequestSummary? request,
}) async {
  tester.view
    ..physicalSize = const Size(1440, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({
    if (tourSeen) 'tour.seen.${employee.id}': true,
  });
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      settingsProvider.overrideWith(
          () => _Fixed(AppSettings(themeMode: mode, locale: locale))),
      currentUserIdProvider.overrideWithValue(employee.id),
      currentEmployeeProvider.overrideWith((ref) async => employee),
      realtimeSyncProvider.overrideWith((ref) {}),
      connectivityProvider.overrideWith((ref) => Stream.value(true)),
      boardProvider.overrideWith((ref) async => Sample.requests),
      myWorkProvider.overrideWith((ref) async => Sample.tasks),
      customerSearchProvider.overrideWith((ref, q) async => Sample.customers),
      activeEmployeesProvider.overrideWith((ref) async => Sample.staff),
      productsProvider.overrideWith((ref) async => const []),
      partnersProvider.overrideWith((ref) async => const []),
      requestProvider
          .overrideWith((ref, id) async => request ?? Sample.requests.first),
      requestItemsProvider.overrideWith((ref, id) async => Sample.items),
      requestFinancialsProvider
          .overrideWith((ref, id) async => Sample.financials),
      requestTasksProvider
          .overrideWith((ref, id) async => Sample.tasks.take(2).toList()),
      requestQuotationsProvider
          .overrideWith((ref, id) async => Sample.quotations),
      requestPaymentsProvider.overrideWith((ref, id) async => Sample.payments),
      requestActivityProvider.overrideWith((ref, id) async => Sample.activity),
    ],
    child: Consumer(
      builder: (context, ref, _) {
        final settings = ref.watch(settingsProvider);
        return RepaintBoundary(
          key: boundaryKey,
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

  // Let the overridden futures resolve; the progress bars animate forever,
  // so settle by time rather than pumpAndSettle.
  await settle(tester);
  return prefs;
}

/// Pumps by time, then decodes the logo: image loads finish outside the
/// test's fake clock, so without this the mark is sometimes missing.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.runAsync(() async {
    for (final e in find.byType(Image).evaluate()) {
      await precacheImage((e.widget as Image).image, e);
    }
  });
  await tester.pump();
}

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  final boundary =
      tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
  await tester.runAsync(() => savePng(boundary, name));
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
            GoRoute(path: '/help', builder: (_, __) => const HelpScreen()),
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
