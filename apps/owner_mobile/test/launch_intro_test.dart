import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inmore_ui/inmore_ui.dart';
import 'package:inmore_ui/testing.dart';

/// The launch intro: draws its key frames to `build/screenshots/`, and checks
/// it gets out of the way — the app underneath is never rebuilt, and nothing
/// plays when the phone asks for reduced motion.
void main() {
  setUpAll(loadAppFonts);

  Widget app(ThemeMode mode, {bool reduceMotion = false}) {
    return MediaQuery(
      data: MediaQueryData(
        size: const Size(390, 844),
        disableAnimations: reduceMotion,
      ),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: InmoreTheme.light(),
        darkTheme: InmoreTheme.dark(),
        themeMode: mode,
        builder: (context, child) => LaunchIntro(child: child!),
        home: const _Counter(),
      ),
    );
  }

  Future<void> precacheMark(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (final e in find.byType(Image).evaluate()) {
        await precacheImage((e.widget as Image).image, e);
      }
    });
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('intro frames, ${mode.name}', (tester) async {
      tester.view
        ..physicalSize = const Size(390 * 2, 844 * 2)
        ..devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final key = GlobalKey();

      await tester.pumpWidget(RepaintBoundary(key: key, child: app(mode)));
      await precacheMark(tester);

      // Mark alone (the splash hand-off), cyan landing, all four, fading out.
      var elapsed = 0;
      for (final at in [0, 330, 820, 1100]) {
        await tester.pump(Duration(milliseconds: at - elapsed));
        elapsed = at;
        final boundary =
            tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
        await tester.runAsync(() => savePng(
            boundary, 'mobile_intro_${mode.name}_${at}ms',
            pixelRatio: 2));
      }

      await tester.pumpAndSettle();
      expect(find.byType(InmoreMark), findsNothing);
    });
  }

  testWidgets('the app underneath keeps its state', (tester) async {
    await tester.pumpWidget(app(ThemeMode.light));
    final before = tester.state(find.byType(_Counter));

    // Taps during the intro land on the intro, not the app.
    await tester.tap(find.byType(_Counter), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('0'), findsOneWidget);

    expect(tester.state(find.byType(_Counter)), same(before));
    await tester.tap(find.byType(_Counter));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('reduced motion skips it', (tester) async {
    await tester.pumpWidget(app(ThemeMode.light, reduceMotion: true));
    expect(find.byType(InmoreMark), findsNothing);
    expect(find.text('0'), findsOneWidget);
  });
}

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  var _taps = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _taps++),
          child: Center(child: Text('$_taps')),
        ),
      );
}
