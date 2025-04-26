import 'package:flutter/material.dart';
import '../models/market.dart';
import '../models/product.dart';
import '../services/supabase_client.dart';

class RecordSpoilageScreen extends StatefulWidget {
  final Market market;

  const RecordSpoilageScreen({super.key, required this.market});

  @override
  State<RecordSpoilageScreen> createState() => _RecordSpoilageScreenState();
}

class _RecordSpoilageScreenState extends State<RecordSpoilageScreen> {
  bool _isLoading = true;
  List<Product> _products = [];
  Map<String, int> _quantities = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load all available products for spoilage recording
      final data = await supabase
          .from('products')
          .select('*')
          .order('name');
      
      final products = data
          .map((item) => Product.fromJson(item))
          .toList();
      
      // Initialize quantities map
      final quantities = <String, int>{};
      for (final product in products) {
        quantities[product.id] = 0;
      }
      
      if (mounted) {
        setState(() {
          _products = products;
          _quantities = quantities;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading products: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _updateQuantity(String productId, int quantity) {
    setState(() {
      _quantities[productId] = quantity;
    });
  }

  Future<void> _saveSpoilageRecord() async {
    // Check if any products were selected
    final hasProducts = _quantities.values.any((quantity) => quantity > 0);
    if (!hasProducts) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one expired product')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final userId = supabase.auth.currentUser!.id;
      
      // Create spoilage record
      final spoilageRecord = await supabase
          .from('spoilage_records')
          .insert({
            'vendor_id': userId,
            'market_id': widget.market.id,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();
      
      // Create spoilage items
      final spoilageItems = <Map<String, dynamic>>[];
      for (final product in _products) {
        final quantity = _quantities[product.id] ?? 0;
        if (quantity > 0) {
          spoilageItems.add({
            'spoilage_record_id': spoilageRecord['id'],
            'product_id': product.id,
            'quantity': quantity,
          });
        }
      }
      
      await supabase.from('spoilage_items').insert(spoilageItems);
      
      // Also create a stockLedger entry for audit purposes
      for (final product in _products) {
        final quantity = _quantities[product.id] ?? 0;
        if (quantity > 0) {
          await supabase.from('stock_ledger').insert({
            'timestamp': DateTime.now().toIso8601String(),
            'type': 'record_spoilage',
            'product_id': product.id,
            'quantity_change': quantity,
            'vendor_id': userId,
            'market_id': widget.market.id,
            'related_spoilage_id': spoilageRecord['id'],
            'notes': 'Spoiled products collected from ${widget.market.name}',
          });
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Spoilage record saved successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error saving spoilage record: $e');
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error recording spoilage: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Record Spoilage - ${widget.market.name}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Record expired or spoiled products collected from this market',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: _products.isEmpty
                      ? const Center(child: Text('No products available'))
                      : ListView.builder(
                          itemCount: _products.length,
                          itemBuilder: (context, index) {
                            final product = _products[index];
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
                              subtitle: const Text('Expired/Spoiled'),
                              trailing: SizedBox(
                                width: 120,
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove),
                                      onPressed: _quantities[product.id]! > 0
                                          ? () => _updateQuantity(product.id, _quantities[product.id]! - 1)
                                          : null,
                                    ),
                                    Text(
                                      '${_quantities[product.id]}',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add),
                                      onPressed: () => _updateQuantity(product.id, _quantities[product.id]! + 1),
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
                      onPressed: _isSaving ? null : _saveSpoilageRecord,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                      ),
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Save Spoilage Record'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
} 