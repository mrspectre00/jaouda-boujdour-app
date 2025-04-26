import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/market.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/supabase_client.dart';
import 'package:flutter/foundation.dart';
import '../../../utils/db_helper.dart';

class MarketsState {
  final bool isLoading;
  final String? error;
  final List<Market> markets;

  MarketsState({this.isLoading = false, this.error, this.markets = const []});

  MarketsState copyWith({
    bool? isLoading,
    String? error,
    List<Market>? markets,
  }) {
    return MarketsState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      markets: markets ?? this.markets,
    );
  }
}

final marketsProvider = StateNotifierProvider<MarketsNotifier, MarketsState>((
  ref,
) {
  return MarketsNotifier(ref);
});

class MarketsNotifier extends StateNotifier<MarketsState> {
  final Ref ref;

  MarketsNotifier(this.ref) : super(MarketsState()) {
    loadMarkets();
  }

  Future<void> loadMarkets() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final authState = ref.read(authProvider);
      if (!authState.isAuthenticated) {
        state = state.copyWith(
          isLoading: false,
          error: "Please log in to view markets",
        );
        return;
      }

      // Check database structure for debugging
      try {
        await DbHelper.checkDatabaseStructure();
      } catch (e) {
        debugPrint('Error checking database structure: $e');
        // Continue with the function, don't return early
      }

      debugPrint('Loading markets...');
      debugPrint('User is management: ${authState.isManagement}');
      if (authState.vendor != null) {
        debugPrint('Vendor ID: ${authState.vendor!.id}');
        debugPrint('Vendor region: ${authState.vendor!.regionId}');
      }

      List<dynamic> marketsData = [];
      try {
        final isManagement = authState.isManagement;

        if (isManagement) {
          // Management users can see all markets
          debugPrint('Loading all markets for management user');
          marketsData = await supabase.from('markets').select();
        } else if (authState.vendor != null) {
          // Regular vendors see only markets in their region
          final regionId = authState.vendor!.regionId;
          if (regionId != null) {
            debugPrint('Loading markets for vendor region: $regionId');
            marketsData = await supabase
                .from('markets')
                .select()
                .eq('region_id', regionId);
          } else {
            debugPrint('Vendor has no region assigned');
          }
        } else {
          debugPrint('User is neither management nor vendor with region');
        }
      } catch (e) {
        debugPrint('Error querying markets table: $e');
        state = state.copyWith(
          isLoading: false,
          error: "Database error: ${e.toString()}",
        );
        return;
      }

      debugPrint('Loaded ${marketsData.length} markets');

      List<Market> markets = [];
      if (marketsData.isNotEmpty) {
        markets =
            marketsData.map<Market>((data) {
              try {
                return Market(
                  id: data['id'] ?? 'unknown',
                  name: data['name'] ?? 'Unknown Market',
                  address: data['address'] ?? 'No address',
                  latitude: 0,
                  longitude: 0,
                  status: MarketStatus.toVisit, // Default to toVisit
                );
              } catch (e) {
                debugPrint('Error parsing market data: $e');
                debugPrint('Problematic data: $data');
                return Market(
                  id: data['id'] ?? 'unknown',
                  name: data['name'] ?? 'Unknown Market',
                  address: data['address'] ?? 'No address',
                  latitude: 0,
                  longitude: 0,
                  status: MarketStatus.toVisit, // Default to toVisit
                );
              }
            }).toList();
      }

      // Log some details about the markets for debugging
      for (var market in markets) {
        debugPrint(
          'Market: ${market.name}, ID: ${market.id}, Location: (${market.latitude}, ${market.longitude}), Status: ${market.status.value}',
        );
      }

      state = state.copyWith(isLoading: false, markets: markets);
    } catch (e) {
      debugPrint('Error loading markets: $e');
      state = state.copyWith(
        isLoading: false,
        error: "Failed to load markets: ${e.toString()}",
      );
    }
  }

  Future<void> addMarket(Market market) async {
    state = state.copyWith(isLoading: true);

    try {
      final authState = ref.read(authProvider);
      if (!authState.isAuthenticated) {
        state = state.copyWith(
          isLoading: false,
          error: "Please log in to add markets",
        );
        return;
      }

      Map<String, dynamic> marketData = {
        'id': market.id,
        'name': market.name,
        'address': market.address,
        'status': market.status.value,
        'visit_date': market.visitDate?.toIso8601String(),
        'assigned_products': market.assignedProducts,
      };

      final lat = market.latitude ?? 0;
      final lng = market.longitude ?? 0;
      marketData['gps_location'] = 'POINT($lng $lat)';

      if (!authState.isManagement && authState.vendor?.id != null) {
        marketData['vendor_id'] = authState.vendor!.id;
      }

      await supabase.from('markets').insert(marketData);
      await loadMarkets();

      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: "Failed to add market: ${e.toString()}",
      );
    }
  }

  Future<void> updateMarketStatus(String marketId, MarketStatus status) async {
    state = state.copyWith(isLoading: true);

    try {
      await supabase
          .from('markets')
          .update({'status': status.value})
          .eq('id', marketId);

      await loadMarkets();

      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: "Failed to update market status: ${e.toString()}",
      );
    }
  }

  Future<Market?> getMarketById(String marketId) async {
    // Use Future() to delay state changes until after build is complete
    Future(() {
      state = state.copyWith(isLoading: true, error: null);
    });

    try {
      final marketData =
          await supabase.from('markets').select().eq('id', marketId).single();

      final market = Market.fromJson(marketData);

      // Use Future() to delay state changes until after build is complete
      Future(() {
        state = state.copyWith(isLoading: false);
      });

      return market;
    } catch (e) {
      // Use Future() to delay state changes until after build is complete
      Future(() {
        state = state.copyWith(
          isLoading: false,
          error: "Failed to get market details: ${e.toString()}",
        );
      });
      return null;
    }
  }
}
