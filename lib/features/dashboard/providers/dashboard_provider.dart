import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/sale.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/supabase_client.dart';

// Dashboard state to hold summary data
class DashboardState {
  final bool isLoading;
  final String? error;
  final int todayTotalSales;
  final int todaySalesCount;
  final int allMarketsCount;
  final int activeMarketsCount;
  final int productsInStockCount;
  final int activePromotionsCount;
  final List<Sale>? recentSales;

  DashboardState({
    this.isLoading = false,
    this.error,
    this.todayTotalSales = 0,
    this.todaySalesCount = 0,
    this.allMarketsCount = 0,
    this.activeMarketsCount = 0,
    this.productsInStockCount = 0,
    this.activePromotionsCount = 0,
    this.recentSales,
  });

  DashboardState copyWith({
    bool? isLoading,
    String? error,
    int? todayTotalSales,
    int? todaySalesCount,
    int? allMarketsCount,
    int? activeMarketsCount,
    int? productsInStockCount,
    int? activePromotionsCount,
    List<Sale>? recentSales,
  }) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      todayTotalSales: todayTotalSales ?? this.todayTotalSales,
      todaySalesCount: todaySalesCount ?? this.todaySalesCount,
      allMarketsCount: allMarketsCount ?? this.allMarketsCount,
      activeMarketsCount: activeMarketsCount ?? this.activeMarketsCount,
      productsInStockCount: productsInStockCount ?? this.productsInStockCount,
      activePromotionsCount:
          activePromotionsCount ?? this.activePromotionsCount,
      recentSales: recentSales ?? this.recentSales,
    );
  }
}

// DashboardNotifier for handling dashboard logic
class DashboardNotifier extends StateNotifier<DashboardState> {
  final Ref _ref;

  DashboardNotifier(this._ref) : super(DashboardState()) {
    loadDashboardData();
  }

  Future<void> loadDashboardData() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final authState = _ref.read(authProvider);

      if (!authState.isAuthenticated) {
        state = state.copyWith(
          isLoading: false,
          error: 'User not authenticated',
        );
        return;
      }

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Check if user is management or vendor
      final isManagement = authState.isManagement;
      final vendorId = authState.vendor?.id;

      // Initialize with default values
      List<Map<String, dynamic>> salesData = [];
      List<Map<String, dynamic>> marketsData = [];
      List<Map<String, dynamic>> activeMarketsData = [];
      List<Map<String, dynamic>> stockData = [];
      List<Map<String, dynamic>> stockInStockData = [];
      List<Map<String, dynamic>> promotionsData = [];
      List<Map<String, dynamic>> recentSalesData = [];

      // Safely fetch today's sales with date filter
      try {
        if (isManagement) {
          // Management sees all sales
          salesData = await supabase
              .from('sales')
              .select()
              .gte('created_at', startOfDay.toIso8601String())
              .lt('created_at', endOfDay.toIso8601String());
        } else if (vendorId != null) {
          // Vendors see only their sales
          salesData = await supabase
              .from('sales')
              .select()
              .eq('vendor_id', vendorId)
              .gte('created_at', startOfDay.toIso8601String())
              .lt('created_at', endOfDay.toIso8601String());
        }
      } catch (e) {
        print('Error fetching sales data: $e');
        // Keep the default empty list
      }

      // Safely process sales data
      List<Sale> todaySales = [];
      double todayRevenue = 0.0;

      try {
        todaySales =
            salesData
                .map((data) {
                  try {
                    return Sale.fromMap(data);
                  } catch (e) {
                    print('Error parsing sale: $e');
                    return null;
                  }
                })
                .where((sale) => sale != null)
                .cast<Sale>()
                .toList();

        todayRevenue = todaySales.fold<double>(
          0.0,
          (sum, sale) => sum + sale.total,
        );
      } catch (e) {
        print('Error processing sales data: $e');
        // Keep defaults
      }

      // Safely count markets
      try {
        if (isManagement) {
          // Management sees all markets
          marketsData = await supabase.from('markets').select('id');
          activeMarketsData = await supabase
              .from('markets')
              .select('id')
              .eq('status', 'active');
        } else if (vendorId != null) {
          // Vendors see only their markets
          marketsData = await supabase
              .from('markets')
              .select('id')
              .eq('vendor_id', vendorId);
          activeMarketsData = await supabase
              .from('markets')
              .select('id')
              .eq('vendor_id', vendorId)
              .eq('status', 'active');
        }
      } catch (e) {
        print('Error fetching markets data: $e');
        // Keep defaults
      }

      // Safely count stock products - skip if table doesn't exist
      try {
        if (isManagement) {
          // Check if stock table exists by making a small query first
          try {
            await supabase.from('stock').select('id').limit(1);

            // If we reach here, the table exists
            stockData = await supabase.from('stock').select('id');
            stockInStockData = await supabase
                .from('stock')
                .select('id')
                .gt('quantity', 0);
          } catch (tableError) {
            print('Stock table likely does not exist: $tableError');
            // Keep defaults
          }
        } else if (vendorId != null) {
          // Check if stock table exists by making a small query first
          try {
            await supabase.from('stock').select('id').limit(1);

            // If we reach here, the table exists
            stockData = await supabase
                .from('stock')
                .select('id')
                .eq('vendor_id', vendorId);
            stockInStockData = await supabase
                .from('stock')
                .select('id')
                .eq('vendor_id', vendorId)
                .gt('quantity', 0);
          } catch (tableError) {
            print('Stock table likely does not exist: $tableError');
            // Keep defaults
          }
        }
      } catch (e) {
        print('Error fetching stock data: $e');
        // Keep defaults
      }

      // Safely count active promotions - skip if table doesn't exist
      try {
        if (isManagement) {
          // Check if promotions table exists
          try {
            await supabase.from('promotions').select('id').limit(1);

            // If we reach here, the table exists
            promotionsData = await supabase
                .from('promotions')
                .select('id')
                .eq('is_active', true);
          } catch (tableError) {
            print('Promotions table likely does not exist: $tableError');
            // Keep defaults
          }
        } else if (vendorId != null) {
          // Check if promotions table exists
          try {
            await supabase.from('promotions').select('id').limit(1);

            // If we reach here, the table exists
            promotionsData = await supabase
                .from('promotions')
                .select('id')
                .eq('vendor_id', vendorId)
                .eq('is_active', true);
          } catch (tableError) {
            print('Promotions table likely does not exist: $tableError');
            // Keep defaults
          }
        }
      } catch (e) {
        print('Error fetching promotions data: $e');
        // Keep defaults
      }

      // Safely fetch recent sales
      try {
        if (isManagement) {
          // Management sees all recent sales
          recentSalesData = await supabase
              .from('sales')
              .select('*, products(*), markets(*)')
              .order('created_at', ascending: false)
              .limit(5);
        } else if (vendorId != null) {
          // Vendors see only their recent sales
          recentSalesData = await supabase
              .from('sales')
              .select('*, products(*), markets(*)')
              .eq('vendor_id', vendorId)
              .order('created_at', ascending: false)
              .limit(5);
        }
      } catch (e) {
        print('Error fetching recent sales: $e');
        // Keep defaults
      }

      // Safely process recent sales data
      List<Sale> recentSales = [];
      try {
        recentSales =
            recentSalesData
                .map((data) {
                  try {
                    return Sale.fromMap(data);
                  } catch (e) {
                    print("Error processing recent sale data: $e");
                    return null;
                  }
                })
                .where((sale) => sale != null)
                .cast<Sale>()
                .toList();
      } catch (e) {
        print('Error processing recent sales data: $e');
        // Keep defaults
      }

      // Update the state with all fetched data
      state = state.copyWith(
        isLoading: false,
        todayTotalSales: todayRevenue.toInt(),
        todaySalesCount: todaySales.length,
        allMarketsCount: marketsData.length,
        activeMarketsCount: activeMarketsData.length,
        productsInStockCount: stockInStockData.length,
        activePromotionsCount: promotionsData.length,
        recentSales: recentSales,
      );
    } catch (e) {
      print('Dashboard loading error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Error loading dashboard data: ${e.toString()}',
      );
    }
  }
}

// Provider for dashboard state
final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
      return DashboardNotifier(ref);
    });
