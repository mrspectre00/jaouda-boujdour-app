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

      if (!authState.isAuthenticated || authState.vendor == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'User not authenticated or vendor profile missing',
        );
        return;
      }

      // Initialize counters with safe defaults
      int todaySalesCount = 0;
      double todayRevenue = 0.0;
      int marketsCount = 0;
      int activeMarketsCount = 0;
      int stockCount = 0;
      int promoCount = 0;
      List<Sale> recentSales = [];

      try {
        final today = DateTime.now();
        final startOfDay = DateTime(today.year, today.month, today.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));

        // Fetch today's sales
        try {
          final salesData = await supabase
              .from('sales')
              .select()
              .gte('created_at', startOfDay.toIso8601String())
              .lt('created_at', endOfDay.toIso8601String());

          final todaySales =
              salesData
                  .map((data) {
                    try {
                      return Sale.fromMap(data);
                    } catch (e) {
                      print('Error parsing sale: $e');
                      return null;
                    }
                  })
                  .whereType<Sale>()
                  .toList();

          todaySalesCount = todaySales.length;
          todayRevenue = todaySales.fold<double>(
            0.0,
            (sum, sale) => sum + sale.total,
          );
        } catch (e) {
          print('Error fetching sales data: $e');
        }

        // Count markets - try without vendor_id filter first
        try {
          final marketsData = await supabase.from('markets').select().count();
          marketsCount = marketsData.count ?? 0;

          final activeMarketsData =
              await supabase
                  .from('markets')
                  .select()
                  .eq('status', 'active')
                  .count();
          activeMarketsCount = activeMarketsData.count ?? 0;
        } catch (e) {
          print('Error fetching markets count: $e');
        }

        // Try to get product count (as fallback for stock)
        try {
          final productsData = await supabase.from('products').select().count();
          stockCount = productsData.count ?? 0;
        } catch (e) {
          print('Error fetching products count: $e');
        }

        // Try to get active promotions count
        try {
          final promotionsData =
              await supabase
                  .from('promotions')
                  .select()
                  .eq('is_active', true)
                  .count();
          promoCount = promotionsData.count ?? 0;
        } catch (e) {
          print('Error fetching promotions count: $e');
        }

        // Fetch recent sales
        try {
          final recentSalesData = await supabase
              .from('sales')
              .select()
              .order('created_at', ascending: false)
              .limit(5);

          recentSales =
              recentSalesData
                  .map((data) {
                    try {
                      return Sale.fromMap(data);
                    } catch (e) {
                      print('Error parsing recent sale: $e');
                      return null;
                    }
                  })
                  .whereType<Sale>()
                  .toList();
        } catch (e) {
          print('Error fetching recent sales: $e');
        }
      } catch (e) {
        print('General error in data fetching: $e');
      }

      // Update state with whatever data we managed to fetch
      state = state.copyWith(
        isLoading: false,
        todayTotalSales: todayRevenue.toInt(),
        todaySalesCount: todaySalesCount,
        allMarketsCount: marketsCount,
        activeMarketsCount: activeMarketsCount,
        productsInStockCount: stockCount,
        activePromotionsCount: promoCount,
        recentSales: recentSales,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load dashboard data: ${e.toString()}',
      );
    }
  }
}

// Provider for dashboard state
final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
      return DashboardNotifier(ref);
    });
