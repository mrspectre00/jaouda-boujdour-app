import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../widgets/app_layout.dart';
import '../../../models/daily_stock.dart';
import '../../../models/vendor.dart';
import '../../../models/product.dart';
import '../../../providers/daily_stock_provider.dart';
import '../../../providers/vendor_provider.dart';
import '../../../providers/stock_provider.dart';
import '../../../config/theme.dart';

class InventoryAnalyticsScreen extends ConsumerStatefulWidget {
  const InventoryAnalyticsScreen({super.key});

  @override
  ConsumerState<InventoryAnalyticsScreen> createState() =>
      _InventoryAnalyticsScreenState();
}

class _InventoryAnalyticsScreenState
    extends ConsumerState<InventoryAnalyticsScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String? _selectedVendorId;
  String? _selectedProductId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    // Load necessary data
    await ref.read(dailyStockProvider.notifier).loadDailyStocks();
    await ref.read(stockProvider.notifier).loadStock();
    await ref.read(vendorProvider.notifier).loadVendors();
  }

  @override
  Widget build(BuildContext context) {
    final dailyStockState = ref.watch(dailyStockProvider);
    final vendorState = ref.watch(vendorProvider);
    final stockState = ref.watch(stockProvider);

    // Filter daily stocks based on selected criteria
    final filteredStocks = _filterDailyStocks(dailyStockState.dailyStocks);

    return AppLayout(
      title: 'Inventory Analytics',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadData,
          tooltip: 'Refresh Data',
        ),
      ],
      body: dailyStockState.isLoading ||
              vendorState.isLoading ||
              stockState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : dailyStockState.error != null
              ? Center(child: Text('Error: ${dailyStockState.error}'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFilterPanel(vendorState.vendors,
                          stockState.stock.map((s) => s.product).toList()),
                      const SizedBox(height: 24),
                      _buildSummaryCards(filteredStocks),
                      const SizedBox(height: 24),
                      _buildConversionChart(filteredStocks),
                      const SizedBox(height: 24),
                      _buildVendorPerformanceTable(filteredStocks),
                      const SizedBox(height: 24),
                      _buildStockGapAnalysis(filteredStocks),
                    ],
                  ),
                ),
    );
  }

  Widget _buildFilterPanel(List<Vendor> vendors, List<Product> products) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filters',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDateRangePicker(
                    label: 'Start Date',
                    date: _startDate,
                    onChanged: (date) {
                      if (date != null && date.isBefore(_endDate)) {
                        setState(() {
                          _startDate = date;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDateRangePicker(
                    label: 'End Date',
                    date: _endDate,
                    onChanged: (date) {
                      if (date != null && date.isAfter(_startDate)) {
                        setState(() {
                          _endDate = date;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildVendorDropdown(vendors),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildProductDropdown(products),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _startDate =
                        DateTime.now().subtract(const Duration(days: 30));
                    _endDate = DateTime.now();
                    _selectedVendorId = null;
                    _selectedProductId = null;
                  });
                },
                icon: const Icon(Icons.clear),
                label: const Text('Clear Filters'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangePicker({
    required String label,
    required DateTime date,
    required Function(DateTime?) onChanged,
  }) {
    return InkWell(
      onTap: () async {
        final selectedDate = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        onChanged(selectedDate);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('yyyy-MM-dd').format(date),
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVendorDropdown(List<Vendor> vendors) {
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(
        labelText: 'Vendor',
        border: OutlineInputBorder(),
      ),
      value: _selectedVendorId,
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text('All Vendors'),
        ),
        ...vendors.map((vendor) => DropdownMenuItem<String>(
              value: vendor.id,
              child: Text(vendor.name),
            )),
      ],
      onChanged: (value) {
        setState(() {
          _selectedVendorId = value;
        });
      },
    );
  }

  Widget _buildProductDropdown(List<Product> products) {
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(
        labelText: 'Product',
        border: OutlineInputBorder(),
      ),
      value: _selectedProductId,
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text('All Products'),
        ),
        ...products.map((product) => DropdownMenuItem<String>(
              value: product.id,
              child: Text(product.name),
            )),
      ],
      onChanged: (value) {
        setState(() {
          _selectedProductId = value;
        });
      },
    );
  }

  List<DailyStock> _filterDailyStocks(List<DailyStock> stocks) {
    return stocks.where((stock) {
      // Date range filter
      final stockDate =
          DateTime(stock.date.year, stock.date.month, stock.date.day);
      final startDate =
          DateTime(_startDate.year, _startDate.month, _startDate.day);
      final endDate = DateTime(_endDate.year, _endDate.month, _endDate.day);

      bool dateInRange = stockDate.isAtSameMomentAs(startDate) ||
          stockDate.isAtSameMomentAs(endDate) ||
          (stockDate.isAfter(startDate) && stockDate.isBefore(endDate));

      // Vendor filter
      bool vendorMatches =
          _selectedVendorId == null || stock.vendorId == _selectedVendorId;

      // Product filter
      bool productMatches =
          _selectedProductId == null || stock.productId == _selectedProductId;

      return dateInRange && vendorMatches && productMatches;
    }).toList();
  }

  Widget _buildSummaryCards(List<DailyStock> stocks) {
    // Calculate metrics for summary cards
    int totalAssigned =
        stocks.fold(0, (sum, stock) => sum + stock.quantityAssigned);
    int totalSold = stocks.fold(0, (sum, stock) => sum + stock.quantitySold);
    int totalReturned =
        stocks.fold(0, (sum, stock) => sum + stock.quantityReturned);
    int totalDamaged =
        stocks.fold(0, (sum, stock) => sum + stock.quantityDamaged);
    int totalRemaining =
        totalAssigned - (totalSold + totalReturned + totalDamaged);

    double conversionRate =
        totalAssigned > 0 ? (totalSold / totalAssigned * 100) : 0;
    double returnRate =
        totalAssigned > 0 ? (totalReturned / totalAssigned * 100) : 0;
    double damageRate =
        totalAssigned > 0 ? (totalDamaged / totalAssigned * 100) : 0;

    return GridView.count(
      crossAxisCount: 3,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildSummaryCard(
          title: 'Total Assigned',
          value: '$totalAssigned units',
          icon: Icons.assignment,
          color: Colors.blue,
        ),
        _buildSummaryCard(
          title: 'Total Sold',
          value: '$totalSold units',
          icon: Icons.shopping_cart_checkout,
          color: Colors.green,
        ),
        _buildSummaryCard(
          title: 'Conversion Rate',
          value: '${conversionRate.toStringAsFixed(1)}%',
          icon: Icons.trending_up,
          color: _getConversionColor(conversionRate),
        ),
        _buildSummaryCard(
          title: 'Total Returned',
          value: '$totalReturned units',
          icon: Icons.assignment_return,
          color: Colors.orange,
        ),
        _buildSummaryCard(
          title: 'Total Damaged',
          value: '$totalDamaged units',
          icon: Icons.dangerous,
          color: Colors.red,
        ),
        _buildSummaryCard(
          title: 'Remaining Stock',
          value: '$totalRemaining units',
          icon: Icons.inventory,
          color: Colors.purple,
        ),
      ],
    );
  }

  Color _getConversionColor(double rate) {
    if (rate >= 90) return Colors.green;
    if (rate >= 75) return Colors.lightGreen;
    if (rate >= 50) return Colors.amber;
    if (rate >= 30) return Colors.orange;
    return Colors.red;
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
                fontSize: 20,
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

  Widget _buildConversionChart(List<DailyStock> stocks) {
    // Group stocks by date
    final Map<DateTime, List<DailyStock>> stocksByDate = {};
    for (var stock in stocks) {
      final date = DateTime(stock.date.year, stock.date.month, stock.date.day);
      if (!stocksByDate.containsKey(date)) {
        stocksByDate[date] = [];
      }
      stocksByDate[date]!.add(stock);
    }

    // Create data points for the chart
    final List<DateTime> dates = stocksByDate.keys.toList()..sort();
    final List<FlSpot> assignedSpots = [];
    final List<FlSpot> soldSpots = [];

    if (dates.isNotEmpty) {
      for (int i = 0; i < dates.length; i++) {
        final date = dates[i];
        final dayStocks = stocksByDate[date]!;
        final totalAssigned =
            dayStocks.fold(0, (sum, stock) => sum + stock.quantityAssigned);
        final totalSold =
            dayStocks.fold(0, (sum, stock) => sum + stock.quantitySold);

        assignedSpots.add(FlSpot(i.toDouble(), totalAssigned.toDouble()));
        soldSpots.add(FlSpot(i.toDouble(), totalSold.toDouble()));
      }
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Conversion Trend',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildChartLegend(color: Colors.blue, label: 'Assigned'),
                const SizedBox(width: 24),
                _buildChartLegend(color: Colors.green, label: 'Sold'),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 300,
              child: dates.isEmpty
                  ? const Center(
                      child: Text('No data available for the selected period'))
                  : LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: FlTitlesData(
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (double value, TitleMeta meta) {
                                if (value >= dates.length ||
                                    value < 0 ||
                                    value % 5 != 0) {
                                  return const SizedBox.shrink();
                                }
                                final date = dates[value.toInt()];
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    DateFormat('MM/dd').format(date),
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 10,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  value.toInt().toString(),
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 10,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: assignedSpots,
                            isCurved: true,
                            color: Colors.blue,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Colors.blue.withOpacity(0.1),
                            ),
                          ),
                          LineChartBarData(
                            spots: soldSpots,
                            isCurved: true,
                            color: Colors.green,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Colors.green.withOpacity(0.1),
                            ),
                          ),
                        ],
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
                            getTooltipItems: (List<LineBarSpot> lineBarsSpot) {
                              return lineBarsSpot.map((lineBarSpot) {
                                return LineTooltipItem(
                                  lineBarSpot.y.toInt().toString(),
                                  const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              }).toList();
                            },
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartLegend({required Color color, required String label}) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }

  Widget _buildVendorPerformanceTable(List<DailyStock> stocks) {
    // Group stocks by vendor
    final Map<String, List<DailyStock>> stocksByVendor = {};
    for (var stock in stocks) {
      if (!stocksByVendor.containsKey(stock.vendorId)) {
        stocksByVendor[stock.vendorId] = [];
      }
      stocksByVendor[stock.vendorId]!.add(stock);
    }

    // Create vendor performance data
    final List<Map<String, dynamic>> vendorPerformance = [];

    stocksByVendor.forEach((vendorId, vendorStocks) {
      final vendorName = vendorStocks.first.vendor?.name ?? 'Unknown Vendor';
      final totalAssigned =
          vendorStocks.fold(0, (sum, stock) => sum + stock.quantityAssigned);
      final totalSold =
          vendorStocks.fold(0, (sum, stock) => sum + stock.quantitySold);
      final totalReturned =
          vendorStocks.fold(0, (sum, stock) => sum + stock.quantityReturned);
      final totalDamaged =
          vendorStocks.fold(0, (sum, stock) => sum + stock.quantityDamaged);

      final conversionRate =
          totalAssigned > 0 ? (totalSold / totalAssigned * 100) : 0;

      vendorPerformance.add({
        'vendorId': vendorId,
        'vendorName': vendorName,
        'totalAssigned': totalAssigned,
        'totalSold': totalSold,
        'totalReturned': totalReturned,
        'totalDamaged': totalDamaged,
        'conversionRate': conversionRate,
      });
    });

    // Sort by conversion rate (descending)
    vendorPerformance.sort((a, b) => (b['conversionRate'] as double)
        .compareTo(a['conversionRate'] as double));

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Vendor Performance',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            vendorPerformance.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                          'No vendor data available for the selected period'),
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Vendor')),
                        DataColumn(label: Text('Assigned')),
                        DataColumn(label: Text('Sold')),
                        DataColumn(label: Text('Returned')),
                        DataColumn(label: Text('Damaged')),
                        DataColumn(label: Text('Conversion')),
                      ],
                      rows: vendorPerformance.map((vendor) {
                        return DataRow(
                          cells: [
                            DataCell(Text(vendor['vendorName'] as String)),
                            DataCell(Text('${vendor['totalAssigned']}')),
                            DataCell(Text('${vendor['totalSold']}')),
                            DataCell(Text('${vendor['totalReturned']}')),
                            DataCell(Text('${vendor['totalDamaged']}')),
                            DataCell(
                              Row(
                                children: [
                                  Container(
                                    width: 60,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      color: _getConversionColor(
                                          vendor['conversionRate'] as double),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${(vendor['conversionRate'] as double).toStringAsFixed(1)}%',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockGapAnalysis(List<DailyStock> stocks) {
    // Group stocks by vendor and product
    final Map<String, Map<String, List<DailyStock>>> stocksByVendorAndProduct =
        {};

    for (var stock in stocks) {
      if (!stocksByVendorAndProduct.containsKey(stock.vendorId)) {
        stocksByVendorAndProduct[stock.vendorId] = {};
      }
      if (!stocksByVendorAndProduct[stock.vendorId]!
          .containsKey(stock.productId)) {
        stocksByVendorAndProduct[stock.vendorId]![stock.productId] = [];
      }
      stocksByVendorAndProduct[stock.vendorId]![stock.productId]!.add(stock);
    }

    // Create gap analysis data (identify areas with low conversion or high returns/damages)
    final List<Map<String, dynamic>> gapAnalysisData = [];

    stocksByVendorAndProduct.forEach((vendorId, productMap) {
      productMap.forEach((productId, productStocks) {
        final vendorName = productStocks.first.vendor?.name ?? 'Unknown Vendor';
        final productName =
            productStocks.first.product?.name ?? 'Unknown Product';

        final totalAssigned =
            productStocks.fold(0, (sum, stock) => sum + stock.quantityAssigned);
        final totalSold =
            productStocks.fold(0, (sum, stock) => sum + stock.quantitySold);
        final totalReturned =
            productStocks.fold(0, (sum, stock) => sum + stock.quantityReturned);
        final totalDamaged =
            productStocks.fold(0, (sum, stock) => sum + stock.quantityDamaged);
        final totalRemaining =
            totalAssigned - (totalSold + totalReturned + totalDamaged);

        final conversionRate =
            totalAssigned > 0 ? (totalSold / totalAssigned * 100) : 0;
        final returnRate =
            totalAssigned > 0 ? (totalReturned / totalAssigned * 100) : 0;
        final damageRate =
            totalAssigned > 0 ? (totalDamaged / totalAssigned * 100) : 0;

        // Identify potential issues
        final List<String> issues = [];
        if (conversionRate < 50 && totalAssigned > 10) {
          issues.add('Low conversion');
        }
        if (returnRate > 10) {
          issues.add('High returns');
        }
        if (damageRate > 5) {
          issues.add('High damages');
        }
        if (totalRemaining > 0 &&
            _endDate.difference(DateTime.now()).inDays <= 3) {
          issues.add('Unsold inventory');
        }

        if (issues.isNotEmpty) {
          gapAnalysisData.add({
            'vendorName': vendorName,
            'productName': productName,
            'conversionRate': conversionRate,
            'issues': issues.join(', '),
            'assigned': totalAssigned,
            'sold': totalSold,
            'remaining': totalRemaining,
          });
        }
      });
    });

    // Sort by conversion rate (ascending, so worst performers first)
    gapAnalysisData.sort((a, b) => (a['conversionRate'] as double)
        .compareTo(b['conversionRate'] as double));

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber, color: Colors.amber),
                const SizedBox(width: 8),
                const Text(
                  'Inventory Gap Analysis',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Tooltip(
                  message: 'Issues identified in inventory movement',
                  child: IconButton(
                    icon: const Icon(Icons.info_outline),
                    onPressed: () {},
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            gapAnalysisData.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                          'No inventory gaps identified for the selected period'),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: gapAnalysisData.length,
                    itemBuilder: (context, index) {
                      final gap = gapAnalysisData[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: Colors.grey.shade100,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${gap['vendorName']} - ${gap['productName']}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getConversionColor(
                                          gap['conversionRate'] as double),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${(gap['conversionRate'] as double).toStringAsFixed(1)}%',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Issues: ${gap['issues']}',
                                style: const TextStyle(
                                  color: Colors.red,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text('Assigned: ${gap['assigned']}'),
                                  const SizedBox(width: 16),
                                  Text('Sold: ${gap['sold']}'),
                                  const SizedBox(width: 16),
                                  Text(
                                    'Remaining: ${gap['remaining']}',
                                    style: TextStyle(
                                      color: gap['remaining'] > 0
                                          ? Colors.red
                                          : Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
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
}
