import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/supabase_client.dart';

class EndDayScreen extends StatefulWidget {
  const EndDayScreen({super.key});

  @override
  State<EndDayScreen> createState() => _EndDayScreenState();
}

class _EndDayScreenState extends State<EndDayScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _inventory = [];
  Map<String, int> _returnQuantities = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = supabase.auth.currentUser!.id;
      
      final data = await supabase
          .from('vendor_inventory')
          .select('*, products(*)')
          .eq('vendor_id', userId)
          .gt('quantity', 0);
      
      final returnQuantities = <String, int>{};
      for (final item in data) {
        returnQuantities[item['product_id']] = 0;
      }
      
      if (mounted) {
        setState(() {
          _inventory = data;
          _returnQuantities = returnQuantities;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading inventory: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _updateReturnQuantity(String productId, int quantity, int maxQuantity) {
    setState(() {
      _returnQuantities[productId] = quantity > maxQuantity ? maxQuantity : quantity;
    });
  }

  Future<void> _submitReturns() async {
    // Check if any products are being returned
    final hasReturns = _returnQuantities.values.any((quantity) => quantity > 0);
    if (!hasReturns) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one product to return')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final userId = supabase.auth.currentUser!.id;
      final timestamp = DateTime.now().toIso8601String();
      
      // 1. Create a return record
      final returnRecord = await supabase
          .from('product_returns')
          .insert({
            'vendor_id': userId,
            'return_date': timestamp,
            'notes': 'End of day return',
          })
          .select()
          .single();
      
      // 2. Process each returned product
      for (final item in _inventory) {
        final productId = item['product_id'];
        final returnQuantity = _returnQuantities[productId] ?? 0;
        
        if (returnQuantity > 0) {
          // Record the return items
          await supabase.from('return_items').insert({
            'return_id': returnRecord['id'],
            'product_id': productId,
            'quantity': returnQuantity,
          });
          
          // Update vendor inventory
          await supabase
              .from('vendor_inventory')
              .update({
                'quantity': item['quantity'] - returnQuantity,
                'updated_at': timestamp,
              })
              .eq('vendor_id', userId)
              .eq('product_id', productId);
          
          // Update central stock
          final product = await supabase
              .from('products')
              .select('central_stock_quantity')
              .eq('id', productId)
              .single();
          
          await supabase
              .from('products')
              .update({
                'central_stock_quantity': product['central_stock_quantity'] + returnQuantity,
                'updated_at': timestamp,
              })
              .eq('id', productId);
          
          // Create audit log entries
          await supabase.from('stock_ledger').insert([
            {
              'timestamp': timestamp,
              'type': 'return_from_vendor',
              'product_id': productId,
              'quantity_change': returnQuantity,
              'vendor_id': userId,
              'related_return_id': returnRecord['id'],
              'notes': 'End of day return from vendor',
            },
            {
              'timestamp': timestamp,
              'type': 'return_to_central',
              'product_id': productId,
              'quantity_change': returnQuantity,
              'related_return_id': returnRecord['id'],
              'notes': 'End of day return to central stock',
            }
          ]);
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Products returned successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error submitting returns: $e');
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error returning products: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('End Day - Return Products'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Enter the quantity of each product you want to return to the central stock',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: _inventory.isEmpty
                      ? const Center(child: Text('No products in inventory'))
                      : ListView.builder(
                          itemCount: _inventory.length,
                          itemBuilder: (context, index) {
                            final item = _inventory[index];
                            final product = Product.fromJson(item['products']);
                            final maxQuantity = item['quantity'] as int;
                            
                            return ListTile(
                              leading: product.imageUrl != null
                                  ? Image.network(
                                      product.imageUrl!,
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 50),
                                    )
                                  : const Icon(Icons.inventory_2, size: 50),
                              title: Text(product.name),
                              subtitle: Text('Available: $maxQuantity'),
                              trailing: SizedBox(
                                width: 120,
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove),
                                      onPressed: _returnQuantities[product.id]! > 0
                                          ? () => _updateReturnQuantity(
                                              product.id, 
                                              _returnQuantities[product.id]! - 1, 
                                              maxQuantity)
                                          : null,
                                    ),
                                    Text(
                                      '${_returnQuantities[product.id]}',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add),
                                      onPressed: _returnQuantities[product.id]! < maxQuantity
                                          ? () => _updateReturnQuantity(
                                              product.id, 
                                              _returnQuantities[product.id]! + 1, 
                                              maxQuantity)
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        spreadRadius: 1,
                        blurRadius: 5,
                        offset: const Offset(0, -3),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _submitReturns,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Submit Returns'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
} 