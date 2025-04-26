import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/sales_provider.dart';

class AddSaleScreen extends ConsumerStatefulWidget {
  final String marketId;

  const AddSaleScreen({super.key, required this.marketId});

  @override
  ConsumerState<AddSaleScreen> createState() => _AddSaleScreenState();
}

class _AddSaleScreenState extends ConsumerState<AddSaleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _unitPriceController = TextEditingController();
  final _notesController = TextEditingController();
  String? _selectedProductId;
  String _selectedProductName = '';
  double _totalAmount = 0.0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMarketData();
  }

  Future<void> _loadMarketData() async {
    await ref.read(salesProvider.notifier).loadMarketData(widget.marketId);
  }

  void _calculateTotal() {
    final quantity = double.tryParse(_quantityController.text) ?? 0;
    final unitPrice = double.tryParse(_unitPriceController.text) ?? 0;
    setState(() {
      _totalAmount = quantity * unitPrice;
    });
  }

  Future<void> _saveSale() async {
    if (!_formKey.currentState!.validate() || _selectedProductId == null) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref
          .read(salesProvider.notifier)
          .recordSale(
            marketId: widget.marketId,
            productId: _selectedProductId!,
            quantity: double.parse(_quantityController.text),
            unitPrice: double.parse(_unitPriceController.text),
            notes: _notesController.text,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sale recorded successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error recording sale: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final salesState = ref.watch(salesProvider);
    final market = salesState.selectedMarket;
    final products = salesState.products;

    return Scaffold(
      appBar: AppBar(title: const Text('Record Sale')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              market?['name'] ?? 'Market',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              market?['address'] ?? 'Address not available',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedProductId,
                      decoration: const InputDecoration(
                        labelText: 'Product',
                        border: OutlineInputBorder(),
                      ),
                      items:
                          products.map((product) {
                            return DropdownMenuItem(
                              value: product['id'] as String,
                              child: Text(product['name'] as String),
                            );
                          }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedProductId = value;
                          _selectedProductName =
                              products.firstWhere(
                                    (p) => p['id'] == value,
                                  )['name']
                                  as String;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a product';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _quantityController,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _calculateTotal(),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter quantity';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _unitPriceController,
                      decoration: const InputDecoration(
                        labelText: 'Unit Price (MAD)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _calculateTotal(),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter unit price';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Summary',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Amount:'),
                                Text(
                                  '${_totalAmount.toStringAsFixed(2)} MAD',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saveSale,
                      child: const Text('Record Sale'),
                    ),
                  ],
                ),
              ),
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _unitPriceController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}

// Simple model classes (would typically be in separate files)
class Product {
  final String id;
  final String name;
  final double price;
  final String unit;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.unit,
  });
}

class Market {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;

  Market({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });
}
