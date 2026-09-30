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

/// The signed-in employee, or null when signed out.
///
/// Watches [authStateProvider] so it reloads itself on sign-in and clears on
/// sign-out — nothing has to remember to invalidate it.
final currentEmployeeProvider = FutureProvider<Employee?>((ref) async {
  ref.watch(authStateProvider);
  return ref.watch(sessionRepositoryProvider).loadCurrentEmployee();
});
