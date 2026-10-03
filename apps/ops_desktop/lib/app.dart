import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inmore_ui/inmore_ui.dart';

import 'router.dart';

class InmoreOpsApp extends ConsumerWidget {
  const InmoreOpsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final settings = ref.watch(settingsProvider);

    return MaterialApp.router(
      title: 'Inmore Operations',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: InmoreTheme.light(dense: true),
      darkTheme: InmoreTheme.dark(dense: true),
      themeMode: settings.themeMode,
      locale: settings.locale,
      supportedLocales: supportedLocales,
      localizationsDelegates: L10n.localizationsDelegates,
      localeResolutionCallback: (device, _) =>
          resolveLocale(settings.locale, device),
      builder: (context, child) {
        syncFormatting(Localizations.localeOf(context));
        return LaunchIntro(fadeInMark: true, markHeight: 96, child: child!);
      },
    );
  }
}
