import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inmore_core/inmore_core.dart';

import 'features/auth/login_screen.dart';
import 'features/board/board_screen.dart';
import 'shell/app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      // Read, don't watch: redirect runs during navigation and must not
      // subscribe. `refreshListenable` below is what re-runs it.
      final session = ref.read(sessionRepositoryProvider).currentSession;
      final signedIn = session != null;
      final onLogin = state.matchedLocation == '/login';

      if (!signedIn) return onLogin ? null : '/login';
      if (onLogin) return '/';
      return null;
    },
    refreshListenable: _AuthRefresh(ref),
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const BoardScreen(),
          ),
        ],
      ),
    ],
  );
});

/// Bridges Riverpod's auth stream to go_router's imperative refresh.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
  }
}
