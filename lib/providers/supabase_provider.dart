import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Provider to access Supabase client throughout the app
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// Provider for the Supabase auth client
final supabaseAuthProvider = Provider<GoTrueClient>((ref) {
  final client = ref.watch(supabaseProvider);
  return client.auth;
});
