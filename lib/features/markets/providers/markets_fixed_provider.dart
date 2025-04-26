import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../models/market.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/supabase_client.dart';
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
      await DbHelper.checkDatabaseStructure();

      // Create a test region if needed
      if (authState.isManagement) {
        await DbHelper.createTestRegion();
      }

      List<dynamic> marketsData;
      final isManagement = authState.isManagement;

      // Include the ST_AsText query to extract coordinates from the PostGIS point
      const query = '''
        SELECT 
          id, name, address, 
          ST_AsText(gps_location) as gps_location_text,
          region_id, vendor_id, status, notes, 
          created_at, updated_at
        FROM 
          markets
      ''';

      if (isManagement) {
        // Management users can see all markets
        debugPrint('Loading all markets for management user');
        marketsData = await supabase.rpc('get_all_markets_with_coords');
      } else if (authState.vendor != null) {
        // Regular vendors see only markets in their region
        final regionId = authState.vendor!.regionId;
        if (regionId != null) {
          debugPrint('Loading markets for vendor region: $regionId');
          marketsData = await supabase.rpc(
            'get_region_markets_with_coords',
            params: {'region_uuid': regionId},
          );
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
          marketsData.map<Market>((data) {
            try {
              // Extract coordinates from PostGIS POINT format
              double lat = 0;
              double lng = 0;

              if (data['gps_location_text'] != null) {
                final String pointStr = data['gps_location_text'].toString();
                // PostGIS returns point as "POINT(lng lat)" or "SRID=4326;POINT(lng lat)"
                RegExp regex = RegExp(r'POINT\(([^ ]+) ([^ ]+)\)');
                Match? match = regex.firstMatch(pointStr);

                if (match != null && match.groupCount >= 2) {
                  lng = double.tryParse(match.group(1) ?? '0') ?? 0;
                  lat = double.tryParse(match.group(2) ?? '0') ?? 0;
                }
              }

              // Create a location object
              final location = LatLng(lat, lng);

              // Create a market object
              return Market(
                id: data['id'] ?? 'error',
                name: data['name'] ?? 'Error parsing market',
                address: data['address'] ?? '',
                location: location,
                regionId: data['region_id'],
                status:
                    data['status'] != null
                        ? MarketStatusExtension.fromString(data['status'])
                        : MarketStatus.pendingReview,
                notes: data['notes'],
                createdAt:
                    data['created_at'] != null
                        ? DateTime.parse(data['created_at'])
                        : null,
                updatedAt:
                    data['updated_at'] != null
                        ? DateTime.parse(data['updated_at'])
                        : null,
              );
            } catch (e) {
              debugPrint('Error parsing market: $e, data: $data');
              // Return a placeholder market
              return Market(
                id: data['id'] ?? 'error',
                name: data['name'] ?? 'Error parsing market',
                address: data['address'] ?? '',
                location: const LatLng(0, 0),
              );
            }
          }).toList();

      // Log some details about the markets for debugging
      for (var market in markets) {
        debugPrint(
          'Market: ${market.name}, Location: ${market.location}, Status: ${market.status.value}',
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
    state = state.copyWith(isLoading: true, error: null);

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

      // Convert location to PostGIS format using ST_SetSRID and ST_MakePoint
      final lat = market.location.latitude;
      final lng = market.location.longitude;

      // Using RPC function to handle PostGIS point creation
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
          final newRegions = await supabase
              .from('regions')
              .select('id')
              .limit(1);
          if (newRegions.isNotEmpty) {
            marketData['region_id'] = newRegions[0]['id'];
          }
        }
      } catch (e) {
        debugPrint('Error handling region: $e');
      }

      debugPrint('Sending market data to Supabase: $marketData');

      // Insert the market using RPC function that handles PostGIS
      await supabase.rpc(
        'insert_market_with_location',
        params: {
          'market_id': marketData['id'],
          'market_name': marketData['name'],
          'market_address': marketData['address'],
          'longitude': lng,
          'latitude': lat,
          'region_id': marketData['region_id'],
          'vendor_id': marketData['vendor_id'],
          'status': marketData['status'],
        },
      );

      // Reload markets
      await loadMarkets();
    } catch (e) {
      debugPrint('Add market error: $e');
      state = state.copyWith(
        isLoading: false,
        error: "Failed to add market: ${e.toString()}",
      );
    }
  }

  Future<void> updateMarketStatus(String marketId, MarketStatus status) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await supabase
          .from('markets')
          .update({'status': status.value})
          .eq('id', marketId);

      // Reload markets
      await loadMarkets();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: "Failed to update market status: ${e.toString()}",
      );
    }
  }

  Future<Market?> getMarketById(String marketId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await supabase.rpc(
        'get_market_with_coords',
        params: {'market_uuid': marketId},
      );

      if (result == null || (result is List && result.isEmpty)) {
        throw Exception("Market not found");
      }

      final marketData = result[0];

      // Extract coordinates from PostGIS POINT format
      double lat = 0;
      double lng = 0;

      if (marketData['gps_location_text'] != null) {
        final String pointStr = marketData['gps_location_text'].toString();
        RegExp regex = RegExp(r'POINT\(([^ ]+) ([^ ]+)\)');
        Match? match = regex.firstMatch(pointStr);

        if (match != null && match.groupCount >= 2) {
          lng = double.tryParse(match.group(1) ?? '0') ?? 0;
          lat = double.tryParse(match.group(2) ?? '0') ?? 0;
        }
      }

      final market = Market(
        id: marketData['id'],
        name: marketData['name'],
        address: marketData['address'] ?? '',
        location: LatLng(lat, lng),
        regionId: marketData['region_id'],
        status: MarketStatusExtension.fromString(
          marketData['status'] ?? 'pending',
        ),
        notes: marketData['notes'],
        createdAt:
            marketData['created_at'] != null
                ? DateTime.parse(marketData['created_at'])
                : null,
        updatedAt:
            marketData['updated_at'] != null
                ? DateTime.parse(marketData['updated_at'])
                : null,
      );

      state = state.copyWith(isLoading: false);

      return market;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: "Failed to get market details: ${e.toString()}",
      );
      return null;
    }
  }
}
