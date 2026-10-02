import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inmore_core/inmore_core.dart';
import 'package:inmore_ui/inmore_ui.dart';
import 'package:inmore_ui/testing.dart';

import 'harness.dart';

/// A closed request says how it ended and offers the way back, and nothing on
/// it can be edited until it is reopened.
void main() {
  setUpAll(loadAppFonts);

  RequestSummary closed(RequestStatus status, {String? reason}) =>
      RequestSummary.fromJson({
        ...Sample.requests.first.toJson(),
        'status': status.wire,
        'waiting_on': null,
        'completed_at': status == RequestStatus.completed
            ? DateTime(2026, 10, 1, 15).toUtc().toIso8601String()
            : null,
        'cancel_reason': reason,
      });

  testWidgets('completed request', (tester) async {
    final key = GlobalKey();
    final en = lookupL10n(const Locale('en'));
    await pumpDesktop(tester,
        location: '/requests/r1042',
        boundaryKey: key,
        request: closed(RequestStatus.completed));
    await capture(tester, key, 'desktop_request_completed_en_light');

    expect(find.textContaining('Completed 1 Oct 2026'), findsOneWidget);
    expect(find.text(en.reopen), findsOneWidget);
    expect(find.text(en.markCompleted), findsNothing);
    expect(find.text(en.addProduct), findsNothing);
    expect(find.text(en.blockedOn), findsNothing);
  });

  testWidgets('cancelled request, in Arabic', (tester) async {
    final key = GlobalKey();
    final ar = lookupL10n(const Locale('ar'));
    await pumpDesktop(tester,
        location: '/requests/r1042',
        boundaryKey: key,
        locale: const Locale('ar'),
        mode: ThemeMode.dark,
        request:
            closed(RequestStatus.cancelled, reason: 'Customer went elsewhere'));
    await capture(tester, key, 'desktop_request_cancelled_ar_dark');

    expect(find.text(ar.cancelledBecause('Customer went elsewhere')),
        findsOneWidget);
    expect(find.text(ar.reopen), findsOneWidget);
  });

  testWidgets('a designer sees how it ended but cannot reopen', (tester) async {
    final en = lookupL10n(const Locale('en'));
    await pumpDesktop(tester,
        location: '/requests/r1042',
        boundaryKey: GlobalKey(),
        employee: Sample.designer,
        request: closed(RequestStatus.completed));
    expect(find.textContaining('Completed'), findsWidgets);
    expect(find.text(en.reopen), findsNothing);
  });
}
