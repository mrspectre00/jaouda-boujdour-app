import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

// Service to initialize and verify database tables
class DbInitService {
  final SupabaseClient _supabase;

  DbInitService(this._supabase);

  // Initialize database by checking if required tables exist
  Future<void> initialize() async {
    try {
      await _checkRequiredTables();
    } catch (e) {
      debugPrint('Error initializing database: $e');
    }
  }

  // Check if required tables exist in the database
  Future<void> _checkRequiredTables() async {
    try {
      // Check vendors table
      await _supabase.from('vendors').select('id').limit(1);
      debugPrint('✓ Vendors table exists');

      // Check markets table
      await _supabase.from('markets').select('id').limit(1);
      debugPrint('✓ Markets table exists');

      // Check sales table
      await _supabase.from('sales').select('id').limit(1);
      debugPrint('✓ Sales table exists');

      // Check products table
      await _supabase.from('products').select('id').limit(1);
      debugPrint('✓ Products table exists');
    } catch (e) {
      debugPrint('Error checking tables: $e');
      // In production, you might want to create these tables or show an error message
    }
  }
}

// Provider for database initialization service
final dbInitServiceProvider = Provider<DbInitService>((ref) {
  final supabase = Supabase.instance.client;
  return DbInitService(supabase);
});
