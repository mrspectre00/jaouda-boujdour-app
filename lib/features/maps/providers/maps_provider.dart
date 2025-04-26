import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../models/market.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/location_service.dart';
import '../../../services/supabase_client.dart';

class MapsState {
  final bool isLoading;
  final String? error;
  final List<Market> markets;
  final LatLng? currentLocation;
  final Market? selectedMarket;
  final List<LatLng>? routePoints;

  MapsState({
    this.isLoading = false,
    this.error,
    this.markets = const [],
    this.currentLocation,
    this.selectedMarket,
    this.routePoints,
  });

  MapsState copyWith({
    bool? isLoading,
    String? error,
    List<Market>? markets,
    LatLng? currentLocation,
    Market? selectedMarket,
    List<LatLng>? routePoints,
  }) {
    return MapsState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      markets: markets ?? this.markets,
      currentLocation: currentLocation ?? this.currentLocation,
      selectedMarket: selectedMarket,
      routePoints: routePoints,
    );
  }
}

final mapsProvider = StateNotifierProvider<MapsNotifier, MapsState>((ref) {
  return MapsNotifier(ref);
});

class MapsNotifier extends StateNotifier<MapsState> {
  final Ref ref;
  final LocationService _locationService = LocationService();

  MapsNotifier(this.ref) : super(MapsState()) {
    initialize();
  }

  Future<void> initialize() async {
    state = state.copyWith(isLoading: true);

    try {
      await loadMarkets();
      await getCurrentLocation();

      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to initialize map: ${e.toString()}',
      );
    }
  }

  Future<void> loadMarkets() async {
    try {
      final authState = ref.read(authProvider);
      if (!authState.isAuthenticated) {
        state = state.copyWith(error: "Please log in to view markets");
        return;
      }

      List<dynamic> marketsData;
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
          marketsData = [];
        }
      } else {
        debugPrint('User is neither management nor vendor with region');
        marketsData = [];
      }

      debugPrint('Loaded ${marketsData.length} markets');
      final markets =
          marketsData.map<Market>((data) => Market.fromJson(data)).toList();

      // Log some details about the markets for debugging
      for (var market in markets) {
        debugPrint(
          'Market: ${market.name}, Location: ${market.location}, Status: ${market.status.value}',
        );
      }

      state = state.copyWith(markets: markets);
    } catch (e) {
      debugPrint('Error loading markets: $e');
      state = state.copyWith(error: "Failed to load markets: ${e.toString()}");
    }
  }

  Future<void> getCurrentLocation() async {
    try {
      final position = await _locationService.getCurrentPosition();
      final currentLocation = LatLng(position.latitude, position.longitude);

      state = state.copyWith(currentLocation: currentLocation);
    } catch (e) {
      state = state.copyWith(
        error: "Failed to get current location: ${e.toString()}",
      );
    }
  }

  void selectMarket(Market? market) {
    if (market != null && state.currentLocation != null) {
      final routePoints = _generateRoute(
        state.currentLocation!,
        market.location,
      );

      state = state.copyWith(selectedMarket: market, routePoints: routePoints);
    } else {
      state = state.copyWith(selectedMarket: market, routePoints: null);
    }
  }

  List<LatLng> _generateRoute(LatLng start, LatLng end) {
    // In a real app, we would call a routing service like OpenRouteService
    // For now, we'll simulate a route with a straight line plus some random points
    final List<LatLng> route = [start];

    // Simulate some intermediate points for a more realistic route
    final double latDiff = end.latitude - start.latitude;
    final double lngDiff = end.longitude - start.longitude;

    for (int i = 1; i <= 3; i++) {
      final factor = i / 4.0;
      final randomFactor = (i % 2 == 0) ? 0.0001 : -0.0001;

      route.add(
        LatLng(
          start.latitude + (latDiff * factor) + randomFactor,
          start.longitude + (lngDiff * factor) + randomFactor,
        ),
      );
    }

    route.add(end);
    return route;
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

      // Get regionId from vendor if available and not already set
      String? regionId = market.regionId;
      if (regionId == null &&
          !authState.isManagement &&
          authState.vendor != null) {
        regionId = authState.vendor!.regionId;
      }

      // Default to a region if none provided (for test/demo purposes)
      if (regionId == null) {
        // Get the first region from the database as fallback
        try {
          final regions = await supabase.from('regions').select('id').limit(1);
          if (regions.isNotEmpty) {
            regionId = regions[0]['id'];
          }
        } catch (e) {
          debugPrint('Error getting default region: $e');
        }
      }

      // Add user ID to the market data
      final marketWithUser = market.copyWith(
        // addedBy field doesn't exist in the schema
        vendorId: authState.isManagement ? null : authState.vendor?.id,
        regionId: regionId,
        status: MarketStatus.pendingReview,
      );

      // Convert market to proper JSON format
      final marketJson = marketWithUser.toJson();

      // Ensure the gps_location is properly formatted for Supabase PostGIS
      final lat = marketWithUser.location.latitude;
      final lng = marketWithUser.location.longitude;
      marketJson['gps_location'] = 'POINT($lng $lat)';

      debugPrint('Sending market data to Supabase: $marketJson');

      // Insert the market into Supabase
      await supabase.from('markets').insert(marketJson);

      // Reload markets
      await loadMarkets();

      state = state.copyWith(isLoading: false);
    } catch (e) {
      debugPrint('Add market error: $e');
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

      // Reload markets
      await loadMarkets();

      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: "Failed to update market status: ${e.toString()}",
      );
    }
  }
}
