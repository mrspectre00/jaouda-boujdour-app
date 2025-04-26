import 'package:flutter/foundation.dart';
import '../models/market.dart';
import './supabase_client.dart';

class MarketService {
  /// Get a market by its ID
  Future<Market?> getMarketById(String marketId) async {
    try {
      final marketData =
          await supabase.from('markets').select().eq('id', marketId).single();
      return Market.fromJson(marketData);
    } catch (e) {
      debugPrint('Error fetching market by ID: $e');
      return null;
    }
  }

  /// Load all markets or markets for a specific region
  Future<List<Market>> getMarkets({String? regionId}) async {
    try {
      var query = supabase.from('markets').select();

      if (regionId != null) {
        query = query.eq('region_id', regionId);
      }

      final marketsData = await query;

      List<Market> markets = [];
      if (marketsData.isNotEmpty) {
        markets = marketsData.map<Market>((data) {
          try {
            return Market.fromJson(data);
          } catch (e) {
            debugPrint('Error parsing market data: $e');
            return Market(
              id: data['id'] ?? 'unknown',
              name: data['name'] ?? 'Unknown Market',
              address: data['address'] ?? 'No address',
              latitude: 0,
              longitude: 0,
              status: MarketStatus.toVisit,
            );
          }
        }).toList();
      }

      return markets;
    } catch (e) {
      debugPrint('Error loading markets: $e');
      return [];
    }
  }

  /// Update the status of a market
  Future<bool> updateMarketStatus(String marketId, MarketStatus status) async {
    try {
      await supabase
          .from('markets')
          .update({'status': status.value}).eq('id', marketId);
      return true;
    } catch (e) {
      debugPrint('Failed to update market status: $e');
      return false;
    }
  }

  /// Add a new market
  Future<bool> addMarket(Market market, {String? vendorId}) async {
    try {
      Map<String, dynamic> marketData = {
        'name': market.name,
        'address': market.address,
        'status': market.status.value,
      };

      // Add ID if provided
      if (market.id != null) {
        marketData['id'] = market.id;
      }

      // Add visit date if available
      if (market.visitDate != null) {
        marketData['visit_date'] = market.visitDate?.toIso8601String();
      }

      // Add assigned products if available
      if (market.assignedProducts != null) {
        marketData['assigned_products'] = market.assignedProducts;
      }

      // Add GPS location if available
      final lat = market.latitude ?? 0;
      final lng = market.longitude ?? 0;
      marketData['gps_location'] = 'POINT($lng $lat)';

      // Add vendor ID if provided
      if (vendorId != null) {
        marketData['vendor_id'] = vendorId;
      }

      await supabase.from('markets').insert(marketData);
      return true;
    } catch (e) {
      debugPrint('Failed to add market: $e');
      return false;
    }
  }
}
