import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/sale.dart';
import '../../../services/supabase_client.dart';
import '../../../providers/auth_provider.dart';

class SalesState {
  final List<Sale> sales;
  final bool isLoading;
  final String? error;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? searchQuery;
  final String? selectedMarketId;
  final Map<String, dynamic>? selectedMarket;
  final List<Map<String, dynamic>> products;

  SalesState({
    this.sales = const [],
    this.isLoading = false,
    this.error,
    this.startDate,
    this.endDate,
    this.searchQuery,
    this.selectedMarketId,
    this.selectedMarket,
    this.products = const [],
  });

  SalesState copyWith({
    List<Sale>? sales,
    bool? isLoading,
    String? error,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
    String? selectedMarketId,
    Map<String, dynamic>? selectedMarket,
    List<Map<String, dynamic>>? products,
  }) {
    return SalesState(
      sales: sales ?? this.sales,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedMarketId: selectedMarketId ?? this.selectedMarketId,
      selectedMarket: selectedMarket ?? this.selectedMarket,
      products: products ?? this.products,
    );
  }
}

final salesProvider = StateNotifierProvider<SalesNotifier, SalesState>((ref) {
  return SalesNotifier(ref);
});

final totalRevenueProvider = Provider<double>((ref) {
  final sales = ref.watch(salesProvider).sales;
  return sales.fold(0, (total, sale) => total + sale.total);
});

class SalesNotifier extends StateNotifier<SalesState> {
  final Ref _ref;

  SalesNotifier(this._ref) : super(SalesState()) {
    loadSales();
    loadProducts();
  }

  Future<void> loadSales() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      debugPrint('Loading sales...');
      final authState = _ref.read(authProvider);

      if (!authState.isAuthenticated) {
        debugPrint('User not authenticated');
        state = state.copyWith(
          isLoading: false,
          error: 'Please log in to view sales',
        );
        return;
      }

      // Check if user is management or vendor
      final isManagement = authState.isManagement;
      final vendorId = authState.vendor?.id;

      debugPrint('Is management: $isManagement');
      debugPrint('Vendor ID: $vendorId');

      // Build the query
      var query = supabase.from('sales').select('*, products(*), markets(*)');

      // Apply filters
      if (state.startDate != null && state.endDate != null) {
        debugPrint(
          'Filtering by date range: ${state.startDate} to ${state.endDate}',
        );
        query = query
            .gte('created_at', state.startDate!.toIso8601String())
            .lte('created_at', state.endDate!.toIso8601String());
      }

      if (state.selectedMarketId != null) {
        debugPrint('Filtering by market ID: ${state.selectedMarketId}');
        // Use non-null assertion (!) to fix the linter error
        query = query.eq('market_id', state.selectedMarketId!);
      }

      if (!isManagement && vendorId != null) {
        debugPrint('Filtering by vendor ID: $vendorId');
        query = query.eq('vendor_id', vendorId);
      }

      // Execute the query
      debugPrint('Executing sales query...');
      final response = await query;
      debugPrint('Received ${response.length} sales records');

      // Process the response
      final salesList = <Sale>[];
      for (var item in response) {
        try {
          final sale = Sale.fromMap(item);
          salesList.add(sale);
        } catch (e) {
          debugPrint('Error parsing sale data: $e');
          debugPrint('Problematic data: $item');
        }
      }

      // Apply search filter locally if needed
      if (state.searchQuery != null && state.searchQuery!.isNotEmpty) {
        final query = state.searchQuery!.toLowerCase();
        debugPrint('Applying search filter: $query');

        final filteredSales =
            salesList.where((sale) {
              final marketName = sale.marketName.toLowerCase();
              final productName = sale.productName.toLowerCase();
              final notes = sale.notes?.toLowerCase() ?? '';

              return marketName.contains(query) ||
                  productName.contains(query) ||
                  notes.contains(query);
            }).toList();

        salesList.clear();
        salesList.addAll(filteredSales);
      }

      // Sort by date (newest first)
      salesList.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Update state
      state = state.copyWith(sales: salesList, isLoading: false);

      debugPrint('Sales loaded successfully: ${salesList.length} records');
    } catch (e) {
      debugPrint('Error loading sales: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load sales: $e',
      );
    }
  }

  Future<void> loadMarketData(String marketId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      debugPrint('Loading market data for ID: $marketId');

      final marketData =
          await supabase.from('markets').select().eq('id', marketId).single();

      state = state.copyWith(
        selectedMarket: marketData,
        selectedMarketId: marketId,
        isLoading: false,
      );

      debugPrint('Market data loaded: ${marketData['name']}');
    } catch (e) {
      debugPrint('Error loading market data: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load market data: $e',
      );
    }
  }

  Future<void> loadProducts() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      debugPrint('Loading products...');

      final response = await supabase.from('products').select();

      state = state.copyWith(
        products: List<Map<String, dynamic>>.from(response),
        isLoading: false,
      );

      debugPrint('Products loaded: ${response.length}');
    } catch (e) {
      debugPrint('Error loading products: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load products: $e',
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
      debugPrint('Recording sale...');
      final authState = _ref.read(authProvider);

      if (!authState.isAuthenticated || authState.vendor == null) {
        throw Exception('You must be logged in to record a sale');
      }

      // Get product and market names
      final product = state.products.firstWhere(
        (p) => p['id'] == productId,
        orElse: () => throw Exception('Product not found'),
      );

      final marketName = state.selectedMarket?['name'] ?? 'Unknown Market';
      final productName = product['name'] ?? 'Unknown Product';

      // Calculate total
      final total = quantity * unitPrice;
      final finalTotal = discount != null ? total - discount : total;

      // Create sale object
      final sale = {
        'market_id': marketId,
        'product_id': productId,
        'vendor_id': authState.vendor!.id,
        'quantity': quantity,
        'unit_price': unitPrice,
        'total': finalTotal,
        'notes': notes,
        'promotion_id': promotionId,
        'discount': discount,
        'market_name': marketName,
        'product_name': productName,
        'created_at': DateTime.now().toIso8601String(),
      };

      debugPrint('Recording sale: $sale');

      // Insert into database
      await supabase.from('sales').insert(sale);

      debugPrint('Sale recorded successfully');

      // Reload sales
      await loadSales();
    } catch (e) {
      debugPrint('Error recording sale: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to record sale: $e',
      );
    }
  }

  Future<void> addSale(Sale sale) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      debugPrint('Adding new sale: ${sale.toMap()}');

      // Insert the sale
      await supabase.from('sales').insert(sale.toMap());

      debugPrint('Sale added successfully');

      // Reload sales
      await loadSales();
    } catch (e) {
      debugPrint('Error adding sale: $e');
      state = state.copyWith(isLoading: false, error: 'Failed to add sale: $e');
    }
  }

  Future<void> deleteSale(String saleId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      debugPrint('Deleting sale with ID: $saleId');

      await supabase.from('sales').delete().eq('id', saleId);

      debugPrint('Sale deleted successfully');

      // Update local state by removing the deleted sale
      final updatedSales = state.sales.where((s) => s.id != saleId).toList();

      state = state.copyWith(sales: updatedSales, isLoading: false);
    } catch (e) {
      debugPrint('Error deleting sale: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to delete sale: $e',
      );
    }
  }

  void setDateRange(DateTime start, DateTime end) {
    debugPrint('Setting date range: $start to $end');

    state = state.copyWith(startDate: start, endDate: end);
    loadSales();
  }

  void setSearchQuery(String query) {
    debugPrint('Setting search query: $query');

    state = state.copyWith(searchQuery: query);
    loadSales();
  }

  void setSelectedMarket(String? marketId) {
    debugPrint('Setting market filter: $marketId');

    state = state.copyWith(selectedMarketId: marketId);
    if (marketId != null) {
      loadMarketData(marketId);
    }
    loadSales();
  }

  void clearFilters() {
    debugPrint('Clearing all filters');

    state = state.copyWith(
      startDate: null,
      endDate: null,
      searchQuery: null,
      selectedMarketId: null,
    );
    loadSales();
  }
}
