import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../providers/sales_provider.dart';
import '../../../models/sale.dart';

class SaleDetailScreen extends ConsumerWidget {
  final String saleId;

  const SaleDetailScreen({super.key, required this.saleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesState = ref.watch(salesProvider);

    // Safely find the sale
    Sale? sale;
    try {
      sale = salesState.sales.firstWhere((s) => s.id == saleId);
    } catch (e) {
      // Sale not found
    }

    if (salesState.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (salesState.error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Error loading sale: ${salesState.error}',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(salesProvider.notifier).loadSales(),
                child: const Text('Retry'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go('/sales'),
                child: const Text('Back to Sales'),
              ),
            ],
          ),
        ),
      );
    }

    if (sale == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sale Not Found')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'The requested sale could not be found.',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(salesProvider.notifier).loadSales(),
                child: const Text('Refresh Sales Data'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go('/sales'),
                child: const Text('Back to Sales'),
              ),
            ],
          ),
        ),
      );
    }

    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('HH:mm');
    final formattedDate = dateFormat.format(sale.createdAt);
    final formattedTime = timeFormat.format(sale.createdAt);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sale Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: const Text('Delete Sale'),
                      content: const Text(
                        'Are you sure you want to delete this sale?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
              );

              if (confirmed == true && context.mounted) {
                try {
                  await ref.read(salesProvider.notifier).deleteSale(saleId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sale deleted successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    context.go('/sales');
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error deleting sale: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sale #${sale.id.substring(0, 8)}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$formattedDate at $formattedTime',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Details',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow('Market', sale.marketName),
                    _buildDetailRow('Product', sale.productName),
                    _buildDetailRow('Quantity', '${sale.quantity}'),
                    _buildDetailRow(
                      'Unit Price',
                      '${sale.unitPrice.toStringAsFixed(2)} MAD',
                    ),
                    _buildDetailRow(
                      'Total',
                      '${sale.total.toStringAsFixed(2)} MAD',
                    ),
                    if (sale.notes != null && sale.notes!.isNotEmpty)
                      _buildDetailRow('Notes', sale.notes!),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }
}
