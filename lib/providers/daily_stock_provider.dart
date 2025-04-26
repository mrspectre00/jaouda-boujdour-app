import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/daily_stock.dart';
import '../providers/auth_provider.dart';
import '../providers/supabase_provider.dart' as app_supabase;
import '../providers/stock_provider.dart';

class DailyStockState {
  final bool isLoading;
  final String? error;
  final List<DailyStock> dailyStocks;
  final List<DailyStock> todayStocks;

  const DailyStockState({
    this.isLoading = false,
    this.error,
    this.dailyStocks = const [],
    this.todayStocks = const [],
  });

  DailyStockState copyWith({
    bool? isLoading,
    String? error,
    List<DailyStock>? dailyStocks,
    List<DailyStock>? todayStocks,
    bool clearError = false,
  }) {
    return DailyStockState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
      dailyStocks: dailyStocks ?? this.dailyStocks,
      todayStocks: todayStocks ?? this.todayStocks,
    );
  }
}

class DailyStockNotifier extends StateNotifier<DailyStockState> {
  final Ref _ref;
  final SupabaseClient _supabase;

  DailyStockNotifier(this._ref)
      : _supabase = _ref.read(app_supabase.supabaseProvider),
        super(const DailyStockState());

  // Get the current vendor ID from auth provider
  String? get _currentVendorId {
    final authState = _ref.read(authProvider);
    return authState.vendor?.id;
  }

  Future<void> loadDailyStocks() async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final authState = _ref.read(authProvider);
      final vendorId = authState.vendor?.id;
      final isAdmin = authState.isManagement;

      if (vendorId == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Vendor ID not available',
        );
        return;
      }

      print('Loading daily stocks. Vendor: $vendorId, isAdmin: $isAdmin');

      // Load today's stock
      final today = DateTime.now();
      final todayStr = today.toIso8601String().split('T')[0];

      try {
        // Different query based on user role
        List todayData;
        List historicalData;

        if (isAdmin) {
          // Admin sees all daily stock for all vendors
          print('Loading all daily stock for admin');
          todayData = await _supabase
              .from('vendor_daily_stock')
              .select('*, product:product_id(*), vendor:vendor_id(*)')
              .eq('date', todayStr);

          historicalData = await _supabase
              .from('vendor_daily_stock')
              .select('*, product:product_id(*), vendor:vendor_id(*)')
              .order('date', ascending: false);
        } else {
          // Regular vendor only sees their own daily stock
          print('Loading daily stock for specific vendor: $vendorId');
          todayData = await _supabase
              .from('vendor_daily_stock')
              .select('*, product:product_id(*), vendor:vendor_id(*)')
              .eq('vendor_id', vendorId)
              .eq('date', todayStr);

          historicalData = await _supabase
              .from('vendor_daily_stock')
              .select('*, product:product_id(*), vendor:vendor_id(*)')
              .eq('vendor_id', vendorId)
              .order('date', ascending: false);
        }

        print('Today data loaded successfully: ${todayData.length} items');
        print(
            'Historical data loaded successfully: ${historicalData.length} items');

        final todayStocks =
            todayData.map((item) => DailyStock.fromJson(item)).toList();

        final dailyStocks =
            historicalData.map((item) => DailyStock.fromJson(item)).toList();

        state = state.copyWith(
          isLoading: false,
          todayStocks: todayStocks,
          dailyStocks: dailyStocks,
        );
      } catch (specificError) {
        print('Specific query error: $specificError');
        rethrow;
      }
    } catch (e) {
      print('Full error details: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load daily stocks: ${e.toString()}',
      );
    }
  }

  Future<void> assignStock({
    required String vendorId,
    required String productId,
    required int quantity,
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final today = DateTime.now();
      final todayStr = today.toIso8601String().split('T')[0];

      print(
          'Assigning $quantity of product $productId to vendor $vendorId on $todayStr');

      try {
        // Step 1: First check and update the main stock (reduce inventory)
        final mainStockData = await _supabase
            .from('stock')
            .select()
            .eq('product_id', productId)
            .eq('vendor_id', _currentVendorId ?? '');

        print('Main stock data: $mainStockData');

        if (mainStockData.isEmpty) {
          throw Exception(
              'No stock available for this product in main inventory');
        }

        final mainStock = mainStockData[0];
        final currentMainQuantity = mainStock['quantity'] as int;

        if (currentMainQuantity < quantity) {
          throw Exception(
              'Not enough stock available. Available: $currentMainQuantity, Requested: $quantity');
        }

        // Step 2: Update the main stock (reduce by assigned quantity)
        await _supabase
            .from('stock')
            .update({'quantity': currentMainQuantity - quantity}).eq(
                'id', mainStock['id']);

        print(
            'Main stock reduced successfully. New quantity: ${currentMainQuantity - quantity}');

        // Step 3: Check if vendor daily stock already exists for today
        final existingStockData = await _supabase
            .from('vendor_daily_stock')
            .select()
            .eq('vendor_id', vendorId)
            .eq('product_id', productId)
            .eq('date', todayStr);

        print('Existing daily stock data: $existingStockData');

        if (existingStockData.isEmpty) {
          // No stock record exists for today, create one
          print('No existing daily stock found for today, creating new record');

          // Let's inspect the table schema first to understand what fields are available
          try {
            // First, let's get the column names of the vendor_daily_stock table
            final sampleRecord = await _supabase
                .from('vendor_daily_stock')
                .select()
                .limit(1)
                .maybeSingle();

            print(
                'Sample record fields: ${sampleRecord?.keys.toList() ?? 'No records found'}');

            // Create a record with minimum required fields
            final insertData = {
              'vendor_id': vendorId,
              'product_id': productId,
              'date': todayStr,
              'quantity_assigned': quantity,
            };

            // Only add fields that are required or known to exist
            if (sampleRecord != null) {
              if (sampleRecord.containsKey('quantity_sold')) {
                insertData['quantity_sold'] = 0;
              }
              if (sampleRecord.containsKey('quantity_returned')) {
                insertData['quantity_returned'] = 0;
              }
              if (sampleRecord.containsKey('quantity_damaged')) {
                insertData['quantity_damaged'] = 0;
              }
            }

            await _supabase.from('vendor_daily_stock').insert(insertData);
            print(
                'New daily stock record created successfully with fields: $insertData');
          } catch (e) {
            print('Error inspecting table schema: $e');

            // Fallback with minimum required fields
            await _supabase.from('vendor_daily_stock').insert({
              'vendor_id': vendorId,
              'product_id': productId,
              'date': todayStr,
              'quantity_assigned': quantity,
            });
            print('New daily stock record created with minimum fields');
          }
        } else {
          // Update existing stock
          final existingStock = existingStockData[0];
          print(
              'Updating existing daily stock record with id: ${existingStock['id']}');

          await _supabase.from('vendor_daily_stock').update({
            'quantity_assigned': existingStock['quantity_assigned'] + quantity,
          }).eq('id', existingStock['id']);

          print('Daily stock record updated successfully');
        }

        // Step 4: Also create a record in stock_updates for tracking
        try {
          await _supabase.from('stock_updates').insert({
            'product_id': productId,
            'quantity_change': -quantity,
            'previous_quantity': currentMainQuantity,
            'new_quantity': currentMainQuantity - quantity,
            'update_type': 'assigned_to_vendor',
            'notes': 'Assigned to vendor: $vendorId',
          });
          print('Stock update record created for assignment');
        } catch (e) {
          print('Warning: Could not create stock update record: $e');
          // Continue even if this fails
        }

        // Step 5: Reload both daily stocks and main inventory
        await loadDailyStocks(); // Refresh the daily stock list

        // Notify the stock provider to refresh its state
        try {
          // Use your ref to notify stock provider to reload
          // This assumes you have a stockProvider with a loadStock method
          final StockNotifier stockNotifier = _ref.read(stockProvider.notifier);
          await stockNotifier.loadStock();
          print('Main stock reloaded successfully');
        } catch (e) {
          print('Warning: Could not reload main stock: $e');
        }

        print('Daily stocks reloaded successfully');
      } catch (specificError) {
        print('Error in daily stock assignment: $specificError');
        rethrow;
      }
    } catch (e) {
      print('Failed to assign stock: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to assign stock: ${e.toString()}',
      );
    }
  }

  Future<void> recordReturn({
    required String vendorId,
    required String productId,
    required int quantity,
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final today = DateTime.now();
      final todayStr = today.toIso8601String().split('T')[0];

      await _supabase
          .from('vendor_daily_stock')
          .update({'quantity_returned': quantity})
          .eq('vendor_id', vendorId)
          .eq('product_id', productId)
          .eq('date', todayStr);

      await loadDailyStocks(); // Refresh the list
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to record return: ${e.toString()}',
      );
    }
  }

  Future<void> recordDamage({
    required String vendorId,
    required String productId,
    required int quantity,
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final today = DateTime.now();
      final todayStr = today.toIso8601String().split('T')[0];

      await _supabase
          .from('vendor_daily_stock')
          .update({'quantity_damaged': quantity})
          .eq('vendor_id', vendorId)
          .eq('product_id', productId)
          .eq('date', todayStr);

      await loadDailyStocks(); // Refresh the list
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to record damage: ${e.toString()}',
      );
    }
  }
}

final dailyStockProvider =
    StateNotifierProvider<DailyStockNotifier, DailyStockState>((ref) {
  return DailyStockNotifier(ref);
});
