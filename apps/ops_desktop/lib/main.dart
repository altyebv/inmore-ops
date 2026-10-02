import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inmore_ui/inmore_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrapUi();

  // It should feel like an installed tool, not a browser tab.
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      size: Size(1440, 900),
      minimumSize: Size(1100, 700),
      center: true,
      title: 'Inmore Operations',
      titleBarStyle: TitleBarStyle.normal,
    ),
  );

  // Loaded before the first frame so the window opens in the chosen theme
  // and language rather than flashing the defaults.
  final prefs = await SharedPreferences.getInstance();

  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabasePublishableKey,
  );

  runApp(ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const InmoreOpsApp(),
  ));

  // Shown once the first frame is drawn, not before: an earlier show() put
  // an empty window on screen for the whole Supabase start-up, and the launch
  // intro would then fade in over that instead of being the first thing seen.
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await windowManager.show();
    await windowManager.focus();
  });
}
