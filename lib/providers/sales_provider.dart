import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_client.dart';
import '../models/market.dart';

class SalesState {
  final bool isLoading;
  final String? error;
  final List<Map<String, dynamic>> products;
  final Map<String, dynamic>? selectedMarket;

  SalesState({
    this.isLoading = false,
    this.error,
    this.products = const [],
    this.selectedMarket,
  });

  SalesState copyWith({
    bool? isLoading,
    String? error,
    List<Map<String, dynamic>>? products,
    Map<String, dynamic>? selectedMarket,
  }) {
    return SalesState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      products: products ?? this.products,
      selectedMarket: selectedMarket ?? this.selectedMarket,
    );
  }
}

final salesProvider = StateNotifierProvider<SalesNotifier, SalesState>((ref) {
  return SalesNotifier();
});

class SalesNotifier extends StateNotifier<SalesState> {
  SalesNotifier() : super(SalesState());

  Future<void> loadProducts() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final productsData = await supabase.from('products').select();
      state = state.copyWith(
        isLoading: false,
        products: List<Map<String, dynamic>>.from(productsData),
      );
    } catch (e) {
      debugPrint('Error loading products: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load products: $e',
      );
    }
  }

  Future<void> loadMarketData(String marketId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final marketData =
          await supabase.from('markets').select().eq('id', marketId).single();

      state = state.copyWith(
        isLoading: false,
        selectedMarket: marketData,
      );
    } catch (e) {
      debugPrint('Error loading market data: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load market data: $e',
      );
    }
  }

  Future<void> recordSale({
    required String marketId,
    required String productId,
    required double quantity,
    required double unitPrice,
    String? notes,
    String? promotionId,
    double? discount,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // 1. Create the sale record
      final saleData = {
        'market_id': marketId,
        'total_amount': (quantity * unitPrice) - (discount ?? 0),
        'notes': notes,
      };

      final saleResponse =
          await supabase.from('sales').insert(saleData).select().single();

      // 2. Create the sale item
      final saleId = saleResponse['id'];

      final saleItemData = {
        'sale_id': saleId,
        'product_id': productId,
        'quantity': quantity,
        'unit_price': unitPrice,
        'discount': discount ?? 0,
        'promotion_id': promotionId,
      };

      await supabase.from('sale_items').insert(saleItemData);

      // 3. Update the market status to reflect the sale
      await supabase
          .from('markets')
          .update({'status': MarketStatus.saleMade.value}).eq('id', marketId);

      // 4. Update vendor stock (reduce inventory based on sale)
      // This logic would depend on your stock management approach

      state = state.copyWith(isLoading: false);
    } catch (e) {
      debugPrint('Error recording sale: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to record sale: $e',
      );
    }
  }
}
