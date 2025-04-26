import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/supabase_client.dart';
import 'product_history_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _inventory = [];
  double _totalInventoryValue = 0.0;

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
          .eq('vendor_id', userId);
      
      double totalValue = 0.0;
      for (final item in data) {
        final product = Product.fromJson(item['products']);
        final quantity = item['quantity'] as int;
        totalValue += product.price * quantity;
      }
      
      if (mounted) {
        setState(() {
          _inventory = data;
          _totalInventoryValue = totalValue;
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

  Future<void> _viewProductHistory(Product product) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductHistoryScreen(product: product),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Inventory summary
        Container(
          padding: const EdgeInsets.all(16.0),
          color: Colors.blue.shade50,
          child: Column(
            children: [
              Text(
                'Total Inventory: ${_inventory.length} Products',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Total Value: \$${_totalInventoryValue.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ),
        
        // Inventory list
        Expanded(
          child: _inventory.isEmpty
              ? const Center(child: Text('No inventory items found'))
              : RefreshIndicator(
                  onRefresh: _loadInventory,
                  child: ListView.builder(
                    itemCount: _inventory.length,
                    itemBuilder: (context, index) {
                      final item = _inventory[index];
                      final product = Product.fromJson(item['products']);
                      final quantity = item['quantity'] as int;
                      final value = product.price * quantity;
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 4.0,
                        ),
                        child: ListTile(
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
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Price: \$${product.price.toStringAsFixed(2)}'),
                              Text('Total Value: \$${value.toStringAsFixed(2)}'),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12.0,
                                  vertical: 6.0,
                                ),
                                decoration: BoxDecoration(
                                  color: quantity > 0 ? Colors.green.shade100 : Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  'Qty: $quantity',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: quantity > 0 ? Colors.green.shade900 : Colors.red.shade900,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.history),
                                tooltip: 'View History',
                                onPressed: () => _viewProductHistory(product),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}