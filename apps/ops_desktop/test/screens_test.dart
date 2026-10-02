import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inmore_ui/testing.dart';

import 'harness.dart';

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
    ('/help', const Locale('en'), ThemeMode.light),
    ('/help', const Locale('ar'), ThemeMode.dark),
  ];

  for (final (location, locale, mode) in cases) {
    final name = 'desktop${location.replaceAll('/', '_')}'
        '_${locale.languageCode}_${mode.name}';

    testWidgets(name, (tester) async {
      final key = GlobalKey();
      await pumpDesktop(tester,
          location: location, boundaryKey: key, locale: locale, mode: mode);
      await capture(tester, key, name);
    });
  }
}
