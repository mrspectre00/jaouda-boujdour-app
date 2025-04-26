import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/market.dart';
import '../services/supabase_service.dart';

// Using the MarketStatus from models/market.dart instead of redefining it here
// enum MarketStatus { toVisit, visited, closed, noNeed }

class MarketsState {
  final List<Market> markets;
  final bool isLoading;
  final String? error;

  MarketsState({this.markets = const [], this.isLoading = false, this.error});

  MarketsState copyWith({
    List<Market>? markets,
    bool? isLoading,
    String? error,
  }) {
    return MarketsState(
      markets: markets ?? this.markets,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class MarketsNotifier extends StateNotifier<MarketsState> {
  final SupabaseClient _supabase;

  MarketsNotifier({required SupabaseClient supabase})
      : _supabase = supabase,
        super(MarketsState()) {
    loadMarkets();
  }

  Future<void> loadMarkets() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _supabase.from('markets').select();
      final markets =
          (response as List).map((json) => Market.fromJson(json)).toList();

      state = state.copyWith(markets: markets, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        error: 'Error loading markets: $e',
        isLoading: false,
      );
    }
  }

  Future<void> addMarket(Market market) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _supabase.from('markets').insert(market.toJson());
      await loadMarkets();
    } catch (e) {
      state = state.copyWith(
        error: 'Error adding market: $e',
        isLoading: false,
      );
    }
  }

  Future<void> updateMarket(Market market) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _supabase
          .from('markets')
          .update(market.toJson())
          .eq('id', market.id);
      await loadMarkets();
    } catch (e) {
      state = state.copyWith(
        error: 'Error updating market: $e',
        isLoading: false,
      );
    }
  }

  Future<void> deleteMarket(String marketId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _supabase.from('markets').delete().eq('id', marketId);
      await loadMarkets();
    } catch (e) {
      state = state.copyWith(
        error: 'Error deleting market: $e',
        isLoading: false,
      );
    }
  }

  Future<void> updateMarketStatus(String marketId, MarketStatus status) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _supabase.from('markets').update(
          {'status': status.toString().split('.').last}).eq('id', marketId);
      await loadMarkets();
    } catch (e) {
      state = state.copyWith(
        error: 'Error updating market status: $e',
        isLoading: false,
      );
    }
  }
}

final marketsProvider = StateNotifierProvider<MarketsNotifier, MarketsState>((
  ref,
) {
  final supabase = ref.watch(supabaseProvider);
  return MarketsNotifier(supabase: supabase);
});
