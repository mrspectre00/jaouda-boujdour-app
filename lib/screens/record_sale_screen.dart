import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RecordSaleScreen extends StatefulWidget {
  final Map<String, dynamic> market;

  const RecordSaleScreen({super.key, required this.market});

  @override
  State<RecordSaleScreen> createState() => _RecordSaleScreenState();
}

class _RecordSaleScreenState extends State<RecordSaleScreen> {
  final List<Map<String, dynamic>> _products = [];
  final Map<String, int> _quantities = {};
  final Map<String, String> _promotions = {};
  final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: 'MAD ',
    decimalDigits: 2,
  );
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  // Load mock product data
  void _loadProducts() {
    // In a real app, this would fetch data from an API or local database
    final mockProducts = [
      {
        'id': 'p1',
        'name': 'Milk 1L',
        'price': 7.50,
        'available_promotions': [
          {'id': 'promo1', 'name': 'Buy 10 get 1 free', 'discount': 0.1},
          {'id': 'promo2', 'name': 'Summer discount', 'discount': 0.05},
        ],
      },
      {
        'id': 'p2',
        'name': 'Yogurt Pack (4)',
        'price': 12.00,
        'available_promotions': [
          {'id': 'promo3', 'name': '15% off', 'discount': 0.15},
        ],
      },
      {
        'id': 'p3',
        'name': 'Cheese 500g',
        'price': 25.00,
        'available_promotions': [],
      },
      {
        'id': 'p4',
        'name': 'Butter 250g',
        'price': 18.50,
        'available_promotions': [
          {'id': 'promo4', 'name': '10% discount', 'discount': 0.1},
        ],
      },
      {
        'id': 'p5',
        'name': 'Ice Cream 1L',
        'price': 30.00,
        'available_promotions': [
          {'id': 'promo5', 'name': 'Buy 2 get 20% off', 'discount': 0.2},
        ],
      },
    ];

    setState(() {
      _products.addAll(mockProducts);

      // Initialize quantities to 0
      for (var product in _products) {
        _quantities[product['id']] = 0;
        _promotions[product['id']] = '';
      }
    });
  }

  // Calculate item price with promotion
  double _calculateItemPrice(String productId) {
    final product = _products.firstWhere((p) => p['id'] == productId);
    final quantity = _quantities[productId] ?? 0;
    final basePrice = product['price'] as double;

    // If no quantity or promotion, return 0
    if (quantity == 0) return 0;

    // If no promotion selected, return base price * quantity
    if (_promotions[productId]?.isEmpty ?? true) {
      return basePrice * quantity;
    }

    // Calculate price with promotion
    final selectedPromoId = _promotions[productId];
    final promo = (product['available_promotions'] as List).firstWhere(
      (p) => p['id'] == selectedPromoId,
      orElse: () => {'discount': 0.0},
    );
    final discount = promo['discount'] as double;

    return basePrice * quantity * (1 - discount);
  }

  // Calculate total sale amount
  double _calculateTotal() {
    double total = 0;
    for (var product in _products) {
      total += _calculateItemPrice(product['id']);
    }
    return total;
  }

  // Submit the sale
  void _submitSale() {
    setState(() {
      _isSubmitting = true;
    });

    // Create sale data
    final saleData = {
      'market_id': widget.market['id'],
      'market_name': widget.market['name'],
      'date': DateTime.now().toIso8601String(),
      'items':
          _products.where((p) => (_quantities[p['id']] ?? 0) > 0).map((p) {
            return {
              'product_id': p['id'],
              'product_name': p['name'],
              'quantity': _quantities[p['id']],
              'unit_price': p['price'],
              'promotion_id': _promotions[p['id']],
              'total_price': _calculateItemPrice(p['id']),
            };
          }).toList(),
      'total_amount': _calculateTotal(),
    };

    // In a real app, this would be saved to a database or sent to an API
    print('Sale data: $saleData');

    // Simulate a network request
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });

        // Show success message and navigate back
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sale recorded successfully'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context, saleData);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasItems = _products.any((p) => (_quantities[p['id']] ?? 0) > 0);
    final total = _calculateTotal();

    return Scaffold(
      appBar: AppBar(
        title: Text('Record Sale - ${widget.market['name']}'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Products list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _products.length,
              itemBuilder: (context, index) {
                final product = _products[index];
                final productId = product['id'];
                final hasPromotions =
                    (product['available_promotions'] as List).isNotEmpty;

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product['name'],
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _currencyFormat.format(product['price']),
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Quantity controls
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed:
                                      _quantities[productId] == 0
                                          ? null
                                          : () {
                                            setState(() {
                                              _quantities[productId] =
                                                  (_quantities[productId] ??
                                                      0) -
                                                  1;
                                            });
                                          },
                                ),
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${_quantities[productId] ?? 0}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: () {
                                    setState(() {
                                      _quantities[productId] =
                                          (_quantities[productId] ?? 0) + 1;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),

                        // Promotions dropdown (only show if product has promotions and quantity > 0)
                        if (hasPromotions &&
                            (_quantities[productId] ?? 0) > 0) ...[
                          const SizedBox(height: 12),
                          const Divider(),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Promotion',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            value: _promotions[productId],
                            items: [
                              const DropdownMenuItem(
                                value: '',
                                child: Text('No promotion'),
                              ),
                              ...(product['available_promotions'] as List)
                                  .map<DropdownMenuItem<String>>((promo) {
                                    return DropdownMenuItem(
                                      value: promo['id'],
                                      child: Text(promo['name']),
                                    );
                                  })
                                  ,
                            ],
                            onChanged: (newValue) {
                              setState(() {
                                _promotions[productId] = newValue!;
                              });
                            },
                          ),
                        ],

                        // Show subtotal if quantity > 0
                        if ((_quantities[productId] ?? 0) > 0) ...[
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                'Subtotal: ${_currencyFormat.format(_calculateItemPrice(productId))}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Total and submit button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Sale Amount:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _currencyFormat.format(total),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: hasItems && !_isSubmitting ? _submitSale : null,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child:
                        _isSubmitting
                            ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                            : const Text(
                              'SUBMIT SALE',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
