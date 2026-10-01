import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inmore_core/inmore_core.dart';

import 'features/auth/login_screen.dart';
import 'features/board/board_screen.dart';
import 'features/customers/customers_screen.dart';
import 'features/export/export_screen.dart';
import 'features/requests/new_request_screen.dart';
import 'features/requests/request_detail_screen.dart';
import 'features/work/my_work_screen.dart';
import 'shell/app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      // Read, don't watch: redirect runs during navigation and must not
      // subscribe. `refreshListenable` below is what re-runs it.
      final signedIn =
          ref.read(sessionRepositoryProvider).currentSession != null;
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
          // Role-shaped landing: supervisors and the owner get the board,
          // designers and production get their own work.
          GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          GoRoute(
            path: '/work',
            builder: (context, state) => const MyWorkScreen(),
          ),
          GoRoute(
            path: '/customers',
            builder: (context, state) => const CustomersScreen(),
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ExportScreen(),
          ),
          GoRoute(
            path: '/requests/new',
            builder: (context, state) => const NewRequestScreen(),
          ),
          GoRoute(
            path: '/requests/:id',
            builder: (context, state) => RequestDetailScreen(
              requestId: state.pathParameters['id']!,
            ),
          ),
        ],
      ),
    ],
  );
});

/// Supervisors think in requests; designers and production think in tasks.
/// Landing them on different screens saves everyone a click, every time.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentEmployeeProvider).valueOrNull;
    if (me == null) return const BoardScreen();
    return me.role.canManageRequests
        ? const BoardScreen()
        : const MyWorkScreen();
  }
}

/// Bridges Riverpod's auth stream to go_router's imperative refresh.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
  }
}
