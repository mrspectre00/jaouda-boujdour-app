import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class SummaryState {
  final bool isLoading;
  final String? error;
  final double totalSales;
  final int totalProducts;
  final int marketsVisited;
  final int totalMarkets;
  final int stockRemaining;
  final int stockReturned;
  final List<double> salesData;
  final List<String> timeLabels;
  final double maxSalesValue;
  final int stockStatus;
  final List<double> salesChartData;
  final int marketsToVisit;
  final int marketsClosed;
  final int marketsNoNeed;

  const SummaryState({
    this.isLoading = false,
    this.error,
    this.totalSales = 0.0,
    this.totalProducts = 0,
    this.marketsVisited = 0,
    this.totalMarkets = 0,
    this.stockRemaining = 0,
    this.stockReturned = 0,
    this.salesData = const [],
    this.timeLabels = const [],
    this.maxSalesValue = 0.0,
    this.stockStatus = 0,
    this.salesChartData = const [],
    this.marketsToVisit = 0,
    this.marketsClosed = 0,
    this.marketsNoNeed = 0,
  });

  SummaryState copyWith({
    bool? isLoading,
    String? error,
    double? totalSales,
    int? totalProducts,
    int? marketsVisited,
    int? totalMarkets,
    int? stockRemaining,
    int? stockReturned,
    List<double>? salesData,
    List<String>? timeLabels,
    double? maxSalesValue,
    int? stockStatus,
    List<double>? salesChartData,
    int? marketsToVisit,
    int? marketsClosed,
    int? marketsNoNeed,
  }) {
    return SummaryState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      totalSales: totalSales ?? this.totalSales,
      totalProducts: totalProducts ?? this.totalProducts,
      marketsVisited: marketsVisited ?? this.marketsVisited,
      totalMarkets: totalMarkets ?? this.totalMarkets,
      stockRemaining: stockRemaining ?? this.stockRemaining,
      stockReturned: stockReturned ?? this.stockReturned,
      salesData: salesData ?? this.salesData,
      timeLabels: timeLabels ?? this.timeLabels,
      maxSalesValue: maxSalesValue ?? this.maxSalesValue,
      stockStatus: stockStatus ?? this.stockStatus,
      salesChartData: salesChartData ?? this.salesChartData,
      marketsToVisit: marketsToVisit ?? this.marketsToVisit,
      marketsClosed: marketsClosed ?? this.marketsClosed,
      marketsNoNeed: marketsNoNeed ?? this.marketsNoNeed,
    );
  }
}

class SummaryNotifier extends StateNotifier<SummaryState> {
  SummaryNotifier() : super(const SummaryState());

  Future<void> loadSummary() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // TODO: Replace with actual API call
      await Future.delayed(const Duration(seconds: 1));

      // Mock data for demonstration
      final salesData = [100.0, 150.0, 200.0, 180.0, 250.0, 300.0];
      final timeLabels = ['9AM', '11AM', '1PM', '3PM', '5PM', '7PM'];

      state = state.copyWith(
        isLoading: false,
        totalSales: 1180.0,
        totalProducts: 45,
        marketsVisited: 8,
        totalMarkets: 12,
        stockRemaining: 15,
        stockReturned: 5,
        salesData: salesData,
        timeLabels: timeLabels,
        maxSalesValue: 350.0,
        stockStatus: 75,
        salesChartData: salesData,
        marketsToVisit: 3,
        marketsClosed: 1,
        marketsNoNeed: 0,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load daily summary: $e',
      );
    }
  }

  Future<void> exportToPDF() async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          build:
              (context) => [
                pw.Header(
                  level: 0,
                  child: pw.Text(
                    'Daily Sales Summary',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Date: ${DateTime.now().toString().split(' ')[0]}',
                  style: const pw.TextStyle(fontSize: 14),
                ),
                pw.SizedBox(height: 20),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatCard(
                      'Total Sales',
                      '\$${state.totalSales.toStringAsFixed(2)}',
                    ),
                    _buildStatCard(
                      'Total Products',
                      state.totalProducts.toString(),
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatCard(
                      'Markets Visited',
                      '${state.marketsVisited}/${state.totalMarkets}',
                    ),
                    _buildStatCard('Stock Status', '${state.stockStatus}%'),
                  ],
                ),
                pw.SizedBox(height: 30),
                pw.Text(
                  'Sales Over Time',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                _buildSalesChart(context),
              ],
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File('${output.path}/daily_summary.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles([XFile(file.path)], text: 'Daily Sales Summary');
    } catch (e) {
      state = state.copyWith(error: 'Failed to export PDF: $e');
    }
  }

  pw.Widget _buildStatCard(String title, String value) {
    return pw.Container(
      width: 200,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSalesChart(pw.Context context) {
    const chartHeight = 200.0;
    const chartWidth = 500.0;
    final maxValue = state.maxSalesValue;
    final barSpacing = chartWidth / state.salesChartData.length;
    final barWidth = barSpacing * 0.6;

    return pw.Container(
      height: chartHeight + 40, // Extra space for labels
      width: chartWidth,
      child: pw.Stack(
        children: [
          // Y-axis grid lines
          pw.Column(
            children: List.generate(5, (index) {
              final y = chartHeight - (chartHeight * index / 4);
              final value = (maxValue * index / 4).toStringAsFixed(0);
              return pw.Container(
                height: chartHeight / 4,
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(color: PdfColors.grey200),
                  ),
                ),
                child: pw.Row(
                  children: [
                    pw.SizedBox(
                      width: 30,
                      child: pw.Text(
                        value,
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
          // Bars
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: List.generate(state.salesChartData.length, (index) {
              final value = state.salesChartData[index];
              final height = (value / maxValue) * chartHeight;
              return pw.Container(
                width: barSpacing,
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Container(
                      width: barWidth,
                      height: height,
                      color: PdfColors.blue400,
                    ),
                    pw.SizedBox(height: 5),
                    pw.Transform.rotate(
                      angle: -0.5,
                      child: pw.Text(
                        state.timeLabels[index],
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Future<void> sendReport() async {
    // TODO: Implement email report
    await Future.delayed(const Duration(seconds: 1));
  }
}

final summaryProvider = StateNotifierProvider<SummaryNotifier, SummaryState>((
  ref,
) {
  return SummaryNotifier();
});
