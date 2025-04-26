import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/product.dart';
import '../../../models/vendor.dart';
import '../../../providers/daily_stock_provider.dart';
import '../../../providers/stock_provider.dart';
import '../../../services/supabase_client.dart';
import '../../../widgets/app_layout.dart';

class StockAssignmentScreen extends ConsumerStatefulWidget {
  const StockAssignmentScreen({super.key});

  @override
  ConsumerState<StockAssignmentScreen> createState() =>
      _StockAssignmentScreenState();
}

class _StockAssignmentScreenState extends ConsumerState<StockAssignmentScreen> {
  final _formKey = GlobalKey<FormState>();
  Vendor? _selectedVendor;
  Product? _selectedProduct;
  final _quantityController = TextEditingController();
  final _percentageController = TextEditingController();
  List<Vendor> _vendors = [];
  List<Product> _products = [];
  bool _isLoadingData = true;
  String? _loadingError;
  bool _isAssigningStock = false;
  bool _isPercentageBased = false;
  int _currentStockQuantity = 0;

  @override
  void initState() {
    super.initState();
    _loadVendorsAndProducts();
    _percentageController.addListener(_updateQuantityFromPercentage);
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _percentageController.dispose();
    super.dispose();
  }

  Future<void> _loadVendorsAndProducts() async {
    setState(() {
      _isLoadingData = true;
      _loadingError = null;
    });

    try {
      final vendorsData = await supabase.from('vendors').select();
      final productsData = await supabase.from('products').select();

      if (mounted) {
        setState(() {
          _vendors = vendorsData.map((data) => Vendor.fromJson(data)).toList();
          _products =
              productsData.map((data) => Product.fromJson(data)).toList();
          _isLoadingData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingError = 'Error loading data: $e';
          _isLoadingData = false;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    }
  }

  Future<void> _loadCurrentStock() async {
    if (_selectedProduct == null) return;

    try {
      // Load the current stock for the selected product
      final stockState = ref.read(stockProvider);
      final productStock = stockState.stock.firstWhere(
        (stock) => stock.product.id == _selectedProduct!.id,
        orElse: () => throw Exception('No stock found for this product'),
      );

      setState(() {
        _currentStockQuantity = productStock.quantity;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading current stock: $e')),
      );
    }
  }

  void _updateQuantityFromPercentage() {
    if (!_isPercentageBased || _currentStockQuantity <= 0) return;

    final percentage = double.tryParse(_percentageController.text) ?? 0;
    if (percentage < 0 || percentage > 100) return;

    final calculatedQuantity =
        (_currentStockQuantity * percentage / 100).round();

    // Only update if the calculated value is different to avoid recursive loop
    if (_quantityController.text != calculatedQuantity.toString()) {
      _quantityController.text = calculatedQuantity.toString();
    }
  }

  Future<void> _assignStock() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVendor == null || _selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a vendor and product')),
      );
      return;
    }

    setState(() {
      _isAssigningStock = true;
    });

    try {
      final quantity = int.parse(_quantityController.text);

      await ref.read(dailyStockProvider.notifier).assignStock(
            vendorId: _selectedVendor!.id,
            productId: _selectedProduct!.id,
            quantity: quantity,
          );

      if (mounted) {
        setState(() {
          _isAssigningStock = false;
          _quantityController.clear();
          _percentageController.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock assigned successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAssigningStock = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error assigning stock: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the daily stock state to know when assignment is in progress
    final dailyStockState = ref.watch(dailyStockProvider);
    final stockState = ref.watch(stockProvider);

    return AppLayout(
      title: 'Assign Stock',
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : _loadingError != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_loadingError!,
                          style: const TextStyle(color: Colors.red)),
                      ElevatedButton(
                        onPressed: _loadVendorsAndProducts,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            DropdownButtonFormField<Vendor>(
                              value: _selectedVendor,
                              decoration: const InputDecoration(
                                labelText: 'Select Vendor',
                                border: OutlineInputBorder(),
                              ),
                              items: _vendors.map((vendor) {
                                return DropdownMenuItem(
                                  value: vendor,
                                  child: Text(vendor.name),
                                );
                              }).toList(),
                              onChanged:
                                  _isAssigningStock || dailyStockState.isLoading
                                      ? null
                                      : (value) {
                                          setState(() {
                                            _selectedVendor = value;
                                          });
                                        },
                              validator: (value) {
                                if (value == null) {
                                  return 'Please select a vendor';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
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
                              onChanged:
                                  _isAssigningStock || dailyStockState.isLoading
                                      ? null
                                      : (value) {
                                          setState(() {
                                            _selectedProduct = value;
                                          });
                                          if (value != null) {
                                            _loadCurrentStock();
                                          }
                                        },
                              validator: (value) {
                                if (value == null) {
                                  return 'Please select a product';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Current Stock Display
                            if (_selectedProduct != null &&
                                _currentStockQuantity > 0)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.inventory,
                                            color: Colors.blue),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'Current Stock: $_currentStockQuantity units',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.refresh),
                                          onPressed: _loadCurrentStock,
                                          tooltip: 'Refresh current stock',
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                            // Assignment Type Selection
                            Row(
                              children: [
                                Expanded(
                                  child: RadioListTile<bool>(
                                    title: const Text('Quantity'),
                                    value: false,
                                    groupValue: _isPercentageBased,
                                    onChanged: _isAssigningStock ||
                                            dailyStockState.isLoading
                                        ? null
                                        : (value) {
                                            setState(() {
                                              _isPercentageBased = value!;
                                              // Clear the other field
                                              _percentageController.clear();
                                            });
                                          },
                                  ),
                                ),
                                Expanded(
                                  child: RadioListTile<bool>(
                                    title: const Text('Percentage'),
                                    value: true,
                                    groupValue: _isPercentageBased,
                                    onChanged: _isAssigningStock ||
                                            dailyStockState.isLoading ||
                                            _currentStockQuantity <= 0
                                        ? null
                                        : (value) {
                                            setState(() {
                                              _isPercentageBased = value!;
                                              // Clear the other field
                                              _quantityController.clear();
                                            });
                                          },
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Conditional form fields based on selection
                            if (_isPercentageBased)
                              TextFormField(
                                controller: _percentageController,
                                decoration: const InputDecoration(
                                  labelText: 'Percentage of Current Stock',
                                  suffixText: '%',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                enabled: !(_isAssigningStock ||
                                    dailyStockState.isLoading),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a percentage';
                                  }
                                  final percentage = double.tryParse(value);
                                  if (percentage == null ||
                                      percentage <= 0 ||
                                      percentage > 100) {
                                    return 'Please enter a valid percentage (1-100)';
                                  }
                                  return null;
                                },
                              ),

                            if (!_isPercentageBased)
                              TextFormField(
                                controller: _quantityController,
                                decoration: const InputDecoration(
                                  labelText: 'Quantity',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                enabled: !(_isAssigningStock ||
                                    dailyStockState.isLoading),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a quantity';
                                  }
                                  final quantity = int.tryParse(value);
                                  if (quantity == null || quantity <= 0) {
                                    return 'Please enter a valid quantity';
                                  }
                                  if (_currentStockQuantity > 0 &&
                                      quantity > _currentStockQuantity) {
                                    return 'Quantity exceeds available stock ($_currentStockQuantity)';
                                  }
                                  return null;
                                },
                              ),

                            const SizedBox(height: 8),

                            // Display calculated quantity when percentage is selected
                            if (_isPercentageBased &&
                                _percentageController.text.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Text(
                                  'This will assign ${_quantityController.text.isEmpty ? "0" : _quantityController.text} units to the vendor',
                                  style: const TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),

                            const SizedBox(height: 16),

                            ElevatedButton(
                              onPressed: (_isAssigningStock ||
                                      dailyStockState.isLoading)
                                  ? null
                                  : _assignStock,
                              child: (_isAssigningStock ||
                                      dailyStockState.isLoading)
                                  ? const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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
                                        Text('Assigning...'),
                                      ],
                                    )
                                  : const Text('Assign Stock'),
                            ),
                            if (dailyStockState.error != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Text(
                                  dailyStockState.error!,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (_isAssigningStock || dailyStockState.isLoading)
                      const Positioned.fill(
                        child: Opacity(
                          opacity: 0.3,
                          child: ModalBarrier(
                              dismissible: false, color: Colors.grey),
                        ),
                      ),
                  ],
                ),
    );
  }
}
