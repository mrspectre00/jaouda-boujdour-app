import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vendor_target.dart';
import '../providers/auth_provider.dart';
import '../providers/supabase_provider.dart' as app_supabase;

class VendorTargetsState {
  final bool isLoading;
  final String? error;
  final List<VendorTarget> targets;
  final List<VendorTarget> activeTargets;

  const VendorTargetsState({
    this.isLoading = false,
    this.error,
    this.targets = const [],
    this.activeTargets = const [],
  });

  VendorTargetsState copyWith({
    bool? isLoading,
    String? error,
    List<VendorTarget>? targets,
    List<VendorTarget>? activeTargets,
    bool clearError = false,
  }) {
    return VendorTargetsState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
      targets: targets ?? this.targets,
      activeTargets: activeTargets ?? this.activeTargets,
    );
  }
}

class VendorTargetsNotifier extends StateNotifier<VendorTargetsState> {
  final Ref _ref;
  final SupabaseClient _supabase;

  VendorTargetsNotifier(this._ref)
      : _supabase = _ref.read(app_supabase.supabaseProvider),
        super(const VendorTargetsState());

  Future<void> loadTargets({String? vendorId}) async {
    try {
      state = state.copyWith(isLoading: true, clearError: true);

      final authState = _ref.read(authProvider);
      final isAdmin = authState.isManagement;
      final currentVendorId = authState.vendor?.id;

      // Determine which vendor's targets to load
      final targetVendorId = vendorId ?? currentVendorId;

      if (!isAdmin && targetVendorId != currentVendorId) {
        throw Exception('Not authorized to view other vendor targets');
      }

      if (targetVendorId == null && !isAdmin) {
        throw Exception('Vendor ID not available');
      }

      // Build the query based on user role and vendor ID
      var query = _supabase
          .from('vendor_targets')
          .select('*, vendor:vendor_id(*), product:product_id(*)');

      // If a specific vendor is requested or user is not admin, filter by vendor ID
      if (targetVendorId != null) {
        query = query.eq('vendor_id', targetVendorId);
      }

      // Execute the query and parse the results
      final data = await query.order('created_at', ascending: false);
      final targets = data.map((item) => VendorTarget.fromJson(item)).toList();

      // Load progress data for each target
      await _loadTargetProgress(targets);

      // Filter active targets
      final now = DateTime.now();
      final activeTargets = targets.where((target) {
        return target.isActive &&
            target.startDate.isBefore(now) &&
            target.endDate.isAfter(now);
      }).toList();

      state = state.copyWith(
        isLoading: false,
        targets: targets,
        activeTargets: activeTargets,
      );
    } catch (e) {
      debugPrint('Error loading targets: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load targets: ${e.toString()}',
      );
    }
  }

  Future<void> _loadTargetProgress(List<VendorTarget> targets) async {
    try {
      for (int i = 0; i < targets.length; i++) {
        final target = targets[i];

        // Query the target progress using the database function
        final progressData = await _supabase.rpc('get_target_progress',
            params: {'target_uuid': target.id}).single();

        if (progressData != null) {
          targets[i] = target.copyWith(
            achievedValue:
                double.tryParse(progressData['achieved_value'].toString()) ?? 0,
            progressPercentage: double.tryParse(
                    progressData['progress_percentage'].toString()) ??
                0,
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading target progress: $e');
      // Continue without progress data if there's an error
    }
  }

  Future<String> createTarget({
    required String vendorId,
    required String targetName,
    String? targetDescription,
    required DateTime startDate,
    required DateTime endDate,
    required TargetType targetType,
    required double targetValue,
    String? productId,
  }) async {
    try {
      state = state.copyWith(isLoading: true, clearError: true);

      final authState = _ref.read(authProvider);
      if (!authState.isManagement) {
        throw Exception('Only management can create targets');
      }

      final targetData = {
        'vendor_id': vendorId,
        'target_name': targetName,
        'target_description': targetDescription,
        'start_date': startDate.toIso8601String().split('T')[0],
        'end_date': endDate.toIso8601String().split('T')[0],
        'target_type': targetType.toJson(),
        'target_value': targetValue,
        'is_active': true,
        'created_by': authState.user?.id,
        'product_id': productId,
      };

      final response = await _supabase
          .from('vendor_targets')
          .insert(targetData)
          .select()
          .single();

      await loadTargets();

      return response['id'] as String;
    } catch (e) {
      debugPrint('Error creating target: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to create target: ${e.toString()}',
      );
      rethrow;
    }
  }

  Future<void> updateTarget(VendorTarget target) async {
    try {
      state = state.copyWith(isLoading: true, clearError: true);

      final authState = _ref.read(authProvider);
      if (!authState.isManagement) {
        throw Exception('Only management can update targets');
      }

      final targetData = {
        'target_name': target.targetName,
        'target_description': target.targetDescription,
        'start_date': target.startDate.toIso8601String().split('T')[0],
        'end_date': target.endDate.toIso8601String().split('T')[0],
        'target_type': target.targetType.toJson(),
        'target_value': target.targetValue,
        'is_active': target.isActive,
        'product_id': target.productId,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase
          .from('vendor_targets')
          .update(targetData)
          .eq('id', target.id);

      await loadTargets();
    } catch (e) {
      debugPrint('Error updating target: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to update target: ${e.toString()}',
      );
    }
  }

  Future<void> deleteTarget(String targetId) async {
    try {
      state = state.copyWith(isLoading: true, clearError: true);

      final authState = _ref.read(authProvider);
      if (!authState.isManagement) {
        throw Exception('Only management can delete targets');
      }

      await _supabase.from('vendor_targets').delete().eq('id', targetId);

      await loadTargets();
    } catch (e) {
      debugPrint('Error deleting target: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to delete target: ${e.toString()}',
      );
    }
  }
}

final vendorTargetsProvider =
    StateNotifierProvider<VendorTargetsNotifier, VendorTargetsState>((ref) {
  return VendorTargetsNotifier(ref);
});

// Provider for active targets for a specific vendor
final vendorActiveTargetsProvider =
    Provider.family<List<VendorTarget>, String?>((ref, vendorId) {
  final state = ref.watch(vendorTargetsProvider);

  if (vendorId == null) {
    return state.activeTargets;
  }

  return state.targets.where((target) {
    final now = DateTime.now();
    return target.vendorId == vendorId &&
        target.isActive &&
        target.startDate.isBefore(now) &&
        target.endDate.isAfter(now);
  }).toList();
});
