import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../models/promotion.dart';
import '../../../services/supabase_client.dart';
import '../../../providers/auth_provider.dart';

class PromotionsState {
  final List<Promotion> promotions;
  final bool isLoading;
  final String? error;

  PromotionsState({
    this.promotions = const [],
    this.isLoading = false,
    this.error,
  });

  PromotionsState copyWith({
    List<Promotion>? promotions,
    bool? isLoading,
    String? error,
  }) {
    return PromotionsState(
      promotions: promotions ?? this.promotions,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final promotionsProvider =
    StateNotifierProvider<PromotionsNotifier, PromotionsState>((ref) {
  return PromotionsNotifier();
});

// Provider to get only active promotions (useful for RecordSaleScreen)
final activePromotionsProvider = Provider<List<Promotion>>((ref) {
  final promotionsState = ref.watch(promotionsProvider);
  final now = DateTime.now();

  return promotionsState.promotions.where((promotion) {
    if (promotion.startDate != null && promotion.startDate!.isAfter(now)) {
      return false;
    }

    if (promotion.endDate != null && promotion.endDate!.isBefore(now)) {
      return false;
    }

    return true;
  }).toList();
});

class PromotionsNotifier extends StateNotifier<PromotionsState> {
  PromotionsNotifier() : super(PromotionsState()) {
    loadPromotions();
  }

  Future<void> loadPromotions() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final promotionsData = await supabase.from('promotions').select();

      final promotions = promotionsData.map<Promotion>((data) {
        return Promotion.fromJson(data);
      }).toList();

      state = state.copyWith(
        isLoading: false,
        promotions: promotions,
      );
    } catch (e) {
      debugPrint('Error loading promotions: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load promotions: $e',
      );
    }
  }

  Future<void> addPromotion(Promotion promotion) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final promotionData = promotion.toJson();
      await supabase.from('promotions').insert(promotionData);
      await loadPromotions();
    } catch (e) {
      debugPrint('Error adding promotion: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to add promotion: $e',
      );
    }
  }

  Future<void> updatePromotion(Promotion promotion) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final promotionData = promotion.toJson();
      await supabase
          .from('promotions')
          .update(promotionData)
          .eq('id', promotion.id);
      await loadPromotions();
    } catch (e) {
      debugPrint('Error updating promotion: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to update promotion: $e',
      );
    }
  }

  Future<void> deletePromotion(String promotionId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await supabase.from('promotions').delete().eq('id', promotionId);
      await loadPromotions();
    } catch (e) {
      debugPrint('Error deleting promotion: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to delete promotion: $e',
      );
    }
  }

  Future<bool> savePromotion(Promotion promotion) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final existingPromotion =
          state.promotions.any((p) => p.id == promotion.id);

      if (existingPromotion) {
        debugPrint('Updating promotion ${promotion.id}');
        await updatePromotion(promotion);
      } else {
        // Ensure ID is generated for new promotions if not provided
        final promotionWithId = promotion.id.isEmpty
            ? promotion.copyWith(id: const Uuid().v4())
            : promotion;
        debugPrint('Adding new promotion ${promotionWithId.id}');
        await addPromotion(promotionWithId);
      }

      return true;
    } catch (e) {
      debugPrint('Error saving promotion: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to save promotion: $e',
      );
      return false;
    }
  }
}
