import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vendor.dart';
import '../providers/auth_provider.dart';
import '../providers/supabase_provider.dart' as app_supabase;

class VendorState {
  final bool isLoading;
  final String? error;
  final List<Vendor> vendors;

  const VendorState({
    this.isLoading = false,
    this.error,
    this.vendors = const [],
  });

  VendorState copyWith({
    bool? isLoading,
    String? error,
    List<Vendor>? vendors,
    bool clearError = false,
  }) {
    return VendorState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
      vendors: vendors ?? this.vendors,
    );
  }
}

class VendorNotifier extends StateNotifier<VendorState> {
  final Ref _ref;
  final SupabaseClient _supabase;

  VendorNotifier(this._ref)
      : _supabase = _ref.read(app_supabase.supabaseProvider),
        super(const VendorState()) {
    // Load vendors when the provider is first created
    loadVendors();
  }

  Future<void> loadVendors() async {
    try {
      state = state.copyWith(isLoading: true, clearError: true);

      final authState = _ref.read(authProvider);
      final isAdmin = authState.isManagement;

      if (!isAdmin) {
        throw Exception('Only management can view all vendors');
      }

      // Query vendors with regions
      final response = await _supabase
          .from('vendors')
          .select('*, region:regions(*)')
          .order('name');

      debugPrint('Response received: ${response.length} vendors found');

      // Convert the response to Vendor objects
      final vendors = response.map((data) {
        // Extract region data if available
        final regionData = data['region'] ?? {};

        return Vendor.fromJson(data);
      }).toList();

      state = state.copyWith(
        isLoading: false,
        vendors: vendors,
      );
    } catch (e) {
      debugPrint('Error loading vendors: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load vendors: ${e.toString()}',
      );
    }
  }
}

final vendorProvider =
    StateNotifierProvider<VendorNotifier, VendorState>((ref) {
  return VendorNotifier(ref);
});

// Provider for active vendors
final activeVendorsProvider = Provider<List<Vendor>>((ref) {
  return ref
      .watch(vendorProvider)
      .vendors
      .where((vendor) => vendor.isActive)
      .toList();
});
