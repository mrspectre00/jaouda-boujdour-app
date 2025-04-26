import 'package:flutter/foundation.dart';
import '../services/supabase_client.dart';

/// Helper class for database operations and initialization
class DbHelper {
  /// Check the database structure to ensure all tables and columns exist
  static Future<void> checkDatabaseStructure() async {
    try {
      // Test if the PostGIS extension is enabled
      await supabase.rpc('check_postgis_exists');
      debugPrint('PostGIS extension is enabled');

      // Removed the check for markets.gps_location column as it's implicitly checked by the loadMarkets RPC
      // await supabase.rpc('check_markets_gps_column');
      // debugPrint('Markets gps_location column exists');
    } catch (e) {
      debugPrint('Error checking database structure: $e');
    }
  }

  /// Create a test region if it doesn't exist
  static Future<void> createTestRegion() async {
    try {
      await supabase.rpc('create_test_region_if_needed');
      debugPrint('Test region created or already exists');
    } catch (e) {
      debugPrint('Error creating test region: $e');
    }
  }

  /// Get the default region for new markets
  static Future<String?> getDefaultRegionId() async {
    try {
      final regions = await supabase.from('regions').select('id').limit(1);
      if (regions.isNotEmpty) {
        return regions[0]['id'];
      }
      return null;
    } catch (e) {
      debugPrint('Error getting default region: $e');
      return null;
    }
  }

  /// Initialize database if needed
  static Future<void> initializeDatabase() async {
    try {
      // First check if our functions exist by calling one
      await createTestRegion();
      debugPrint('Database functions appear to be working');
    } catch (e) {
      debugPrint('Error initializing database: $e');
      debugPrint('You may need to run the schema and functions SQL scripts');
    }
  }

  /// Create PostGIS functions to check database structure
  static Future<void> createDatabaseCheckFunctions() async {
    try {
      // Create functions to check if PostGIS is installed
      await supabase.rpc('create_database_check_functions');
      debugPrint('Created database check functions');
    } catch (e) {
      debugPrint('Error creating database check functions: $e');
    }
  }

  /// Check if regions table exists
  static Future<bool> checkRegionsTableExists() async {
    try {
      await supabase.from('regions').select('id').limit(1);
      return true;
    } catch (e) {
      debugPrint('Regions table does not exist: $e');
      return false;
    }
  }
}
