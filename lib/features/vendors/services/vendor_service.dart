import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/api_exception.dart';
import '../../../models/vendor.dart';
import '../../../services/supabase_service.dart';

final vendorServiceProvider = Provider<VendorService>((ref) {
  final supabase = ref.watch(supabaseServiceProvider);
  return VendorService(supabase);
});

class VendorService {
  final SupabaseService _supabaseService;

  VendorService(this._supabaseService);

  Future<List<Vendor>> getVendors() async {
    try {
      final response = await _supabaseService.client
          .from('vendors')
          .select('*, regions(name)')
          .order('name');

      return response.map((vendor) => Vendor.fromJson(vendor)).toList();
    } on PostgrestException catch (e) {
      throw ApiException('Failed to load vendors: ${e.message}');
    } catch (e) {
      throw ApiException('An unexpected error occurred: $e');
    }
  }

  Future<Vendor> getVendorById(String id) async {
    try {
      final response = await _supabaseService.client
          .from('vendors')
          .select('*, regions(name)')
          .eq('id', id)
          .single();

      return Vendor.fromJson(response);
    } on PostgrestException catch (e) {
      throw ApiException('Failed to load vendor: ${e.message}');
    } catch (e) {
      throw ApiException('An unexpected error occurred: $e');
    }
  }

  Future<void> createVendor({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String regionId,
    String? address,
  }) async {
    try {
      // Call the Edge Function to create the vendor with auth user
      final response = await _supabaseService.client.functions.invoke(
        'create-vendor-user',
        body: {
          'email': email,
          'password': password,
          'userData': {
            'name': name,
            'email': email,
            'region_id': regionId,
            'phone': phone,
            'address': address,
            'is_active': true,
            'is_management': false,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          }
        },
      );

      if (response.status != 200) {
        final error =
            response.data is Map ? response.data['error'] : 'Unknown error';
        throw ApiException('Failed to create vendor: $error');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('An unexpected error occurred: $e');
    }
  }

  Future<void> updateVendor({
    required String id,
    String? name,
    String? email,
    String? phone,
    String? regionId,
    String? address,
  }) async {
    try {
      final Map<String, dynamic> updates = {};

      if (name != null) updates['name'] = name;
      if (email != null) updates['email'] = email;
      if (phone != null) updates['phone'] = phone;
      if (regionId != null) updates['region_id'] = regionId;
      if (address != null) updates['address'] = address;

      if (updates.isEmpty) return;

      await _supabaseService.client
          .from('vendors')
          .update(updates)
          .eq('id', id);
    } on PostgrestException catch (e) {
      throw ApiException('Failed to update vendor: ${e.message}');
    } catch (e) {
      throw ApiException('An unexpected error occurred: $e');
    }
  }

  Future<void> deleteVendor(String id) async {
    try {
      // Get the vendor record first
      final response = await _supabaseService.client
          .from('vendors')
          .select(
              'user_id') // Using user_id instead of auth_id based on the Edge Function
          .eq('id', id)
          .single();

      if (response['user_id'] == null) {
        throw ApiException('Vendor has no associated authentication user');
      }

      // Call our edge function to delete both vendor and auth user
      final functionResponse = await _supabaseService.client.functions.invoke(
        'delete-vendor-with-auth',
        body: {'vendorId': id},
      );

      if (functionResponse.status != 200) {
        final error = functionResponse.data is Map
            ? functionResponse.data['error']
            : 'Unknown error';
        throw ApiException('Failed to delete vendor: $error');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('An unexpected error occurred: $e');
    }
  }

  Future<void> resetPassword(String email, String newPassword) async {
    try {
      final response = await _supabaseService.client.functions.invoke(
        'reset-vendor-password',
        body: {
          'email': email,
          'newPassword': newPassword,
        },
      );

      if (response.status != 200) {
        final error =
            response.data is Map ? response.data['error'] : 'Unknown error';
        throw ApiException('Failed to reset password: $error');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('An unexpected error occurred: $e');
    }
  }
}
