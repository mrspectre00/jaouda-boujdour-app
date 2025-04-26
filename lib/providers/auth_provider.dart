import 'dart:async'; // Import for StreamSubscription
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart'; // Import for GoRouter
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';
import '../models/vendor.dart';
import '../services/supabase_client.dart';
import 'package:flutter/material.dart'; // For debugPrint

// Rename local state class to avoid conflict
class AuthNotifierState {
  final bool isAuthenticated;
  final bool isLoading;
  final String? error;
  final Vendor? vendor;
  final User? user;
  final bool isManagement;
  final LatLng? currentLocation;

  AuthNotifierState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.error,
    this.vendor,
    this.user,
    this.isManagement = false,
    this.currentLocation,
  });

  AuthNotifierState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    String? error,
    bool clearError = false, // Add flag to explicitly clear error
    Vendor? vendor,
    User? user,
    bool? isManagement,
    LatLng? currentLocation,
  }) {
    return AuthNotifierState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error,
      vendor: vendor ?? this.vendor,
      user: user ?? this.user,
      isManagement: isManagement ?? this.isManagement,
      currentLocation: currentLocation ?? this.currentLocation,
    );
  }
}

// Update the StateNotifier definition to use the new state class name
class AuthNotifier extends StateNotifier<AuthNotifierState> {
  AuthNotifier(this.ref) : super(AuthNotifierState()) {
    _listenToAuthStateChanges();
    _initialize();
  }

  final Ref ref;
  GoRouter? _router; // Hold reference to router for potential re-navigation
  StreamSubscription<AuthState>? _authStateSubscription;

  void setRouter(GoRouter router) {
    _router = router;
  }

  void _listenToAuthStateChanges() {
    _authStateSubscription?.cancel();

    _authStateSubscription = supabase.auth.onAuthStateChange.listen(
      (data) {
        final AuthChangeEvent event = data.event;
        final Session? session = data.session;
        debugPrint(
          '[Auth Listener] Event: $event, Session User: ${session?.user.id}, Current State User: ${state.user?.id}',
        );

        if (event == AuthChangeEvent.signedIn && session != null) {
          if (state.user?.id != session.user.id ||
              !state.isAuthenticated ||
              state.isLoading) {
            debugPrint(
              '[Auth Listener] SIGNED_IN detected, loading user data...',
            );
            Future.microtask(() async {
              if (state.user?.id != session.user.id || !state.isAuthenticated) {
                await _loadUserData(session.user);
              }
            });
          }
        } else if (event == AuthChangeEvent.signedOut) {
          debugPrint('[Auth Listener] SIGNED_OUT detected, resetting state.');
          if (state.isAuthenticated || state.user != null) {
            state = AuthNotifierState();
          }
        } else if (event == AuthChangeEvent.userUpdated) {
          debugPrint('[Auth Listener] USER_UPDATED detected.');
          if (session != null && state.isAuthenticated) {
            Future.microtask(() async {
              await _loadUserData(session.user);
            });
          }
        } else if (event == AuthChangeEvent.passwordRecovery) {
          debugPrint('[Auth Listener] PASSWORD_RECOVERY event.');
        } else if (event == AuthChangeEvent.tokenRefreshed) {
          debugPrint('[Auth Listener] TOKEN_REFRESHED event.');
        } else if (event == AuthChangeEvent.initialSession) {
          debugPrint(
            '[Auth Listener] INITIAL_SESSION event. Handled by _initialize.',
          );
        }
      },
      onError: (error) {
        debugPrint('[Auth Listener] Error: $error');
        state = state.copyWith(
          error: 'Auth listener error: $error',
          isLoading: false,
        );
      },
    );
  }

  Future<void> _initialize() async {
    debugPrint('[Auth Initialize] Starting...');
    // Use the persisted session from Supabase
    final Session? initialSession = supabase.auth.currentSession;

    if (initialSession != null) {
      debugPrint(
        '[Auth Initialize] Found initial session for user: ${initialSession.user.id}',
      );
      // Set loading state before async operation
      state = state.copyWith(isLoading: true, clearError: true);
      await _loadUserData(initialSession.user);
    } else {
      debugPrint('[Auth Initialize] No initial session found.');
      // Ensure state is clean if no session
      state = AuthNotifierState();
    }
  }

  Future<void> _loadUserData(User user) async {
    if (state.isLoading && state.user?.id == user.id && state.vendor != null) {
      debugPrint(
        '[Auth Load User] Already loading/loaded for ${user.id}, skipping.',
      );
      return;
    }
    debugPrint('[Auth Load User] Loading data for user: ${user.id}...');
    state = state.copyWith(
      isLoading: true,
      user: user,
      isAuthenticated: true,
      clearError: true,
    );

    try {
      // Fetch vendor data using user_id
      final vendorData = await supabase
          .from('vendors')
          .select('*, region:region_id(*)')
          .eq('user_id', user.id)
          .maybeSingle();

      if (vendorData != null) {
        final vendor = Vendor.fromJson(vendorData);
        debugPrint(
          '[Auth Load User] Found vendor data for ${user.id}. Is management: ${vendor.isManagement}',
        );
        state = state.copyWith(
          vendor: vendor,
          isManagement: vendor.isManagement,
          isLoading: false,
        );
      } else {
        debugPrint(
          '[Auth Load User] No vendor record found by user_id for ${user.id}. Checking by email...',
        );
        final email = user.email;
        if (email == null) {
          throw Exception('User email is null, cannot check vendor by email.');
        }

        final emailVendorData = await supabase
            .from('vendors')
            .select('*, region:region_id(*)')
            .eq('email', email) // Use non-null email
            .maybeSingle();

        if (emailVendorData != null) {
          debugPrint(
            '[Auth Load User] Found vendor by email for ${user.id}. Linking user_id.',
          );
          final vendor = Vendor.fromJson(emailVendorData);
          await supabase
              .from('vendors')
              .update({'user_id': user.id}).eq('id', vendor.id);
          state = state.copyWith(
            vendor: vendor,
            isManagement: vendor.isManagement,
            isLoading: false,
          );
        } else {
          debugPrint(
            '[Auth Load User] No vendor record found by email either for ${user.id}. Creating new vendor...',
          );
          await _createVendorForUser(user);
        }
      }
    } catch (e) {
      debugPrint(
        '[Auth Load User] Error loading/creating vendor data for ${user.id}: $e',
      );
      state = state.copyWith(
        error: 'Failed to load profile data: ${e.toString()}',
        isLoading: false,
      );
    }
  }

  Future<void> _createVendorForUser(User user) async {
    final checkVendor = await supabase
        .from('vendors')
        .select('id')
        .eq('user_id', user.id)
        .maybeSingle();
    if (checkVendor != null) {
      debugPrint(
        '[Auth Create Vendor] Vendor already exists for user ${user.id}, skipping creation.',
      );
      if (state.vendor == null) await _loadUserData(user);
      return;
    }

    debugPrint(
      '[Auth Create Vendor] Creating vendor record for user: ${user.id}',
    );

    try {
      String? regionId;
      bool isManagement = user.email?.contains('admin') == true ||
          user.email == 'test@admin.com';
      debugPrint(
        '[Auth Create Vendor] Assigning management: $isManagement based on email.',
      );

      if (user.email == null) {
        throw Exception('Cannot create vendor without user email.');
      }

      final newVendorData = {
        'name': user.userMetadata?['full_name'] ?? user.email!.split('@').first,
        'email': user.email!,
        'user_id': user.id,
        'region_id': regionId,
        'is_management': isManagement,
        'is_active': true,
      };

      final result = await supabase
          .from('vendors')
          .insert(newVendorData)
          .select('*, region:region_id(*)')
          .single();

      final vendor = Vendor.fromJson(result);
      debugPrint(
        '[Auth Create Vendor] Vendor created successfully for ${user.id}',
      );

      state = state.copyWith(
        vendor: vendor,
        isManagement: vendor.isManagement,
        isLoading: false,
        clearError: true,
      );
    } catch (e) {
      debugPrint(
        '[Auth Create Vendor] Error creating vendor for ${user.id}: $e',
      );
      state = state.copyWith(
        error: 'Failed to create vendor profile: ${e.toString()}',
        isLoading: false,
      );
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    debugPrint('[Auth Sign In] Attempting sign in for: $email');
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      isAuthenticated: false,
      vendor: null,
      user: null,
      isManagement: false,
    );

    try {
      final AuthResponse response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        debugPrint(
          '[Auth Sign In] Sign in successful via Supabase for: ${response.user!.id}. Listener will handle data loading.',
        );
      } else {
        debugPrint(
          '[Auth Sign In] Sign in failed (no user in response) for: $email',
        );
        throw const AuthException('Invalid login credentials');
      }
    } on AuthException catch (e) {
      debugPrint(
        '[Auth Sign In] AuthException for $email: ${e.statusCode} ${e.message}',
      );
      state = state.copyWith(
        error: e.message,
        isLoading: false,
        isAuthenticated: false,
      );
    } catch (e) {
      debugPrint('[Auth Sign In] Unknown error for $email: $e');
      state = state.copyWith(
        error: 'An unexpected error occurred during sign in.',
        isLoading: false,
        isAuthenticated: false,
      );
    }
    if (state.error != null && state.isLoading) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> userData,
  }) async {
    debugPrint('[Auth Sign Up] Attempting sign up for: $email');
    state = state.copyWith(
      isLoading: true,
      clearError: true,
    );

    try {
      final AuthResponse response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: userData,
      );

      if (response.user != null) {
        debugPrint(
          '[Auth Sign Up] Sign up successful for: ${response.user!.id}',
        );

        return {
          'success': true,
          'user': response.user,
          'message': 'Registration successful! Please verify your email.'
        };
      } else {
        debugPrint(
          '[Auth Sign Up] Sign up failed (no user in response) for: $email',
        );
        throw const AuthException('Registration failed. Please try again.');
      }
    } on AuthException catch (e) {
      debugPrint(
        '[Auth Sign Up] AuthException for $email: ${e.statusCode} ${e.message}',
      );
      state = state.copyWith(
        error: e.message,
        isLoading: false,
      );
      return {
        'success': false,
        'message': e.message,
      };
    } catch (e) {
      debugPrint('[Auth Sign Up] Unknown error for $email: $e');
      state = state.copyWith(
        error: 'An unexpected error occurred during sign up.',
        isLoading: false,
      );
      return {
        'success': false,
        'message': 'An unexpected error occurred during sign up: $e',
      };
    } finally {
      if (state.isLoading) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  Future<Map<String, dynamic>> resetPassword({required String email}) async {
    debugPrint('[Auth Reset Password] Sending reset email to: $email');
    state = state.copyWith(
      isLoading: true,
      clearError: true,
    );

    try {
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'io.supabase.jaouda://reset-callback/',
      );

      debugPrint('[Auth Reset Password] Reset email sent to: $email');

      return {
        'success': true,
        'message': 'Password reset instructions sent to your email'
      };
    } on AuthException catch (e) {
      debugPrint(
        '[Auth Reset Password] AuthException for $email: ${e.statusCode} ${e.message}',
      );
      state = state.copyWith(
        error: e.message,
        isLoading: false,
      );
      return {
        'success': false,
        'message': e.message,
      };
    } catch (e) {
      debugPrint('[Auth Reset Password] Unknown error for $email: $e');
      state = state.copyWith(
        error: 'An unexpected error occurred while sending reset instructions.',
        isLoading: false,
      );
      return {
        'success': false,
        'message': 'An unexpected error occurred: $e',
      };
    } finally {
      if (state.isLoading) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  Future<void> signOut() async {
    debugPrint('[Auth Sign Out] Signing out...');
    try {
      await supabase.auth.signOut();
      debugPrint('[Auth Sign Out] Sign out successful via Supabase.');
    } catch (e) {
      debugPrint('[Auth Sign Out] Error: $e');
      state = state.copyWith(
        error: 'Error signing out: ${e.toString()}',
        isLoading: false,
      );
    }
  }

  Future<void> refreshCurrentUserState() async {
    final currentUser = supabase.auth.currentUser;
    debugPrint(
      '[Auth Refresh] Attempting to refresh state for user: ${currentUser?.id}',
    );
    if (currentUser != null) {
      await _loadUserData(currentUser);
    } else {
      debugPrint('[Auth Refresh] No current user found, resetting state.');
      state = AuthNotifierState();
    }
  }

  // Fallback method to completely re-initialize the auth state
  Future<void> forceReinitialize() async {
    debugPrint('[Auth Force Reinitialize] Forcing full re-initialization...');
    // This will re-check the current session and load data or reset state
    await _initialize();
  }

  @override
  void dispose() {
    debugPrint('[Auth Provider] Disposing listener.');
    _authStateSubscription?.cancel();
    super.dispose();
  }
}

// Update the provider definition
final authProvider = StateNotifierProvider<AuthNotifier, AuthNotifierState>((
  ref,
) {
  return AuthNotifier(ref);
});
