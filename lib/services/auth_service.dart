import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_client.dart';

class AuthService {
  SupabaseClient? get _client => getSupabaseClient();

  String _normalizeEmail(String email) => email.trim().toLowerCase();

  /// Registers a new user. The `handle_new_user` trigger in schema.sql
  /// auto-creates the matching `profiles` row from `data.name` / email.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is not initialized');
    }

    final normalizedEmail = _normalizeEmail(email);

    return client.auth.signUp(
      email: normalizedEmail,
      password: password,
      data: {'name': name},
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is not initialized');
    }

    final normalizedEmail = _normalizeEmail(email);

    return client.auth.signInWithPassword(
      email: normalizedEmail,
      password: password,
    );
  }

  Future<void> signOut() async {
    final client = _client;
    if (client == null) {
      return;
    }

    return client.auth.signOut();
  }

  User? get currentUser => _client?.auth.currentUser;

  /// Emits whenever auth state changes (sign in, sign out, token refresh).
  /// Use this to drive an AuthGate widget.
  Stream<AuthState> get authStateChanges {
    final client = _client;
    if (client == null) {
      return const Stream<AuthState>.empty();
    }

    return client.auth.onAuthStateChange;
  }
}
