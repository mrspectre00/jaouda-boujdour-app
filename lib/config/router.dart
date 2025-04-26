import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/maps/screens/map_screen.dart';
import '../features/markets/screens/markets_list_screen.dart';
import '../features/markets/screens/market_detail_screen.dart';
import '../features/markets/screens/add_market_screen.dart';
import '../features/markets/screens/review_markets_screen.dart';
import '../features/products/screens/products_management_screen.dart';
import '../features/promotions/screens/promotions_management_screen.dart';
import '../features/sales/screens/record_sale_screen.dart';
import '../features/sales/screens/sales_list_screen.dart';
import '../features/sales/screens/add_sale_screen.dart';
import '../features/sales/screens/sale_detail_screen.dart';
import '../features/sales/screens/daily_summary_screen.dart';
import '../features/sales/screens/market_selection_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/test/navigation_test_screen.dart';
import '../features/test/database_test_screen.dart';
import '../features/vendors/screens/vendors_list_screen.dart';
import '../features/stock/screens/stock_management_screen.dart';
import '../features/stock/screens/stock_dashboard_screen.dart';
import '../features/admin/screens/stock_assignment_screen.dart';
import '../features/vendor/screens/daily_stock_screen.dart';
import '../features/admin/screens/vendor_targets_screen.dart';
import '../providers/auth_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final isAuthenticated = authState.isAuthenticated;
      final isAuthRoute = state.matchedLocation == '/login';
      final isTestRoute = state.matchedLocation == '/test';
      final isManagement = authState.isManagement;

      // Allow test route without authentication
      if (isTestRoute) return null;

      // Handle vendor dashboard route
      if (state.matchedLocation == '/vendor/dashboard') {
        return '/dashboard';
      }

      // Redirect unauthenticated users to login (unless already there)
      if (!isAuthenticated && !isAuthRoute) {
        return '/login';
      }

      // Redirect authenticated users away from login to dashboard
      if (isAuthenticated && isAuthRoute) {
        return '/dashboard';
      }

      // --- Management Route Protection ---
      final managementRoutes = [
        '/vendors',
        '/review-markets',
        '/promotions',
        '/products',
        '/stock',
        '/stock/assign',
        '/stock/dashboard',
        '/targets',
        '/targets/vendor',
      ];
      if (managementRoutes.contains(state.matchedLocation) && !isManagement) {
        return '/dashboard';
      }
      // --- End Management Route Protection ---

      return null; // No redirection needed
    },
    routes: [
      // Test Route
      GoRoute(
        path: '/test',
        builder: (context, state) => const NavigationTestScreen(),
      ),

      // Database Test Route
      GoRoute(
        path: '/db-test',
        builder: (context, state) => const DatabaseTestScreen(),
      ),

      // Splash Screen
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // Auth Routes
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),

      // Main App Routes
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(path: '/map', builder: (context, state) => const MapScreen()),
      GoRoute(
        path: '/markets',
        builder: (context, state) => const MarketsListScreen(),
      ),
      GoRoute(
        path: '/markets/:id',
        builder: (context, state) {
          final marketId = state.pathParameters['id']!;
          return MarketDetailScreen(marketId: marketId);
        },
      ),
      GoRoute(
        path: '/add-market',
        builder: (context, state) => const AddMarketScreen(),
      ),
      GoRoute(
        path: '/review-markets',
        builder: (context, state) => const ReviewMarketsScreen(),
      ),
      GoRoute(
        path: '/vendors',
        builder: (context, state) => const VendorsListScreen(),
      ),
      GoRoute(
        path: '/sales',
        builder: (context, state) => const SalesListScreen(),
      ),
      GoRoute(
        path: '/add-sale/:marketId',
        builder: (context, state) =>
            AddSaleScreen(marketId: state.pathParameters['marketId']!),
      ),
      GoRoute(
        path: '/sales/detail/:saleId',
        builder: (context, state) =>
            SaleDetailScreen(saleId: state.pathParameters['saleId']!),
      ),
      // Updated route for sales/record (direct to RecordSaleScreen, no market selection required)
      GoRoute(
        path: '/sales/record',
        builder: (context, state) => const RecordSaleScreen(),
      ),
      GoRoute(
        path: '/sales/record/:marketId',
        builder: (context, state) {
          final marketId = state.pathParameters['marketId']!;
          return RecordSaleScreen(marketId: marketId);
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/products',
        builder: (context, state) => const ProductsManagementScreen(),
      ),
      GoRoute(
        path: '/promotions',
        builder: (context, state) => const PromotionsManagementScreen(),
      ),
      GoRoute(
        path: '/daily-summary',
        builder: (context, state) => const DailySummaryScreen(),
      ),

      // Stock Management Routes
      GoRoute(
        path: '/stock/dashboard',
        builder: (context, state) => const StockDashboardScreen(),
      ),
      GoRoute(
        path: '/stock',
        builder: (context, state) => const StockManagementScreen(),
      ),
      GoRoute(
        path: '/stock/assign',
        builder: (context, state) => const StockAssignmentScreen(),
      ),
      GoRoute(
        path: '/daily-stock',
        builder: (context, state) => const DailyStockScreen(),
      ),

      // Vendor Targets Routes
      GoRoute(
        path: '/targets',
        builder: (context, state) => const VendorTargetsScreen(),
      ),
      GoRoute(
        path: '/targets/vendor/:vendorId',
        builder: (context, state) {
          final vendorId = state.pathParameters['vendorId']!;
          return VendorTargetsScreen(vendorId: vendorId);
        },
      ),
    ],
    errorBuilder: (context, state) =>
        Scaffold(body: Center(child: Text('Error: ${state.error}'))),
  );
});
