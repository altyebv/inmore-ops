import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inmore_ui/inmore_ui.dart';
import 'package:inmore_ui/testing.dart';
import 'package:ops_desktop/features/help/help_content.dart';
import 'package:ops_desktop/shell/tour.dart';

import 'harness.dart';

/// The first-run tour and the help center: the tour starts once and only
/// once, each step lands on something real, and neither tells a role about
/// things it can't do. Frames go to `build/screenshots/desktop_tour_*.png`.
void main() {
  setUpAll(loadAppFonts);

  final en = lookupL10n(const Locale('en'));

  testWidgets('tour starts on first sign-in and is remembered', (tester) async {
    final key = GlobalKey();
    final prefs = await pumpDesktop(tester,
        location: '/', boundaryKey: key, tourSeen: false);

    // Waits for the launch intro before starting.
    expect(find.text(en.tourNext), findsNothing);
    await tester.pump(const Duration(milliseconds: 1500));
    await stepFrames(tester);
    expect(find.textContaining('Welcome to Inmore'), findsOneWidget);
    await capture(tester, key, 'desktop_tour_1_welcome_en');

    await tester.tap(find.text(en.tourNext));
    await stepFrames(tester);
    expect(find.text(en.tourBoardTitle), findsOneWidget);
    await capture(tester, key, 'desktop_tour_2_board_en');

    await tester.tap(find.text(en.tourNext));
    await stepFrames(tester);
    expect(find.text(en.tourNewRequestTitle), findsOneWidget);
    await capture(tester, key, 'desktop_tour_3_new_request_en');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await closeFrames(tester);
    expect(find.text(en.tourNext), findsNothing);
    expect(prefs.getBool('tour.seen.${Sample.supervisor.id}'), isTrue);
  });

  testWidgets('tour does not start again once seen', (tester) async {
    await pumpDesktop(tester, location: '/', boundaryKey: GlobalKey());
    await tester.pump(const Duration(milliseconds: 2000));
    expect(find.text(en.tourNext), findsNothing);
  });

  testWidgets('tour in Arabic, right to left', (tester) async {
    final key = GlobalKey();
    await pumpDesktop(tester,
        location: '/',
        boundaryKey: key,
        locale: const Locale('ar'),
        mode: ThemeMode.dark,
        tourSeen: false);
    await tester.pump(const Duration(milliseconds: 1500));
    await stepFrames(tester);

    final ar = lookupL10n(const Locale('ar'));
    // Welcome, board, new request, my work, search, customers.
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text(ar.tourNext));
      await stepFrames(tester);
    }
    expect(find.text(ar.tourCustomersTitle), findsWidgets);
    await capture(tester, key, 'desktop_tour_customers_ar_dark');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await closeFrames(tester);
    expect(find.text(ar.tourNext), findsNothing);
  });

  testWidgets('the last step closes the tour', (tester) async {
    await pumpDesktop(tester,
        location: '/', boundaryKey: GlobalKey(), tourSeen: false);
    await tester.pump(const Duration(milliseconds: 1500));
    await stepFrames(tester);
    while (find.text(en.tourNext).evaluate().isNotEmpty) {
      await tester.tap(find.text(en.tourNext));
      await stepFrames(tester);
    }
    expect(find.text(en.tourAccountTitle), findsOneWidget);
    await tester.tap(find.text(en.tourDone));
    await closeFrames(tester);
    expect(find.text(en.tourDone), findsNothing);
  });

  test('tour steps follow the role', () {
    final supervisor = tourSteps(en, Sample.supervisor).map((s) => s.title);
    final designer = tourSteps(en, Sample.designer).map((s) => s.title);
    expect(supervisor, contains(en.tourNewRequestTitle));
    expect(supervisor, contains(en.tourReportsTitle));
    expect(designer, isNot(contains(en.tourNewRequestTitle)));
    expect(designer, isNot(contains(en.tourReportsTitle)));
    expect(designer, contains(en.tourHomeWorkTitle));
  });

  test('help only shows what the role can do', () {
    List<String> ids(List<HelpSection> s) => [
          for (final sec in s)
            for (final a in sec.articles) '${sec.id}/${a.id}'
        ];
    final designer = ids(helpFor(Sample.designer));
    final supervisor = ids(helpFor(Sample.supervisor));

    expect(designer, isNot(contains('money/quote')));
    expect(designer, isNot(contains('reports/export')));
    expect(designer, isNot(contains('requests/new')));
    expect(designer, contains('work/owntask'));
    expect(designer, contains('work/mywork'));

    expect(supervisor, contains('money/payment'));
    expect(supervisor, contains('reports/export'));
    expect(supervisor, isNot(contains('work/owntask')));
  });

  test('every help text is written in both languages', () {
    final arabic = RegExp(r'[؀-ۿ]');
    for (final s in helpSections) {
      final texts = [
        s.title,
        for (final a in s.articles) ...[
          a.title,
          for (final b in a.blocks) ...b.texts,
        ],
      ];
      for (final t in texts) {
        expect(t.en.trim(), isNotEmpty, reason: t.ar);
        expect(arabic.hasMatch(t.ar), isTrue, reason: t.en);
      }
    }
  });

  test('help search matches words in the reader’s language', () {
    final payment = helpSections
        .expand((s) => s.articles)
        .firstWhere((a) => a.id == 'payment');
    expect(payment.matches('record payment', const Locale('en')), isTrue);
    expect(payment.matches('دفعة', const Locale('ar')), isTrue);
    expect(payment.matches('excel', const Locale('en')), isFalse);
  });
}

/// The tour's fade-out starts on the frame after it is closed, and the route
/// is removed on the frame after that.
Future<void> closeFrames(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// A step's card fades in and its spotlight moves starting on the frame after
/// the change; let both finish before looking.
Future<void> stepFrames(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}
