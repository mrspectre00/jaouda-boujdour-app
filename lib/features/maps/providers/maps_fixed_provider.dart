import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../models/market.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/location_service.dart';
import '../../../services/supabase_client.dart';
import '../../../utils/db_helper.dart';
import '../../../services/route_service.dart';
import 'dart:math' as math;

class MapsState {
  final bool isLoading;
  final String? error;
  final List<Market> markets;
  final LatLng? currentLocation;
  final Market? selectedMarket;
  final List<LatLng> routePoints;
  final bool isSatelliteView;
  final Set<MarketStatus> visibleStatuses;
  final bool showRoutePlan;
  final double? routeDistance;
  final Duration? routeDuration;

  MapsState({
    this.isLoading = false,
    this.error,
    this.markets = const [],
    this.currentLocation,
    this.selectedMarket,
    this.routePoints = const [],
    this.isSatelliteView = false,
    this.visibleStatuses = const {
      MarketStatus.toVisit,
      MarketStatus.saleMade,
      MarketStatus.closed,
      MarketStatus.noNeed,
    },
    this.showRoutePlan = false,
    this.routeDistance,
    this.routeDuration,
  });

  MapsState copyWith({
    bool? isLoading,
    String? error,
    List<Market>? markets,
    LatLng? currentLocation,
    Market? selectedMarket,
    List<LatLng>? routePoints,
    bool? isSatelliteView,
    Set<MarketStatus>? visibleStatuses,
    bool? showRoutePlan,
    double? routeDistance,
    Duration? routeDuration,
  }) {
    return MapsState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      markets: markets ?? this.markets,
      currentLocation: currentLocation ?? this.currentLocation,
      selectedMarket: selectedMarket ?? this.selectedMarket,
      routePoints: routePoints ?? this.routePoints,
      isSatelliteView: isSatelliteView ?? this.isSatelliteView,
      visibleStatuses: visibleStatuses ?? this.visibleStatuses,
      showRoutePlan: showRoutePlan ?? this.showRoutePlan,
      routeDistance: routeDistance ?? this.routeDistance,
      routeDuration: routeDuration ?? this.routeDuration,
    );
  }

  static MapsState initial() {
    return MapsState();
  }
}

final mapsProvider = StateNotifierProvider<MapsNotifier, MapsState>((ref) {
  return MapsNotifier(ref);
});

class MapsNotifier extends StateNotifier<MapsState> {
  final Ref ref;
  final LocationService _locationService;
  final RouteService _routeService;
  final DbHelper _dbHelper;
  StreamSubscription<Position>? _locationSubscription;

  MapsNotifier(this.ref)
      : _locationService = LocationService(),
        _routeService = RouteService(),
        _dbHelper = DbHelper(),
        super(MapsState.initial()) {
    initialize();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  Future<void> initialize() async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      // Initialize route service first
      try {
        await _routeService.initialize();
      } catch (e) {
        debugPrint('Failed to initialize RouteService: $e');
        state = state.copyWith(
          error: 'Failed to initialize routing service: $e',
          isLoading: false,
        );
        return;
      }

      await loadMarkets();

      // Try to get last known location first
      final lastKnownLocation = await LocationService.getLastKnownLocation();
      if (lastKnownLocation != null) {
        state = state.copyWith(
          currentLocation: LatLng(
            lastKnownLocation.latitude,
            lastKnownLocation.longitude,
          ),
        );
      }

      await getCurrentLocation();
      _startLocationUpdates();

      // Try to load last known route
      final lastKnownRoute = await LocationService.getLastKnownRoute();
      if (lastKnownRoute != null) {
        state = state.copyWith(routePoints: lastKnownRoute);
      }
    } catch (e) {
      debugPrint('Failed to initialize MapsNotifier: $e');
      state = state.copyWith(error: 'Failed to initialize: $e');
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> loadMarkets() async {
    try {
      final authState = ref.read(authProvider);
      if (!authState.isAuthenticated) {
        state = state.copyWith(
          isLoading: false,
          error: "Please log in to view markets",
        );
        return;
      }

      List<dynamic> rawMarketsData = [];
      final isManagement = authState.isManagement;
      String? vendorRegionId = authState.vendor?.regionId;

      if (isManagement) {
        debugPrint('Loading all markets for management user via RPC');
        rawMarketsData = await supabase.rpc('get_all_markets_with_coords');
      } else if (vendorRegionId != null) {
        debugPrint(
          'Loading markets for vendor region: $vendorRegionId via RPC',
        );
        rawMarketsData = await supabase.rpc(
          'get_region_markets_with_coords',
          params: {'region_uuid': vendorRegionId},
        );
      }

      final markets = rawMarketsData.map<Market>((data) {
        try {
          final Map<String, dynamic> marketMap = Map<String, dynamic>.from(
            data,
          );
          if (marketMap.containsKey('gps_location_text')) {
            marketMap['gps_location'] = marketMap['gps_location_text'];
          }
          return Market.fromJson(marketMap);
        } catch (e) {
          debugPrint('Error parsing market from RPC: $e, data: $data');
          return Market(
            id: data?['id']?.toString() ?? 'error_rpc',
            name: data?['name']?.toString() ?? 'Error parsing market',
            address: data?['address']?.toString() ?? '',
            latitude: 0,
            longitude: 0,
            status: MarketStatus.toVisit,
          );
        }
      }).toList();

      state = state.copyWith(markets: markets, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to load markets: $e',
        isLoading: false,
      );
    }
  }

  Future<void> getCurrentLocation() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final position = await _locationService.getCurrentLocation();
      if (position != null) {
        state = state.copyWith(
          currentLocation: LatLng(position.latitude, position.longitude),
          error: null,
        );
      }
    } catch (e) {
      debugPrint('Error getting current position: $e');
      state = state.copyWith(error: 'Failed to get current location: $e');
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  void _startLocationUpdates() {
    _locationSubscription?.cancel();
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      state = state.copyWith(
        currentLocation: LatLng(position.latitude, position.longitude),
      );
    });
  }

  void _checkNearbyMarkets(LatLng location) {
    final nearbyMarkets = state.markets.where((market) {
      final distance = LocationService.calculateDistance(
        location.latitude,
        location.longitude,
        market.latitude ?? 0,
        market.longitude ?? 0,
      );
      return distance <= 50; // 50 meters radius
    }).toList();

    if (nearbyMarkets.isNotEmpty) {
      // Update the nearest market status
      final nearestMarket = nearbyMarkets.reduce((a, b) {
        final distanceA = LocationService.calculateDistance(
          location.latitude,
          location.longitude,
          a.latitude ?? 0,
          a.longitude ?? 0,
        );
        final distanceB = LocationService.calculateDistance(
          location.latitude,
          location.longitude,
          b.latitude ?? 0,
          b.longitude ?? 0,
        );
        return distanceA < distanceB ? a : b;
      });

      if (nearestMarket.status == MarketStatus.toVisit) {
        state = state.copyWith(selectedMarket: nearestMarket);
      }
    }
  }

  void selectMarket(Market? market) {
    state = state.copyWith(selectedMarket: market);
  }

  void clearSelectedMarket() {
    state = state.copyWith(selectedMarket: null);
  }

  void clearRoute() {
    state = state.copyWith(routePoints: []);
  }

  // Calculate distance between two points in kilometers using Haversine formula
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371; // Earth's radius in kilometers
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double degree) {
    return degree * (math.pi / 180);
  }

  Future<void> generateRoute(LatLng start, LatLng end) async {
    try {
      if (!_routeService.isInitialized) {
        await _routeService.initialize();
      }

      final routePoints = await _routeService.generateRoute(start, end);

      if (routePoints.isEmpty) {
        throw Exception('No route points generated');
      }

      // Calculate total distance
      double totalDistance = 0;
      for (int i = 0; i < routePoints.length - 1; i++) {
        totalDistance += _calculateDistance(
          routePoints[i].latitude,
          routePoints[i].longitude,
          routePoints[i + 1].latitude,
          routePoints[i + 1].longitude,
        );
      }

      // Estimate duration (assuming average speed of 30 km/h)
      final durationInHours = totalDistance / 30;
      final durationInMinutes = (durationInHours * 60).round();

      state = state.copyWith(
        routePoints: routePoints,
        routeDistance: totalDistance,
        routeDuration: Duration(minutes: durationInMinutes),
        error: null,
      );

      // Cache the route
      LocationService.cacheLastKnownRoute(routePoints);
    } catch (e) {
      debugPrint('Error generating route: $e');
      state = state.copyWith(
        error: 'Failed to generate route: ${e.toString()}',
        routePoints: [],
        routeDistance: 0,
        routeDuration: null,
      );
    }
  }

  void toggleSatelliteView() {
    state = state.copyWith(isSatelliteView: !state.isSatelliteView);
  }

  void toggleMarketStatus(MarketStatus status) {
    final newStatuses = Set<MarketStatus>.from(state.visibleStatuses);
    if (newStatuses.contains(status)) {
      newStatuses.remove(status);
    } else {
      newStatuses.add(status);
    }
    state = state.copyWith(visibleStatuses: newStatuses);
  }

  void toggleRoutePlan() {
    state = state.copyWith(showRoutePlan: !state.showRoutePlan);
  }

  void recenterToVendor() {
    if (state.currentLocation != null) {
      state = state.copyWith(selectedMarket: null);
    }
  }

  Future<void> refreshMap() async {
    await loadMarkets();
    await getCurrentLocation();
  }

  List<Market> getFilteredMarkets() {
    return state.markets
        .where((market) => state.visibleStatuses.contains(market.status))
        .toList();
  }

  Future<void> optimizeTodayRoute() async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      // Get today's markets
      final todayMarkets = state.markets
          .where(
            (market) =>
                market.visitDate != null &&
                market.visitDate!.year == DateTime.now().year &&
                market.visitDate!.month == DateTime.now().month &&
                market.visitDate!.day == DateTime.now().day &&
                market.status == MarketStatus.toVisit,
          )
          .toList();

      if (todayMarkets.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: 'No markets to visit today',
        );
        return;
      }

      // Add current location as start point
      if (state.currentLocation == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Current location not available',
        );
        return;
      }

      final locations = [
        state.currentLocation!,
        ...todayMarkets.map((m) => m.location),
      ];

      final optimizedRoute = await _routeService.optimizeRoute(locations);
      state = state.copyWith(
        routePoints: optimizedRoute ?? [],
        isLoading: false,
        showRoutePlan: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to optimize route: $e',
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

      // Simplify the market creation - focus on essential fields only
      Map<String, dynamic> marketData = {
        'id': market.id,
        'name': market.name,
        'address': market.address,
        'status': market.status.value,
      };

      // Convert location to PostGIS format
      final lat = market.latitude ?? 0;
      final lng = market.longitude ?? 0;
      marketData['gps_location'] = 'POINT($lng $lat)';

      // Add vendor_id if available
      if (!authState.isManagement && authState.vendor?.id != null) {
        marketData['vendor_id'] = authState.vendor!.id;
      }

      // Get or create a region
      try {
        final regions = await supabase.from('regions').select('id').limit(1);
        if (regions.isNotEmpty) {
          marketData['region_id'] = regions[0]['id'];
        } else {
          // No regions found, try to create one
          debugPrint('No regions found, attempting to create a test region');
          await DbHelper.createTestRegion();

          // Get the ID of the newly created region
          final newRegions =
              await supabase.from('regions').select('id').limit(1);
          if (newRegions.isNotEmpty) {
            marketData['region_id'] = newRegions[0]['id'];
          }
        }
      } catch (e) {
        debugPrint('Error handling region: $e');
      }

      debugPrint('Sending market data to Supabase: $marketData');

      // Insert the market into Supabase
      await supabase.from('markets').insert(marketData);

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
          .update({'status': status.value}).eq('id', marketId);

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

  Future<void> navigateToNearestUnvisitedMarket() async {
    try {
      if (!_routeService.isInitialized) {
        await _routeService.initialize();
      }

      final currentLocation = state.currentLocation;
      if (currentLocation == null) {
        throw Exception('Current location not available');
      }

      final unvisitedMarkets = state.markets
          .where((market) => market.status == MarketStatus.toVisit)
          .toList();

      if (unvisitedMarkets.isEmpty) {
        throw Exception('No unvisited markets found');
      }

      // Find the nearest market
      Market nearestMarket = unvisitedMarkets.first;
      double minDistance = double.infinity;

      for (final market in unvisitedMarkets) {
        final distance = LocationService.calculateDistance(
          currentLocation.latitude,
          currentLocation.longitude,
          market.latitude ?? 0,
          market.longitude ?? 0,
        );
        if (distance < minDistance) {
          minDistance = distance;
          nearestMarket = market;
        }
      }

      // Generate route to the nearest market
      await _routeService.generateRoute(
        LatLng(currentLocation.latitude, currentLocation.longitude),
        LatLng(
          nearestMarket.latitude ?? 0,
          nearestMarket.longitude ?? 0,
        ),
      );

      // Update state with navigation details
      state = state.copyWith(
        selectedMarket: nearestMarket,
        showRoutePlan: true,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('Error navigating to nearest market: $e');
      state = state.copyWith(
        error: 'Failed to generate navigation route: ${e.toString()}',
      );
    }
  }
}
