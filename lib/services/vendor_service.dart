import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jaouda_boujdour_app/models/vendor.dart';
import 'package:jaouda_boujdour_app/utils/error_handler.dart';

final vendorServiceProvider = Provider<VendorService>((ref) {
  return VendorService(Supabase.instance.client);
});

/// A service class that handles all vendor account operations
class VendorService {
  final SupabaseClient _client;

  // System default vendor ID - used for reassigning data when a vendor is deleted
  static const String defaultVendorId = '00000000-0000-0000-0000-000000000001';

  // Protected vendor IDs that cannot be deleted
  static const List<String> protectedVendorIds = [
    defaultVendorId,
    // Add other protected IDs here
  ];

  VendorService(this._client);

  /// Get all vendors with their region data
  Future<List<Vendor>> getAllVendors() async {
    try {
      final response = await _client
          .from('vendors')
          .select('*, region:regions(*)')
          .order('name');

      return response.map((data) => Vendor.fromJson(data)).toList();
    } catch (e) {
      handleError('Failed to load vendors', e);
      return [];
    }
  }

  /// Fetch all vendors from the database
  Future<List<Vendor>> getVendors() async {
    try {
      final response = await _client.from('vendors').select().order('name');

      return (response as List)
          .map((vendor) => Vendor.fromJson(vendor))
          .toList();
    } catch (e) {
      handleError('Failed to fetch vendors', e);
      return [];
    }
  }

  /// Fetch a vendor by ID
  Future<Vendor?> getVendorById(String id) async {
    try {
      final response =
          await _client.from('vendors').select().eq('id', id).single();

      return Vendor.fromJson(response);
    } catch (e) {
      handleError('Failed to fetch vendor', e);
      return null;
    }
  }

  /// Create a new vendor with authentication account
  Future<Map<String, dynamic>> createVendor(
      Map<String, dynamic> vendorData) async {
    try {
      // Use the Edge Function to create vendor
      final response = await _client.functions.invoke(
        'create-vendor-user',
        body: vendorData,
      );

      if (response.status != 200) {
        final error = jsonDecode(response.data);
        throw Exception(error['error'] ?? 'Failed to create vendor');
      }

      return jsonDecode(response.data);
    } catch (e) {
      handleError('Failed to create vendor', e);
      rethrow;
    }
  }

  /// Update an existing vendor's details
  Future<Vendor?> updateVendor(
      String id, Map<String, dynamic> vendorData) async {
    try {
      final response = await _client
          .from('vendors')
          .update(vendorData)
          .eq('id', id)
          .select()
          .single();

      return Vendor.fromJson(response);
    } catch (e) {
      handleError('Failed to update vendor', e);
      return null;
    }
  }

  /// Delete a vendor and their authentication account
  Future<Map<String, dynamic>> deleteVendor(String vendorId) async {
    try {
      final response = await _client.functions.invoke(
        'delete-vendor-user',
        body: {'vendorId': vendorId},
      );

      if (response.status != 200) {
        final error = jsonDecode(response.data);
        throw Exception(error['error'] ?? 'Failed to delete vendor');
      }

      return jsonDecode(response.data);
    } catch (e) {
      handleError('Failed to delete vendor', e);
      rethrow;
    }
  }

  /// Reset a vendor's password
  Future<Map<String, dynamic>> resetVendorPassword(
      String vendorId, String newPassword) async {
    try {
      // Call the Edge Function to reset password
      final response = await _client.functions.invoke(
        'reset-vendor-password',
        body: {
          'vendorId': vendorId,
          'newPassword': newPassword,
        },
      );

      if (response.status != 200) {
        final error = jsonDecode(response.data);
        throw Exception(error['error'] ?? 'Failed to reset password');
      }

      return jsonDecode(response.data);
    } catch (e) {
      handleError('Failed to reset vendor password', e);
      rethrow;
    }
  }

  /// Check if the current user has management privileges
  Future<bool> hasManagementPrivileges() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return false;

      final response = await _client
          .from('vendors')
          .select('is_management')
          .eq('user_id', user.id)
          .single();

      return response['is_management'] ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Toggle a vendor's active status
  Future<Vendor> toggleVendorActiveStatus(
      String vendorId, bool isActive) async {
    try {
      await _client.from('vendors').update({
        'is_active': isActive,
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', vendorId);

      // Fetch the updated vendor to return
      final updatedVendor = await _client
          .from('vendors')
          .select('*, region:regions(*)')
          .eq('id', vendorId)
          .single();

      return Vendor.fromJson(updatedVendor);
    } catch (e) {
      debugPrint('Error toggling vendor status: $e');
      throw 'Failed to update vendor status: $e';
    }
  }
}
