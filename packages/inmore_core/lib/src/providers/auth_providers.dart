import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/session_repository.dart';
import '../models/employee.dart';

final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => SessionRepository(ref.watch(supabaseClientProvider)),
);

/// Emits on every sign-in, sign-out and token refresh.
final authStateProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(sessionRepositoryProvider).authStateChanges,
);

/// Who is signed in, as a plain id — the scope every cached read hangs off.
///
/// Riverpod keeps a provider's last value for as long as the app runs. On a
/// shared office PC that would mean a designer signing in after a supervisor
/// could be shown the supervisor's cached money panel without a single new
/// query. Every data provider watches this, so a change of user throws all of
/// it away. A token refresh emits on [authStateProvider] but leaves the id
/// unchanged, and a [Provider] only notifies when its value changes — so
/// refreshes do not trigger a refetch storm.
final currentUserIdProvider = Provider<String?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(sessionRepositoryProvider).currentUserId;
});

/// The signed-in employee, or null when signed out.
///
/// Watches [currentUserIdProvider] so it reloads itself on sign-in and clears
/// on sign-out — nothing has to remember to invalidate it.
final currentEmployeeProvider = FutureProvider<Employee?>((ref) async {
  ref.watch(currentUserIdProvider);
  return ref.watch(sessionRepositoryProvider).loadCurrentEmployee();
});
