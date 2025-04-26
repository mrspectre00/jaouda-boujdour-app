import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';
import '../models/stock.dart';
import '../models/stock_update.dart';
import '../providers/auth_provider.dart';

// Supabase provider
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final stockProvider = StateNotifierProvider<StockNotifier, StockState>((ref) {
  return StockNotifier(ref: ref);
});

class StockState {
  final List<Stock> stock;
  final List<StockUpdate> stockHistory;
  final bool isLoading;
  final String? error;

  StockState({
    this.stock = const [],
    this.stockHistory = const [],
    this.isLoading = false,
    this.error,
  });

  StockState copyWith({
    List<Stock>? stock,
    List<StockUpdate>? stockHistory,
    bool? isLoading,
    String? error,
  }) {
    return StockState(
      stock: stock ?? this.stock,
      stockHistory: stockHistory ?? this.stockHistory,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  static StockState initial() {
    return StockState();
  }
}

class StockNotifier extends StateNotifier<StockState> {
  final Ref ref;
  late final SupabaseClient _client;
  RealtimeChannel? _stockChannel;
  bool _isRealtimeActive = false;

  StockNotifier({required this.ref}) : super(StockState.initial()) {
    _client = Supabase.instance.client;
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _stockChannel?.unsubscribe();
    super.dispose();
  }

  void _setupRealtimeSubscription() async {
    final vendorId = ref.read(authProvider).user?.id;
    if (vendorId == null) return;

    // Close existing channel if any
    await _stockChannel?.unsubscribe();

    // Create a new channel for stock table
    _stockChannel = _client.channel('stock_channel');

    // Subscribe to changes using the correct API
    _stockChannel = _stockChannel!
        .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'stock',
            filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'vendor_id',
                value: vendorId),
            callback: (payload) {
              // Reload stocks when new data arrives
              loadStock();
            })
        .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'stock',
            filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'vendor_id',
                value: vendorId),
            callback: (payload) {
              // Reload stocks when data is updated
              loadStock();
            });

    // Subscribe to the channel
    _stockChannel!.subscribe();
    _isRealtimeActive = true;
  }

  Future<void> loadStock() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final currentUserId = ref.read(authProvider).user?.id;
      if (currentUserId == null) {
        throw Exception('No user ID available');
      }

      print('Loading stock for vendor: $currentUserId');

      // First, try to find a valid vendor ID
      String vendorId;

      try {
        // Check if the current user is a vendor
        final vendorResponse = await _client
            .from('vendors')
            .select('id')
            .eq('user_id', currentUserId)
            .limit(1);

        if (vendorResponse.isNotEmpty) {
          // If the current user is a vendor, use their ID
          vendorId = vendorResponse[0]['id'];
        } else {
          // Check if the user ID itself is a vendor ID
          final directVendorResponse = await _client
              .from('vendors')
              .select('id')
              .eq('id', currentUserId)
              .limit(1);

          if (directVendorResponse.isNotEmpty) {
            vendorId = currentUserId;
          } else {
            // If not, get the first vendor from the table
            final firstVendorResponse =
                await _client.from('vendors').select('id').limit(1);

            if (firstVendorResponse.isEmpty) {
              throw Exception('No vendors found in the database');
            }

            vendorId = firstVendorResponse[0]['id'];
          }
        }

        print('Using vendor ID for loading stock: $vendorId');
      } catch (e) {
        print('Error finding valid vendor ID: $e');
        throw Exception('Failed to find a valid vendor ID: $e');
      }

      final response = await _client
          .from('stock')
          .select('*, product:products(*)')
          .eq('vendor_id', vendorId)
          .order('created_at', ascending: false);

      final stock =
          (response as List).map((json) => Stock.fromJson(json)).toList();

      state = state.copyWith(stock: stock, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        error: 'Error loading stock: $e',
        isLoading: false,
      );
    }
  }

  Future<void> loadStockHistory() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final currentUserId = ref.read(authProvider).user?.id;
      if (currentUserId == null) {
        throw Exception('No user ID available');
      }

      print('Loading stock history');

      // First, try to find a valid vendor ID
      String vendorId;

      try {
        // Check if the current user is a vendor
        final vendorResponse = await _client
            .from('vendors')
            .select('id')
            .eq('user_id', currentUserId)
            .limit(1);

        if (vendorResponse.isNotEmpty) {
          // If the current user is a vendor, use their ID
          vendorId = vendorResponse[0]['id'];
        } else {
          // Check if the user ID itself is a vendor ID
          final directVendorResponse = await _client
              .from('vendors')
              .select('id')
              .eq('id', currentUserId)
              .limit(1);

          if (directVendorResponse.isNotEmpty) {
            vendorId = currentUserId;
          } else {
            // If not, get the first vendor from the table
            final firstVendorResponse =
                await _client.from('vendors').select('id').limit(1);

            if (firstVendorResponse.isEmpty) {
              throw Exception('No vendors found in the database');
            }

            vendorId = firstVendorResponse[0]['id'];
          }
        }

        print('Using vendor ID for loading stock history: $vendorId');
      } catch (e) {
        print('Error finding valid vendor ID: $e');
        throw Exception('Failed to find a valid vendor ID: $e');
      }

      // Since stock_updates table doesn't have vendor_id, we'll join with stock table
      final response = await _client
          .from('stock_updates')
          .select('*, product:products(*)')
          .order('created_at', ascending: false);

      print('Loaded ${response.length} stock history records');

      // Filter history to show only updates for products that our vendor has in stock
      final stockResponse = await _client
          .from('stock')
          .select('product_id')
          .eq('vendor_id', vendorId);

      final vendorProductIds = (stockResponse as List)
          .map((item) => item['product_id'] as String)
          .toSet();

      print('Vendor has ${vendorProductIds.length} products in stock');

      final filteredHistory = (response as List)
          .where((item) => vendorProductIds.contains(item['product_id']))
          .toList();

      print(
          'Filtered to ${filteredHistory.length} relevant stock history records');

      final history =
          filteredHistory.map((json) => StockUpdate.fromJson(json)).toList();

      state = state.copyWith(stockHistory: history, isLoading: false);
    } catch (e) {
      print('Error loading stock history: $e');
      state = state.copyWith(
        error: 'Error loading stock history: $e',
        isLoading: false,
      );
    }
  }

  Future<String> updateStock({
    required Product product,
    required int quantityChange,
    required StockUpdateType updateType,
    String? notes,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final currentUserId = ref.read(authProvider).user?.id;
      if (currentUserId == null) {
        state = state.copyWith(isLoading: false, error: 'No user ID available');
        return 'Error: No user ID available';
      }

      // First, try to find a valid vendor ID
      String vendorId;

      try {
        // Check if the current user is a vendor
        final vendorResponse = await _client
            .from('vendors')
            .select('id')
            .eq('user_id', currentUserId)
            .limit(1);

        if (vendorResponse.isNotEmpty) {
          // If the current user is a vendor, use their ID
          vendorId = vendorResponse[0]['id'];
        } else {
          // Check if the user ID itself is a vendor ID
          final directVendorResponse = await _client
              .from('vendors')
              .select('id')
              .eq('id', currentUserId)
              .limit(1);

          if (directVendorResponse.isNotEmpty) {
            vendorId = currentUserId;
          } else {
            // If not, get the first vendor from the table
            final firstVendorResponse =
                await _client.from('vendors').select('id').limit(1);

            if (firstVendorResponse.isEmpty) {
              state = state.copyWith(
                  isLoading: false, error: 'No vendors found in the database');
              return 'Error: No vendors found in the database';
            }

            vendorId = firstVendorResponse[0]['id'];
          }
        }

        print('Using vendor ID for updating stock: $vendorId');
      } catch (e) {
        print('Error finding valid vendor ID: $e');
        state = state.copyWith(
            isLoading: false, error: 'Failed to find a valid vendor ID: $e');
        return 'Error: Failed to find a valid vendor ID: $e';
      }

      print(
          'Updating stock: ${product.name}, change: $quantityChange, type: $updateType, vendor: $vendorId');

      // Get current stock from database to ensure we have fresh data
      print(
          'Checking if product ${product.id} exists in stock table for vendor $vendorId');
      final existingStockData = await _client
          .from('stock')
          .select()
          .eq('product_id', product.id)
          .eq('vendor_id', vendorId);

      print('Existing stock data: $existingStockData');

      int previousQuantity = 0;
      int newQuantity = quantityChange;
      bool productTableUpdated = false;
      bool stockTableUpdated = false;

      if (existingStockData.isEmpty) {
        // No stock record exists, create one
        print('No existing stock found, creating new record');

        try {
          await _client.from('stock').insert({
            'product_id': product.id,
            'vendor_id': vendorId,
            'quantity': quantityChange,
          });
          stockTableUpdated = true;

          // Also update the product's stockQuantity field
          try {
            await _client.from('products').update(
                {'stock_quantity': quantityChange}).eq('id', product.id);
            productTableUpdated = true;
          } catch (productError) {
            print('Error updating product table: $productError');
            // Continue even if product table update fails
          }
        } catch (e) {
          // If the insert fails, try to update instead
          print('Error creating stock record: $e');
          print('Trying to fetch stock again...');

          final checkStock = await _client
              .from('stock')
              .select()
              .eq('product_id', product.id)
              .eq('vendor_id', vendorId);

          if (checkStock.isNotEmpty) {
            final stockRecord = checkStock[0];
            previousQuantity = stockRecord['quantity'];
            newQuantity = previousQuantity + quantityChange;

            try {
              await _client.from('stock').update({'quantity': newQuantity}).eq(
                  'id', stockRecord['id']);
              stockTableUpdated = true;
            } catch (stockError) {
              print('Error updating stock table: $stockError');
              throw Exception('Failed to update stock record: $stockError');
            }

            // Also update the product's stockQuantity field
            try {
              await _client
                  .from('products')
                  .update({'stock_quantity': newQuantity}).eq('id', product.id);
              productTableUpdated = true;
            } catch (productError) {
              print('Error updating product table: $productError');
              // Continue even if product table update fails
            }
          } else {
            throw Exception('Failed to create or update stock record');
          }
        }
      } else {
        // Update existing stock record
        final Map<String, dynamic> currentStock = existingStockData[0];
        final int currentQuantity = currentStock['quantity'];
        print('Found existing stock with quantity: $currentQuantity');

        previousQuantity = currentQuantity;
        newQuantity = currentQuantity + quantityChange;

        try {
          await _client
              .from('stock')
              .update({'quantity': newQuantity}).eq('id', currentStock['id']);
          stockTableUpdated = true;
        } catch (stockError) {
          print('Error updating stock table: $stockError');
          throw Exception('Failed to update stock record: $stockError');
        }

        // Also update the product's stockQuantity field
        try {
          await _client
              .from('products')
              .update({'stock_quantity': newQuantity}).eq('id', product.id);
          productTableUpdated = true;
        } catch (productError) {
          print('Error updating product table: $productError');
          // Continue even if product table update fails
        }
      }

      // Now insert the stock update record
      try {
        final stockUpdateData = {
          'product_id': product.id,
          'quantity_change': quantityChange,
          'previous_quantity': previousQuantity,
          'new_quantity': newQuantity,
          'update_type': updateType.toString().split('.').last,
          'notes': notes,
        };

        print('Inserting stock update record: $stockUpdateData');
        await _client.from('stock_updates').insert(stockUpdateData);
      } catch (e) {
        // If there's an error with the stock_updates table, we can ignore it
        // since we've already updated the main stock record
        print('Warning: Could not create stock update history record: $e');
      }

      // Reload stock and history
      print('Reloading stock and history');
      await loadStock();
      try {
        await loadStockHistory();
      } catch (e) {
        print('Warning: Error loading stock history: $e');
      }

      // Prepare success message
      String successMessage = 'Stock updated successfully';
      if (productTableUpdated && stockTableUpdated) {
        successMessage =
            'Stock updated successfully in both product and inventory tables';
      } else if (productTableUpdated) {
        successMessage =
            'Stock updated in product table only - synchronization needed';
      } else if (stockTableUpdated) {
        successMessage =
            'Stock updated in inventory table only - synchronization needed';
      }

      print(
          'Stock reload complete. Current stock items: ${state.stock.length}');
      return successMessage;
    } catch (e) {
      print('Error updating stock: $e');
      state = state.copyWith(
        error: 'Error updating stock: $e',
        isLoading: false,
      );
      return 'Error updating stock: $e';
    }
  }

  Future<void> addInventory({
    required String productId,
    required int quantity,
    String? notes,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final vendorId = ref.read(authProvider).user?.id;
      if (vendorId == null) {
        throw Exception('No vendor ID available');
      }

      print('Adding inventory: Product=$productId, Quantity=$quantity');

      // Check if a stock record exists for this product
      final existingStockData = await _client
          .from('stock')
          .select()
          .eq('product_id', productId)
          .eq('vendor_id', vendorId);

      print('Existing stock data: $existingStockData');

      // Handle add inventory
      if (existingStockData.isEmpty) {
        // No stock record exists, create one
        print('No existing stock found, creating new record');

        await _client.from('stock').insert({
          'product_id': productId,
          'vendor_id': vendorId,
          'quantity': quantity,
        });

        print('New stock record created for inventory');
      } else {
        // Update existing stock record
        final currentStock = existingStockData[0];
        final currentQuantity = currentStock['quantity'] as int;

        await _client
            .from('stock')
            .update({'quantity': currentQuantity + quantity}).eq(
                'id', currentStock['id']);

        print(
            'Inventory updated. Previous: $currentQuantity, New: ${currentQuantity + quantity}');
      }

      // Create stock update record
      try {
        await _client.from('stock_updates').insert({
          'product_id': productId,
          'quantity_change': quantity,
          'previous_quantity':
              existingStockData.isEmpty ? 0 : existingStockData[0]['quantity'],
          'new_quantity': existingStockData.isEmpty
              ? quantity
              : existingStockData[0]['quantity'] + quantity,
          'update_type': 'inventory',
          'notes': notes ?? 'Inventory addition',
        });
      } catch (e) {
        print('Warning: Failed to create stock update record: $e');
      }

      // Reload stock
      await loadStock();
    } catch (e) {
      print('Error adding inventory: $e');
      state = state.copyWith(
        error: 'Error adding inventory: $e',
        isLoading: false,
      );
    }
  }

  Future<String> adjustStock({
    required Product product,
    required int newQuantity,
    String? notes,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final currentUserId = ref.read(authProvider).user?.id;
      if (currentUserId == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'No user ID available',
        );
        return 'Error: No user ID available';
      }

      // First, try to find a valid vendor ID using the same approach as loadStock
      String vendorId;

      try {
        // Check if the current user is a vendor
        final vendorResponse = await _client
            .from('vendors')
            .select('id')
            .eq('user_id', currentUserId)
            .limit(1);

        if (vendorResponse.isNotEmpty) {
          // If the current user is a vendor, use their ID
          vendorId = vendorResponse[0]['id'];
        } else {
          // Check if the user ID itself is a vendor ID
          final directVendorResponse = await _client
              .from('vendors')
              .select('id')
              .eq('id', currentUserId)
              .limit(1);

          if (directVendorResponse.isNotEmpty) {
            vendorId = currentUserId;
          } else {
            // If not, get the first vendor from the table
            final firstVendorResponse =
                await _client.from('vendors').select('id').limit(1);

            if (firstVendorResponse.isEmpty) {
              state = state.copyWith(
                  isLoading: false, error: 'No vendors found in the database');
              return 'Error: No vendors found in the database';
            }

            vendorId = firstVendorResponse[0]['id'];
          }
        }

        print('Using vendor ID for adjusting stock: $vendorId');
      } catch (e) {
        print('Error finding valid vendor ID: $e');
        state = state.copyWith(
            isLoading: false, error: 'Failed to find a valid vendor ID: $e');
        return 'Error: Failed to find a valid vendor ID: $e';
      }

      // Validate new quantity
      if (newQuantity < 0) {
        state = state.copyWith(
          isLoading: false,
          error: 'Stock quantity cannot be negative',
        );
        return 'Error: Stock quantity cannot be negative';
      }

      // Get current stock from database to ensure we have fresh data
      print(
          'Checking current stock for product ${product.id}, vendor $vendorId');
      final existingStockData = await _client
          .from('stock')
          .select()
          .eq('product_id', product.id)
          .eq('vendor_id', vendorId);

      int currentQuantity = 0;
      String stockRecordId = '';

      if (existingStockData.isNotEmpty) {
        final Map<String, dynamic> currentStock = existingStockData[0];
        currentQuantity = currentStock['quantity'];
        stockRecordId = currentStock['id'];
        print('Found existing stock with quantity: $currentQuantity');
      } else {
        print('No existing stock found for this product');
      }

      // Calculate the quantity change
      final quantityChange = newQuantity - currentQuantity;
      print('Calculated quantity change: $quantityChange');

      // If there is no change, don't update
      if (quantityChange == 0) {
        state = state.copyWith(isLoading: false);
        return 'No change needed - quantity already at $newQuantity';
      }

      bool stockTableUpdated = false;
      bool productTableUpdated = false;

      // Use a transaction pattern to manage updates
      try {
        if (existingStockData.isEmpty) {
          // No stock record exists, create one
          print('Creating new stock record with quantity $newQuantity');

          await _client.from('stock').insert({
            'product_id': product.id,
            'vendor_id': vendorId,
            'quantity': newQuantity,
          });
          stockTableUpdated = true;
        } else {
          // Update existing stock record
          print('Updating stock record to quantity $newQuantity');

          await _client
              .from('stock')
              .update({'quantity': newQuantity}).eq('id', stockRecordId);
          stockTableUpdated = true;
        }

        // Update the product's stockQuantity field
        print('Updating product stock_quantity to $newQuantity');
        await _client
            .from('products')
            .update({'stock_quantity': newQuantity}).eq('id', product.id);
        productTableUpdated = true;

        // Create a stock update record for history tracking
        print('Creating stock update history record');
        final stockUpdateData = {
          'product_id': product.id,
          'quantity_change': quantityChange,
          'previous_quantity': currentQuantity,
          'new_quantity': newQuantity,
          'update_type': StockUpdateType.adjustment.toString().split('.').last,
          'notes': notes ?? 'Adjusted to $newQuantity',
        };

        try {
          await _client.from('stock_updates').insert(stockUpdateData);
          print('Stock update history record created successfully');
        } catch (e) {
          // Non-critical error, just log it
          print('Warning: Could not create stock update history record: $e');
        }

        // Reload stock data to reflect the changes
        print('Reloading stock data');
        await loadStock();
        await loadStockHistory();

        state = state.copyWith(isLoading: false);
        return 'Stock adjusted successfully to $newQuantity';
      } catch (e) {
        print('Error performing stock adjustment: $e');
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to adjust stock: $e',
        );
        return 'Error: Failed to adjust stock: $e';
      }
    } catch (e) {
      print('Error in adjustStock: $e');
      state = state.copyWith(
        error: 'Error adjusting stock: $e',
        isLoading: false,
      );
      return 'Error adjusting stock: $e';
    }
  }

  Future<String> addStock({
    required Product product,
    required int quantity,
    String? notes,
  }) async {
    if (quantity <= 0) {
      return 'Error: Quantity must be greater than 0';
    }

    return await updateStock(
      product: product,
      quantityChange: quantity,
      updateType: StockUpdateType.purchase,
      notes: notes,
    );
  }

  Future<String> removeStock({
    required Product product,
    required int quantity,
    String? notes,
  }) async {
    if (quantity <= 0) {
      return 'Error: Quantity must be greater than 0';
    }

    // Ensure we have enough stock
    final currentUserId = ref.read(authProvider).user?.id;
    if (currentUserId == null) {
      state = state.copyWith(
        error: 'No user ID available',
        isLoading: false,
      );
      return 'Error: No user ID available';
    }

    // First, try to find a valid vendor ID
    String vendorId;

    try {
      // Check if the current user is a vendor
      final vendorResponse = await _client
          .from('vendors')
          .select('id')
          .eq('user_id', currentUserId)
          .limit(1);

      if (vendorResponse.isNotEmpty) {
        // If the current user is a vendor, use their ID
        vendorId = vendorResponse[0]['id'];
      } else {
        // Check if the user ID itself is a vendor ID
        final directVendorResponse = await _client
            .from('vendors')
            .select('id')
            .eq('id', currentUserId)
            .limit(1);

        if (directVendorResponse.isNotEmpty) {
          vendorId = currentUserId;
        } else {
          // If not, get the first vendor from the table
          final firstVendorResponse =
              await _client.from('vendors').select('id').limit(1);

          if (firstVendorResponse.isEmpty) {
            state = state.copyWith(
                isLoading: false, error: 'No vendors found in the database');
            return 'Error: No vendors found in the database';
          }

          vendorId = firstVendorResponse[0]['id'];
        }
      }

      print('Using vendor ID for removing stock: $vendorId');
    } catch (e) {
      print('Error finding valid vendor ID: $e');
      state = state.copyWith(
          isLoading: false, error: 'Failed to find a valid vendor ID: $e');
      return 'Error: Failed to find a valid vendor ID: $e';
    }

    final existingStockData = await _client
        .from('stock')
        .select()
        .eq('product_id', product.id)
        .eq('vendor_id', vendorId);

    int currentQuantity = 0;
    if (existingStockData.isNotEmpty) {
      final Map<String, dynamic> currentStock = existingStockData[0];
      currentQuantity = currentStock['quantity'];
    }

    if (currentQuantity < quantity) {
      state = state.copyWith(
        error: 'Not enough stock available',
        isLoading: false,
      );
      return 'Error: Not enough stock available. Current: $currentQuantity, Requested: $quantity';
    }

    return await updateStock(
      product: product,
      quantityChange: -quantity,
      updateType: StockUpdateType.removal,
      notes: notes,
    );
  }

  // New method to synchronize stock counts
  Future<void> synchronizeStockCounts() async {
    try {
      final currentUserId = ref.read(authProvider).user?.id;
      if (currentUserId == null) {
        print('No user ID available for synchronization');
        return;
      }

      print('Synchronizing stock counts between products and stock tables');

      // First, find a valid vendor ID from the vendors table
      String vendorId;

      try {
        // Check if the current user is a vendor
        final vendorResponse = await _client
            .from('vendors')
            .select('id')
            .eq('user_id', currentUserId)
            .limit(1);

        if (vendorResponse.isNotEmpty) {
          // If the current user is a vendor, use their ID
          vendorId = vendorResponse[0]['id'];
        } else {
          // If not, get the first vendor from the table
          final firstVendorResponse =
              await _client.from('vendors').select('id').limit(1);

          if (firstVendorResponse.isEmpty) {
            print('No vendors found in the database');
            return;
          }

          vendorId = firstVendorResponse[0]['id'];
        }

        print('Using vendor ID for synchronization: $vendorId');
      } catch (e) {
        print('Error finding valid vendor ID: $e');
        return;
      }

      // Get all products
      final productsResponse = await _client.from('products').select();
      final products = productsResponse as List;

      // Get all stock for this vendor
      final stockResponse =
          await _client.from('stock').select().eq('vendor_id', vendorId);
      final stockItems = stockResponse as List;

      // Create a map of product_id to stock quantity for faster lookup
      final stockMap = Map.fromEntries(
        stockItems.map(
          (item) =>
              MapEntry(item['product_id'] as String, item['quantity'] as int),
        ),
      );

      // For each product, check if its stock_quantity matches the stock table
      for (final product in products) {
        final productId = product['id'] as String;
        final productStockQuantity = product['stock_quantity'] as int?;
        final stockQuantity = stockMap[productId];

        if (stockQuantity != null && productStockQuantity != stockQuantity) {
          // If stock table and product table don't match, update the product table
          print(
              'Synchronizing product $productId: product table shows ${productStockQuantity ?? 0}, stock table shows $stockQuantity');
          await _client
              .from('products')
              .update({'stock_quantity': stockQuantity}).eq('id', productId);
        } else if (stockQuantity == null &&
            productStockQuantity != null &&
            productStockQuantity > 0) {
          // If product has stock but no stock record, create one
          print(
              'Creating missing stock record for product $productId with quantity $productStockQuantity');
          await _client.from('stock').insert({
            'product_id': productId,
            'vendor_id': vendorId,
            'quantity': productStockQuantity,
          });
        }
      }

      print('Stock synchronization completed');

      // Reload stock to reflect changes
      await loadStock();
    } catch (e) {
      print('Error synchronizing stock counts: $e');
    }
  }
}

// Provider for total products in stock
final productsInStockProvider = Provider<int>((ref) {
  final stocks = ref.watch(stockProvider).stock;
  return stocks.length;
});

// Provider for total quantity of all products
final totalStockQuantityProvider = Provider<int>((ref) {
  final stocks = ref.watch(stockProvider).stock;
  return stocks.fold(0, (total, stock) => total + stock.quantity);
});
