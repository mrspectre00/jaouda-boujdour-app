import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'supabase_service.dart';

class AuthState {
  final Session? session;
  final User? user;
  final String? error;

  AuthState({this.session, this.user, this.error});

  AuthState copyWith({Session? session, User? user, String? error}) {
    return AuthState(
      session: session ?? this.session,
      user: user ?? this.user,
      error: error ?? this.error,
    );
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(supabaseProvider));
});

class AuthService {
  final SupabaseClient _supabase;

  AuthService(this._supabase);

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } catch (e) {
      throw Exception('Failed to sign in: $e');
    }
  }

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'name': name, 'role': 'vendor'},
      );
      return response;
    } catch (e) {
      throw Exception('Failed to sign up: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }

  User? get currentUser => _supabase.auth.currentUser;

  Stream<AuthState> get authStateChanges =>
      _supabase.auth.onAuthStateChange.map((data) {
        final event = data.event;
        final session = data.session;

        if (event == AuthChangeEvent.signedIn && session != null) {
          return AuthState(session: session, user: session.user, error: null);
        } else if (event == AuthChangeEvent.signedOut) {
          return AuthState(session: null, user: null, error: null);
        } else {
          return AuthState(session: session, user: session?.user, error: null);
        }
      });

  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      throw Exception('Failed to reset password: ${e.toString()}');
    }
  }
}
