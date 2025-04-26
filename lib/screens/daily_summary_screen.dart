import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DailySummaryScreen extends StatefulWidget {
  const DailySummaryScreen({super.key});

  @override
  State<DailySummaryScreen> createState() => _DailySummaryScreenState();
}

class _DailySummaryScreenState extends State<DailySummaryScreen> {
  bool _isLoading = true;
  late Map<String, dynamic> _summaryData;
  final DateFormat _dateFormat = DateFormat('EEEE, MMMM d, yyyy');
  final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: 'MAD ',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _loadSummaryData();
  }

  // Load mock summary data
  Future<void> _loadSummaryData() async {
    // In a real app, this would be fetched from a backend
    await Future.delayed(
      const Duration(milliseconds: 800),
    ); // Simulate network delay

    final mockSummaryData = {
      'date': DateTime.now(),
      'markets_visited': [
        {
          'id': '1',
          'name': 'Supermarket Central',
          'status': 'visited_sale',
          'time': '09:30 AM',
        },
        {
          'id': '2',
          'name': 'Corner Grocery',
          'status': 'visited_sale',
          'time': '11:15 AM',
        },
        {
          'id': '3',
          'name': 'Mini Market Express',
          'status': 'visited_no_sale',
          'time': '02:45 PM',
        },
      ],
      'total_sales': 2850.50,
      'products_sold': [
        {
          'product_id': 'p1',
          'product_name': 'Milk 1L',
          'quantity': 45,
          'total_amount': 337.50,
        },
        {
          'product_id': 'p2',
          'product_name': 'Yogurt Pack (4)',
          'quantity': 60,
          'total_amount': 612.00,
        },
        {
          'product_id': 'p3',
          'product_name': 'Cheese 500g',
          'quantity': 25,
          'total_amount': 625.00,
        },
        {
          'product_id': 'p4',
          'product_name': 'Butter 250g',
          'quantity': 30,
          'total_amount': 499.50,
        },
        {
          'product_id': 'p5',
          'product_name': 'Ice Cream 1L',
          'quantity': 33,
          'total_amount': 776.50,
        },
      ],
      'returned_stock': [
        {
          'product_id': 'p3',
          'product_name': 'Cheese 500g',
          'quantity': 3,
          'reason': 'Damaged packaging',
        },
      ],
      'spoiled_stock': [
        {
          'product_id': 'p5',
          'product_name': 'Ice Cream 1L',
          'quantity': 2,
          'reason': 'Melted during transport',
        },
      ],
    };

    setState(() {
      _summaryData = mockSummaryData;
      _isLoading = false;
    });
  }

  // Get color for market status
  Color _getStatusColor(String status) {
    switch (status) {
      case 'visited_sale':
        return Colors.green;
      case 'visited_no_sale':
        return Colors.red;
      case 'to_visit':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  // Get icon for market status
  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'visited_sale':
        return Icons.check_circle;
      case 'visited_no_sale':
        return Icons.cancel;
      case 'to_visit':
        return Icons.schedule;
      default:
        return Icons.help;
    }
  }

  // Get text for market status
  String _getStatusText(String status) {
    switch (status) {
      case 'visited_sale':
        return 'Sale Made';
      case 'visited_no_sale':
        return 'No Sale';
      case 'to_visit':
        return 'Need to Visit';
      default:
        return 'Unknown';
    }
  }

  // Export summary (placeholder)
  void _exportSummary() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Summary exported successfully (placeholder)'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Summary'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Export Summary',
            onPressed: _isLoading ? null : _exportSummary,
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date
                    Text(
                      _dateFormat.format(_summaryData['date']),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Summary card
                    Card(
                      margin: EdgeInsets.zero,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Sales Summary',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildSummaryRow(
                              'Markets Visited',
                              _summaryData['markets_visited'].length.toString(),
                              Icons.store,
                              Colors.blue,
                            ),
                            const Divider(),
                            _buildSummaryRow(
                              'Total Sales Value',
                              _currencyFormat.format(
                                _summaryData['total_sales'],
                              ),
                              Icons.payments,
                              Colors.green,
                            ),
                            const Divider(),
                            _buildSummaryRow(
                              'Products Sold',
                              _summaryData['products_sold']
                                  .fold(
                                    0,
                                    (sum, item) => sum + item['quantity'],
                                  )
                                  .toString(),
                              Icons.inventory_2,
                              Colors.purple,
                            ),
                            if (_summaryData['returned_stock'].isNotEmpty) ...[
                              const Divider(),
                              _buildSummaryRow(
                                'Returned Stock',
                                _summaryData['returned_stock']
                                    .fold(
                                      0,
                                      (sum, item) => sum + item['quantity'],
                                    )
                                    .toString(),
                                Icons.assignment_return,
                                Colors.orange,
                              ),
                            ],
                            if (_summaryData['spoiled_stock'].isNotEmpty) ...[
                              const Divider(),
                              _buildSummaryRow(
                                'Spoiled Stock',
                                _summaryData['spoiled_stock']
                                    .fold(
                                      0,
                                      (sum, item) => sum + item['quantity'],
                                    )
                                    .toString(),
                                Icons.delete,
                                Colors.red,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Markets visited
                    const Text(
                      'Markets Visited',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      margin: EdgeInsets.zero,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _summaryData['markets_visited'].length,
                        separatorBuilder:
                            (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final market = _summaryData['markets_visited'][index];
                          return ListTile(
                            title: Text(market['name']),
                            subtitle: Text('Visited at ${market['time']}'),
                            leading: CircleAvatar(
                              backgroundColor: _getStatusColor(
                                market['status'],
                              ).withOpacity(0.2),
                              child: Icon(
                                _getStatusIcon(market['status']),
                                color: _getStatusColor(market['status']),
                              ),
                            ),
                            trailing: Chip(
                              label: Text(
                                _getStatusText(market['status']),
                                style: TextStyle(
                                  color: _getStatusColor(market['status']),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              backgroundColor: _getStatusColor(
                                market['status'],
                              ).withOpacity(0.1),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Products sold
                    const Text(
                      'Products Sold',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      margin: EdgeInsets.zero,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _summaryData['products_sold'].length,
                        separatorBuilder:
                            (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final product = _summaryData['products_sold'][index];
                          return ListTile(
                            title: Text(product['product_name']),
                            subtitle: Text('Quantity: ${product['quantity']}'),
                            trailing: Text(
                              _currencyFormat.format(product['total_amount']),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Returned stock section
                    if (_summaryData['returned_stock'].isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Returned Stock',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        margin: EdgeInsets.zero,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _summaryData['returned_stock'].length,
                          separatorBuilder:
                              (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = _summaryData['returned_stock'][index];
                            return ListTile(
                              title: Text(item['product_name']),
                              subtitle: Text('Reason: ${item['reason']}'),
                              trailing: Chip(
                                label: Text(
                                  'Qty: ${item['quantity']}',
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                backgroundColor: Colors.orange.withOpacity(0.1),
                              ),
                            );
                          },
                        ),
                      ),
                    ],

                    // Spoiled stock section
                    if (_summaryData['spoiled_stock'].isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Spoiled Stock',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        margin: EdgeInsets.zero,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _summaryData['spoiled_stock'].length,
                          separatorBuilder:
                              (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = _summaryData['spoiled_stock'][index];
                            return ListTile(
                              title: Text(item['product_name']),
                              subtitle: Text('Reason: ${item['reason']}'),
                              trailing: Chip(
                                label: Text(
                                  'Qty: ${item['quantity']}',
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                backgroundColor: Colors.red.withOpacity(0.1),
                              ),
                            );
                          },
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // Export button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _exportSummary,
                        icon: const Icon(Icons.download),
                        label: const Text(
                          'EXPORT SUMMARY',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
