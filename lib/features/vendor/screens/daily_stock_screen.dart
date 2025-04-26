import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/daily_stock_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../models/daily_stock.dart';
import '../../../widgets/app_layout.dart';

class DailyStockScreen extends ConsumerStatefulWidget {
  const DailyStockScreen({super.key});

  @override
  ConsumerState<DailyStockScreen> createState() => _DailyStockScreenState();
}

class _DailyStockScreenState extends ConsumerState<DailyStockScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dailyStockProvider.notifier).loadDailyStocks();
    });
  }

  Future<void> _showReturnDialog(DailyStock stock) async {
    final quantityController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Record Return'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Product: ${stock.product?.name ?? 'Unknown'}'),
              const SizedBox(height: 16),
              TextFormField(
                controller: quantityController,
                decoration: const InputDecoration(
                  labelText: 'Return Quantity',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a quantity';
                  }
                  final quantity = int.tryParse(value);
                  if (quantity == null || quantity <= 0) {
                    return 'Please enter a valid quantity';
                  }
                  if (quantity > stock.quantityRemaining) {
                    return 'Cannot return more than remaining stock';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              try {
                await ref.read(dailyStockProvider.notifier).recordReturn(
                      vendorId: stock.vendorId,
                      productId: stock.productId,
                      quantity: int.parse(quantityController.text),
                    );

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Return recorded successfully'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error recording return: $e')),
                  );
                }
              }
            },
            child: const Text('Record Return'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDamageDialog(DailyStock stock) async {
    final quantityController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Record Damaged Items'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Product: ${stock.product?.name ?? 'Unknown'}'),
              const SizedBox(height: 16),
              TextFormField(
                controller: quantityController,
                decoration: const InputDecoration(
                  labelText: 'Damaged Quantity',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a quantity';
                  }
                  final quantity = int.tryParse(value);
                  if (quantity == null || quantity <= 0) {
                    return 'Please enter a valid quantity';
                  }
                  if (quantity > stock.quantityRemaining) {
                    return 'Cannot record more than remaining stock';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              try {
                await ref.read(dailyStockProvider.notifier).recordDamage(
                      vendorId: stock.vendorId,
                      productId: stock.productId,
                      quantity: int.parse(quantityController.text),
                    );

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Damage recorded successfully'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error recording damage: $e')),
                  );
                }
              }
            },
            child: const Text('Record Damage'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stockState = ref.watch(dailyStockProvider);
    final authState = ref.watch(authProvider);
    final isAdmin = authState.isManagement;

    return AppLayout(
      title: 'Daily Stock',
      body: stockState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : stockState.error != null
              ? Center(child: Text(stockState.error!))
              : stockState.todayStocks.isEmpty
                  ? const Center(child: Text('No stock assigned for today'))
                  : RefreshIndicator(
                      onRefresh: () => ref
                          .read(dailyStockProvider.notifier)
                          .loadDailyStocks(),
                      child: _buildStockList(stockState.todayStocks, isAdmin),
                    ),
    );
  }

  Widget _buildStockList(List<DailyStock> stocks, bool isAdmin) {
    if (!isAdmin) {
      // Regular vendor view - simple list
      return ListView.builder(
        itemCount: stocks.length,
        itemBuilder: (context, index) {
          final stock = stocks[index];
          return _buildStockCard(stock);
        },
      );
    } else {
      // Admin view - grouped by vendor
      // First group stocks by vendor
      final Map<String, List<DailyStock>> stocksByVendor = {};

      for (final stock in stocks) {
        final vendorId = stock.vendorId;
        if (!stocksByVendor.containsKey(vendorId)) {
          stocksByVendor[vendorId] = [];
        }
        stocksByVendor[vendorId]!.add(stock);
      }

      // Build UI with expandable sections for each vendor
      return ListView.builder(
        itemCount: stocksByVendor.keys.length,
        itemBuilder: (context, index) {
          final vendorId = stocksByVendor.keys.elementAt(index);
          final vendorStocks = stocksByVendor[vendorId]!;
          final vendorName =
              vendorStocks.first.vendor?.name ?? 'Unknown Vendor';

          return ExpansionTile(
            title: Text('Vendor: $vendorName'),
            subtitle: Text('${vendorStocks.length} products assigned'),
            initiallyExpanded: true,
            children:
                vendorStocks.map((stock) => _buildStockCard(stock)).toList(),
          );
        },
      );
    }
  }

  Widget _buildStockCard(DailyStock stock) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      child: ListTile(
        title: Text(stock.product?.name ?? 'Unknown Product'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Assigned: ${stock.quantityAssigned}'),
            Text('Sold: ${stock.quantitySold}'),
            Text('Returned: ${stock.quantityReturned}'),
            Text('Damaged: ${stock.quantityDamaged}'),
            Text(
              'Remaining: ${stock.quantityRemaining}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.assignment_return),
              onPressed: () => _showReturnDialog(stock),
              tooltip: 'Record Return',
            ),
            IconButton(
              icon: const Icon(Icons.warning),
              onPressed: () => _showDamageDialog(stock),
              tooltip: 'Record Damage',
            ),
          ],
        ),
      ),
    );
  }
}
