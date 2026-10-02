import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inmore_core/inmore_core.dart';
import 'package:inmore_ui/inmore_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/snapshot_store.dart';
import 'features/auth/login_screen.dart';
import 'home.dart';

class OwnerApp extends ConsumerWidget {
  const OwnerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final signedIn =
        ref.watch(sessionRepositoryProvider).currentSession != null;
    final settings = ref.watch(settingsProvider);

    // Whatever was saved on the phone leaves with the person who saw it.
    ref.listen(authStateProvider, (_, next) {
      if (next.valueOrNull?.event == AuthChangeEvent.signedOut) {
        ref.read(snapshotStoreProvider).clear();
      }
    });

    return MaterialApp(
      title: 'Inmore',
      debugShowCheckedModeBanner: false,
      theme: InmoreTheme.light(),
      darkTheme: InmoreTheme.dark(),
      themeMode: settings.themeMode,
      locale: settings.locale,
      supportedLocales: supportedLocales,
      localizationsDelegates: L10n.localizationsDelegates,
      localeResolutionCallback: (device, _) =>
          resolveLocale(settings.locale, device),
      builder: (context, child) {
        syncFormatting(Localizations.localeOf(context));
        return child!;
      },
      // No router: the owner's app is four tabs and a detail page. go_router
      // would be ceremony around a Navigator.push.
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: auth.isLoading && !signedIn
            ? const BrandLoader()
            : (signedIn ? const HomeScreen() : const LoginScreen()),
      ),
    );
  }
}
