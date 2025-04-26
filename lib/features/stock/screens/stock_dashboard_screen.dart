import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../../../models/stock.dart';
import '../../../models/stock_update.dart';
import '../../../providers/stock_provider.dart';
import '../../../widgets/app_layout.dart';

class StockDashboardScreen extends ConsumerStatefulWidget {
  const StockDashboardScreen({super.key});

  @override
  ConsumerState<StockDashboardScreen> createState() =>
      _StockDashboardScreenState();
}

class _StockDashboardScreenState extends ConsumerState<StockDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(stockProvider.notifier).loadStock();
      ref.read(stockProvider.notifier).loadStockHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final stockState = ref.watch(stockProvider);
    final totalProducts = ref.watch(productsInStockProvider);
    final totalQuantity = ref.watch(totalStockQuantityProvider);

    return AppLayout(
      title: 'Stock Dashboard',
      body: stockState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : stockState.error != null
              ? Center(child: Text('Error: ${stockState.error}'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSummaryCards(
                          totalProducts, totalQuantity, stockState),
                      const SizedBox(height: 24),
                      _buildStockChart(stockState.stock),
                      const SizedBox(height: 24),
                      _buildRecentActivities(stockState.stockHistory),
                      const SizedBox(height: 24),
                      _buildActionButtons(context),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSummaryCards(
      int totalProducts, int totalQuantity, StockState stockState) {
    // Count low stock items (less than 10 units)
    final lowStockCount =
        stockState.stock.where((stock) => stock.quantity < 10).length;

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildSummaryCard(
          title: 'Total Products',
          value: totalProducts.toString(),
          icon: Icons.category,
          color: Colors.blue,
        ),
        _buildSummaryCard(
          title: 'Total Stock',
          value: totalQuantity.toString(),
          icon: Icons.inventory_2,
          color: Colors.green,
        ),
        _buildSummaryCard(
          title: 'Low Stock Items',
          value: lowStockCount.toString(),
          icon: Icons.warning_amber,
          color: Colors.orange,
        ),
        _buildSummaryCard(
          title: 'Stock Updates',
          value: stockState.stockHistory.length.toString(),
          icon: Icons.history,
          color: Colors.purple,
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockChart(List<Stock> stocks) {
    // Take top 5 products by quantity
    final topStocks = List<Stock>.from(stocks)
      ..sort((a, b) => b.quantity.compareTo(a.quantity));

    final displayStocks = topStocks.take(5).toList();

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Products by Stock Level',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: displayStocks.isEmpty
                  ? const Center(child: Text('No stock data available'))
                  : PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: displayStocks.asMap().entries.map((entry) {
                          final index = entry.key;
                          final stock = entry.value;

                          // Calculate total quantity for percentage
                          final chartTotalQuantity = displayStocks.fold(
                            0.0,
                            (sum, item) => sum + item.quantity,
                          );

                          // Calculate percentage
                          final percentage = chartTotalQuantity > 0
                              ? (stock.quantity / chartTotalQuantity * 100)
                                  .toStringAsFixed(1)
                              : '0';

                          return PieChartSectionData(
                            value: stock.quantity.toDouble(),
                            color: stock.quantity < 10
                                ? Colors.red
                                : stock.quantity < 20
                                    ? Colors.orange
                                    : Colors.blue,
                            title: '$percentage%',
                            radius: 40,
                            titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivities(List<dynamic> activities) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Stock Activities',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Navigate to stock history screen
                    context.push('/stock');
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            activities.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No recent activities'),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: activities.length > 5 ? 5 : activities.length,
                    itemBuilder: (context, index) {
                      final activity = activities[index];
                      return ListTile(
                        leading: _getActivityIcon(activity),
                        title: Text(activity.product.name),
                        subtitle: Text(
                          '${_getActivityTypeText(activity)} - ${activity.quantityChange > 0 ? '+${activity.quantityChange}' : activity.quantityChange}',
                        ),
                        trailing: Text(
                          _formatDate(activity.createdAt),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _getActivityIcon(dynamic activity) {
    if (activity.updateType == StockUpdateType.in_) {
      return const CircleAvatar(
        backgroundColor: Colors.green,
        child: Icon(Icons.add, color: Colors.white),
      );
    } else if (activity.updateType == StockUpdateType.out) {
      return const CircleAvatar(
        backgroundColor: Colors.red,
        child: Icon(Icons.remove, color: Colors.white),
      );
    } else {
      return const CircleAvatar(
        backgroundColor: Colors.blue,
        child: Icon(Icons.edit, color: Colors.white),
      );
    }
  }

  String _getActivityTypeText(dynamic activity) {
    if (activity.updateType == StockUpdateType.in_) {
      return 'Stock Added';
    } else if (activity.updateType == StockUpdateType.out) {
      return 'Stock Removed';
    } else {
      return 'Stock Adjusted';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(
          context,
          title: 'Manage Stock',
          icon: Icons.inventory_2,
          color: Colors.blue,
          onTap: () => context.push('/stock'),
        ),
        _buildActionButton(
          context,
          title: 'Assign Stock',
          icon: Icons.assignment,
          color: Colors.green,
          onTap: () => context.push('/stock/assign'),
        ),
        _buildActionButton(
          context,
          title: 'Products',
          icon: Icons.category,
          color: Colors.purple,
          onTap: () => context.push('/products'),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 4,
        child: Container(
          width: 100,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
