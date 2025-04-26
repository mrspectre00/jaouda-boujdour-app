import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../models/sale.dart';
import '../../../widgets/app_layout.dart';
import '../providers/sales_provider.dart';

class SalesListScreen extends ConsumerStatefulWidget {
  const SalesListScreen({super.key});

  @override
  ConsumerState<SalesListScreen> createState() => _SalesListScreenState();
}

class _SalesListScreenState extends ConsumerState<SalesListScreen> {
  final TextEditingController _searchController = TextEditingController();
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    // Load sales when the screen initializes
    Future.microtask(() => ref.read(salesProvider.notifier).loadSales());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final lastMonth = now.subtract(const Duration(days: 30));

    final initialDateRange =
        _selectedDateRange ?? DateTimeRange(start: lastMonth, end: now);

    final pickedDateRange = await showDateRangePicker(
      context: context,
      initialDateRange: initialDateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDateRange != null) {
      setState(() {
        _selectedDateRange = pickedDateRange;
      });

      // Update provider with new date range
      ref
          .read(salesProvider.notifier)
          .setDateRange(pickedDateRange.start, pickedDateRange.end);
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedDateRange = null;
      _searchController.clear();
    });

    ref.read(salesProvider.notifier).clearFilters();
  }

  void _applySearch(String query) {
    ref.read(salesProvider.notifier).setSearchQuery(query);
  }

  @override
  Widget build(BuildContext context) {
    final salesState = ref.watch(salesProvider);
    final sales = salesState.sales;
    final isLoading = salesState.isLoading;
    final error = salesState.error;

    return AppLayout(
      title: 'Sales Records',
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () {
            context.go('/markets');
          },
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: isLoading
              ? null
              : () => ref.read(salesProvider.notifier).loadSales(),
        ),
      ],
      body: Column(
        children: [
          // Filter bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                // Search field
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search sales...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onSubmitted: _applySearch,
                  ),
                ),
                const SizedBox(width: 8),
                // Date filter button
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      _selectedDateRange != null
                          ? '${DateFormat('MM/dd').format(_selectedDateRange!.start)} - ${DateFormat('MM/dd').format(_selectedDateRange!.end)}'
                          : 'Date Range',
                    ),
                    onPressed: _selectDateRange,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Clear filters button
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: _clearFilters,
                  tooltip: 'Clear filters',
                ),
              ],
            ),
          ),

          // Total amount summary
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 8.0,
              horizontal: 16.0,
            ),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Sales: ${sales.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Consumer(
                    builder: (context, ref, _) {
                      final totalRevenue = ref.watch(totalRevenueProvider);
                      return Text(
                        'Total Revenue: \$${totalRevenue.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Error message
          if (error != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),

          // Sales list
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : sales.isEmpty
                    ? const Center(
                        child: Text(
                          'No sales found. Try adjusting your filters.',
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () =>
                            ref.read(salesProvider.notifier).loadSales(),
                        child: ListView.builder(
                          itemCount: sales.length,
                          itemBuilder: (context, index) {
                            final sale = sales[index];
                            return SaleListItem(
                              sale: sale,
                              onDelete: () {
                                ref
                                    .read(salesProvider.notifier)
                                    .deleteSale(sale.id);
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.go('/markets');
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class SaleListItem extends StatelessWidget {
  final Sale sale;
  final VoidCallback onDelete;

  const SaleListItem({super.key, required this.sale, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy - HH:mm');
    final formattedDate = dateFormat.format(sale.createdAt);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () {
          context.go('/sales/detail/${sale.id}');
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      sale.productName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '\$${sale.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Market: ${sale.marketName}'),
              Text(
                'Quantity: ${sale.quantity} × \$${sale.unitPrice.toStringAsFixed(2)}',
              ),
              if (sale.notes != null && sale.notes!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Notes: ${sale.notes}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formattedDate,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Sale'),
                          content: const Text(
                            'Are you sure you want to delete this sale? This action cannot be undone.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                onDelete();
                                Navigator.pop(context);
                              },
                              child: const Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    splashRadius: 24,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
