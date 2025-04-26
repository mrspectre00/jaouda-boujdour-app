import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../providers/summary_provider.dart';
import '../../../widgets/app_layout.dart';

class DailySummaryScreen extends ConsumerWidget {
  const DailySummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryState = ref.watch(summaryProvider);

    return AppLayout(
      title: 'Daily Summary',
      actions: [
        IconButton(
          icon: const Icon(Icons.download),
          onPressed: () => ref.read(summaryProvider.notifier).exportToPDF(),
          tooltip: 'Download PDF',
        ),
      ],
      body: summaryState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => ref.read(summaryProvider.notifier).loadSummary(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date Header
                    Text(
                      DateFormat('EEEE, MMMM d, y').format(DateTime.now()),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    // Summary Cards
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      children: [
                        _buildSummaryCard(
                          context,
                          'Total Sales',
                          '${summaryState.totalSales} MAD',
                          Icons.attach_money,
                          Colors.green,
                        ),
                        _buildSummaryCard(
                          context,
                          'Products Sold',
                          summaryState.totalProducts.toString(),
                          Icons.shopping_bag,
                          Colors.blue,
                        ),
                        _buildSummaryCard(
                          context,
                          'Markets Visited',
                          '${summaryState.marketsVisited}/${summaryState.totalMarkets}',
                          Icons.store,
                          Colors.orange,
                        ),
                        _buildSummaryCard(
                          context,
                          'Stock Status',
                          '${summaryState.stockStatus}%',
                          Icons.inventory,
                          Colors.purple,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Sales Chart
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sales Over Time',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 200,
                              child: summaryState.salesChartData.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'No sales data available',
                                      ),
                                    )
                                  : _buildSalesChart(
                                      context,
                                      summaryState,
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Market Status
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Market Status',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),
                            _buildMarketStatusList(context, summaryState),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesChart(BuildContext context, SummaryState state) {
    return CustomPaint(
      painter: SalesChartPainter(
        data: state.salesChartData,
        maxValue: state.maxSalesValue,
      ),
    );
  }

  Widget _buildMarketStatusList(BuildContext context, SummaryState state) {
    return Column(
      children: [
        _buildMarketStatusItem(
          context,
          'To Visit',
          state.marketsToVisit,
          Colors.amber,
        ),
        _buildMarketStatusItem(
          context,
          'Visited',
          state.marketsVisited,
          Colors.green,
        ),
        _buildMarketStatusItem(
          context,
          'Closed',
          state.marketsClosed,
          Colors.red,
        ),
        _buildMarketStatusItem(
          context,
          'No Need',
          state.marketsNoNeed,
          Colors.grey,
        ),
      ],
    );
  }

  Widget _buildMarketStatusItem(
    BuildContext context,
    String status,
    int count,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(status),
          const Spacer(),
          Text(
            count.toString(),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class SalesChartPainter extends CustomPainter {
  final List<double> data;
  final double maxValue;

  SalesChartPainter({required this.data, required this.maxValue});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    final xStep = size.width / (data.length - 1);
    final yScale = size.height / maxValue;

    path.moveTo(0, size.height - data[0] * yScale);
    for (var i = 1; i < data.length; i++) {
      path.lineTo(i * xStep, size.height - data[i] * yScale);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
