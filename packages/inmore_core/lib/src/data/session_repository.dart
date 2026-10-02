import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/employee.dart';

/// Sign-in and "who am I" against Supabase.
///
/// A concrete class with no interface behind it: there is exactly one
/// implementation, and an interface with one implementor is indirection rather
/// than abstraction (blueprint §F).
class SessionRepository {
  SessionRepository(this._client);

  final SupabaseClient _client;

  Session? get currentSession => _client.auth.currentSession;

  String? get currentUserId => _client.auth.currentUser?.id;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  /// The signed-in user's employee profile.
  ///
  /// Returns null when there is no session, and throws [InactiveAccountException]
  /// when the row exists but has not been activated by the owner. Those are
  /// genuinely different states: the second one is a person waiting on an admin,
  /// not a failed login, and the UI should say so.
  Future<Employee?> loadCurrentEmployee() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final row =
        await _client.from('employees').select().eq('id', userId).maybeSingle();

    if (row == null) throw const InactiveAccountException();

    final employee = Employee.fromJson(row);
    if (!employee.isActive) throw const InactiveAccountException();
    return employee;
  }
}

/// The account exists but the owner has not activated it yet.
///
/// `handle_new_auth_user()` creates every employee row inactive, so this is the
/// normal state of a brand-new account, not an error condition.
class InactiveAccountException implements Exception {
  const InactiveAccountException();

  @override
  String toString() =>
      'This account is not active yet. Ask the owner to activate it.';
}
