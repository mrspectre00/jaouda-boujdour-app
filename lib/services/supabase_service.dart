import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Provider to access Supabase client throughout the app
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// Class to manage authentication state
class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;

  AuthState({this.user, this.isLoading = false, this.error});

  AuthState copyWith({
    User? user,
    bool? isLoading,
    String? error,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      user: clearUser ? null : user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }
}

// Authentication notifier to manage auth state
class AuthNotifier extends StateNotifier<AuthState> {
  final SupabaseClient _supabase;

  AuthNotifier({required SupabaseClient supabase})
      : _supabase = supabase,
        super(AuthState()) {
    // Check if user is already logged in
    _initialize();
  }

  Future<void> _initialize() async {
    state = state.copyWith(isLoading: true);

    try {
      final currentUser = _supabase.auth.currentUser;

      if (currentUser != null) {
        state = state.copyWith(user: currentUser, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(
        error: 'Error initializing auth: $e',
        isLoading: false,
      );
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      state = state.copyWith(user: response.user, isLoading: false);
    } on AuthException catch (e) {
      state = state.copyWith(error: e.message, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: 'Error signing in: $e', isLoading: false);
    }
  }

  Future<void> signUp({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      state = state.copyWith(user: response.user, isLoading: false);
    } on AuthException catch (e) {
      state = state.copyWith(error: e.message, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: 'Error signing up: $e', isLoading: false);
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _supabase.auth.signOut();
      state = state.copyWith(clearUser: true, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: 'Error signing out: $e', isLoading: false);
    }
  }

  Future<void> resetPassword({required String email}) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _supabase.auth.resetPasswordForEmail(email);
      state = state.copyWith(isLoading: false);
    } on AuthException catch (e) {
      state = state.copyWith(error: e.message, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        error: 'Error resetting password: $e',
        isLoading: false,
      );
    }
  }
}

// Provider for auth state throughout the app
final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return AuthNotifier(supabase: supabase);
});

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService();
});

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  final SupabaseClient client = Supabase.instance.client;

  // Authentication functions
  Future<void> signIn(String email, String password) async {
    await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }

  // Fetch the current session
  Session? get currentSession => client.auth.currentSession;

  // Check if user is authenticated
  bool get isAuthenticated => currentSession != null;

  // Get current user
  User? get currentUser => client.auth.currentUser;

  // Get user ID
  String? get currentUserId => currentUser?.id;

  // Function to invoke edge functions
  Future<dynamic> invokeFunction(String functionName,
      {Map<String, dynamic>? params}) async {
    final response = await client.functions.invoke(
      functionName,
      body: params,
    );

    if (response.status != 200) {
      throw Exception('Error invoking function: ${response.data}');
    }

    return response.data;
  }

  // Table references
  SupabaseQueryBuilder get marketsTable => client.from('markets');
  SupabaseQueryBuilder get vendorsTable => client.from('vendors');
  SupabaseQueryBuilder get productsTable => client.from('products');
  SupabaseQueryBuilder get dailyStockTable => client.from('vendor_daily_stock');

  GoTrueClient get auth => client.auth;

  Future<PostgrestList> from(String table) async {
    return await client.from(table).select();
  }

  Future<PostgrestList> insert(String table, Map<String, dynamic> data) async {
    return await client.from(table).insert(data);
  }

  Future<PostgrestList> update(
    String table,
    Map<String, dynamic> data, {
    required String column,
    required String value,
  }) async {
    return await client.from(table).update(data).eq(column, value);
  }

  Future<PostgrestList> delete(
    String table, {
    required String column,
    required String value,
  }) async {
    return await client.from(table).delete().eq(column, value);
  }
}

// Create a global instance
final supabaseService = SupabaseService();
