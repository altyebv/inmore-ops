import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inmore_core/inmore_core.dart';

import 'features/auth/login_screen.dart';
import 'home.dart';

class OwnerApp extends ConsumerWidget {
  const OwnerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final signedIn =
        ref.watch(sessionRepositoryProvider).currentSession != null;

    return MaterialApp(
      title: 'Inmore',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      // No router: the owner's app is four tabs and a detail page. go_router
      // would be ceremony around a Navigator.push.
      home: auth.isLoading && !signedIn
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : (signedIn ? const HomeScreen() : const LoginScreen()),
    );
  }

  ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1F5F4B),
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      cardTheme: const CardThemeData(margin: EdgeInsets.zero),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );
  }
}
