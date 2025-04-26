import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/product.dart';
import '../../../providers/stock_provider.dart';
import '../../../services/supabase_client.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  List<Product> _products = [];
  Product? _selectedProduct;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final productsData = await supabase.from('products').select();

      setState(() {
        _products = productsData.map((data) => Product.fromJson(data)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to load products: $e';
      });
    }
  }

  Future<void> _addInventory() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a product')),
      );
      return;
    }

    try {
      await ref.read(stockProvider.notifier).addInventory(
            productId: _selectedProduct!.id,
            quantity: int.parse(_quantityController.text),
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inventory added successfully')),
        );

        // Reset the form
        setState(() {
          _selectedProduct = null;
          _quantityController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding inventory: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final stockState = ref.watch(stockProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Inventory')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      ElevatedButton(
                        onPressed: _loadProducts,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<Product>(
                          value: _selectedProduct,
                          decoration: const InputDecoration(
                            labelText: 'Select Product',
                            border: OutlineInputBorder(),
                          ),
                          items: _products.map((product) {
                            return DropdownMenuItem(
                              value: product,
                              child: Text(product.name),
                            );
                          }).toList(),
                          onChanged: stockState.isLoading
                              ? null
                              : (value) {
                                  setState(() {
                                    _selectedProduct = value;
                                  });
                                },
                          validator: (value) {
                            if (value == null) {
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
                          enabled: !stockState.isLoading,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a quantity';
                            }
                            final quantity = int.tryParse(value);
                            if (quantity == null || quantity <= 0) {
                              return 'Please enter a valid quantity';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed:
                              stockState.isLoading ? null : _addInventory,
                          child: stockState.isLoading
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Text('Adding...'),
                                  ],
                                )
                              : const Text('Add Inventory'),
                        ),
                        if (stockState.error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(
                              stockState.error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        const SizedBox(height: 32),
                        const Text(
                          'Current Inventory',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: stockState.isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : stockState.stock.isEmpty
                                  ? const Center(
                                      child: Text('No inventory found'))
                                  : ListView.builder(
                                      itemCount: stockState.stock.length,
                                      itemBuilder: (context, index) {
                                        final stock = stockState.stock[index];
                                        return Card(
                                          margin:
                                              const EdgeInsets.only(bottom: 8),
                                          child: ListTile(
                                            title: Text(stock.product.name),
                                            subtitle:
                                                Text('ID: ${stock.product.id}'),
                                            trailing: Text(
                                              'Quantity: ${stock.quantity}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
