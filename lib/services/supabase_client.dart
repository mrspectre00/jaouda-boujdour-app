import 'package:supabase_flutter/supabase_flutter.dart';

// Get Supabase client instance
final supabase = Supabase.instance.client;

// Safe query methods to avoid 406 errors
class SupabaseHelper {
  static Future<List<Map<String, dynamic>>> safeSelect(
    String table, {
    String columns = '*',
    Map<String, dynamic> eqFilter = const {},
  }) async {
    try {
      // Start with the base query
      var query = supabase.from(table).select(columns);

      // Apply each filter condition
      eqFilter.forEach((key, value) {
        query = query.eq(key, value);
      });

      // Execute the query
      final response = await query;

      // Return the data or empty list if null
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Supabase query error: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> safeSingle(
    String table, {
    String columns = '*',
    Map<String, dynamic> eqFilter = const {},
  }) async {
    try {
      final results = await safeSelect(
        table,
        columns: columns,
        eqFilter: eqFilter,
      );
      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      print('Supabase safeSingle error: $e');
      return null;
    }
  }
}
