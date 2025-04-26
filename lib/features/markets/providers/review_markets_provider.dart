import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/market.dart';
import '../../../services/supabase_client.dart';
import '../../../providers/auth_provider.dart';

class ReviewMarketsState {
  final List<Market> pendingMarkets;
  final bool isLoading;
  final String? error;

  ReviewMarketsState({
    this.pendingMarkets = const [],
    this.isLoading = false,
    this.error,
  });

  ReviewMarketsState copyWith({
    List<Market>? pendingMarkets,
    bool? isLoading,
    String? error,
  }) {
    return ReviewMarketsState(
      pendingMarkets: pendingMarkets ?? this.pendingMarkets,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final reviewMarketsProvider =
    StateNotifierProvider<ReviewMarketsNotifier, ReviewMarketsState>((ref) {
      return ReviewMarketsNotifier(ref);
    });

class ReviewMarketsNotifier extends StateNotifier<ReviewMarketsState> {
  final Ref _ref;

  ReviewMarketsNotifier(this._ref) : super(ReviewMarketsState()) {
    loadPendingMarkets();
  }

  Future<void> loadPendingMarkets() async {
    state = state.copyWith(isLoading: true, error: null);
    final authState = _ref.read(authProvider);

    if (!authState.isManagement) {
      state = state.copyWith(isLoading: false, error: 'Access denied.');
      return;
    }

    try {
      debugPrint('Loading markets pending review...');
      final response = await supabase
          .from('markets')
          .select()
          .eq('status', MarketStatus.toVisit.value); // New markets to review

      final markets =
          (response as List).map((data) => Market.fromJson(data)).toList();
      state = state.copyWith(pendingMarkets: markets, isLoading: false);
      debugPrint('Loaded ${markets.length} markets for review.');
    } catch (e) {
      debugPrint('Error loading pending markets: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load markets: $e',
      );
    }
  }

  Future<bool> updateMarketStatus(
    String marketId,
    MarketStatus newStatus,
  ) async {
    state = state.copyWith(
      isLoading: true,
    ); // Indicate loading for the specific action
    final authState = _ref.read(authProvider);
    if (!authState.isManagement) {
      state = state.copyWith(isLoading: false, error: 'Access denied.');
      return false;
    }

    try {
      debugPrint('Updating market $marketId status to ${newStatus.value}');
      await supabase
          .from('markets')
          .update({'status': newStatus.value})
          .eq('id', marketId);

      // Reload the list after update
      await loadPendingMarkets();
      return true;
    } catch (e) {
      debugPrint('Error updating market status: $e');
      // Keep isLoading true until reload finishes, but set error
      state = state.copyWith(error: 'Failed to update status: $e');
      await loadPendingMarkets(); // Still try to reload to clear loading state
      return false;
    }
  }

  Future<void> loadMarkets() async {
    state = state.copyWith(isLoading: true);

    try {
      final query = supabase
          .from('markets')
          .select()
          .eq('status', MarketStatus.toVisit.value);

      final data = await query;
      final markets = data.map((json) => Market.fromJson(json)).toList();

      state = state.copyWith(pendingMarkets: markets, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        error: "Failed to load markets: ${e.toString()}",
        isLoading: false,
      );
    }
  }
}
