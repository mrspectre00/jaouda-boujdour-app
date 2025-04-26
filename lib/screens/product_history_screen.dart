import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/supabase_client.dart';

class ProductHistoryScreen extends StatefulWidget {
  final Product product;

  const ProductHistoryScreen({super.key, required this.product});

  @override
  State<ProductHistoryScreen> createState() => _ProductHistoryScreenState();
}

class _ProductHistoryScreenState extends State<ProductHistoryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _ledgerEntries = [];

  @override
  void initState() {
    super.initState();
    _loadProductHistory();
  }

  Future<void> _loadProductHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = supabase.auth.currentUser!.id;
      
      // Load the stock ledger entries for this product and this vendor
      final data = await supabase
          .from('stock_ledger')
          .select('*')
          .eq('product_id', widget.product.id)
          .eq('vendor_id', userId)
          .order('timestamp', ascending: false);
      
      if (mounted) {
        setState(() {
          _ledgerEntries = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading product history: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatType(String type) {
    switch (type) {
      case 'allocate_to_vendor':
        return 'Received from Stock';
      case 'sale':
        return 'Sold to Market';
      case 'return_from_vendor':
        return 'Returned to Stock';
      case 'record_spoilage':
        return 'Spoilage Collected';
      default:
        return type.replaceAll('_', ' ').toUpperCase();
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'allocate_to_vendor':
        return Colors.green;
      case 'sale':
        return Colors.blue;
      case 'return_from_vendor':
        return Colors.orange;
      case 'record_spoilage':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'allocate_to_vendor':
        return Icons.add_box;
      case 'sale':
        return Icons.shopping_cart;
      case 'return_from_vendor':
        return Icons.keyboard_return;
      case 'record_spoilage':
        return Icons.delete_outline;
      default:
        return Icons.history;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.product.name} History'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Product info header
                Container(
                  padding: const EdgeInsets.all(16.0),
                  color: Colors.blue.shade50,
                  child: Row(
                    children: [
                      widget.product.imageUrl != null
                          ? Image.network(
                              widget.product.imageUrl!,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 80),
                            )
                          : const Icon(Icons.inventory_2, size: 80),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.product.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Price: \$${widget.product.price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // History header
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Text(
                        'Movement History',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_ledgerEntries.length} records',
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // History list
                Expanded(
                  child: _ledgerEntries.isEmpty
                      ? const Center(child: Text('No history found for this product'))
                      : ListView.builder(
                          itemCount: _ledgerEntries.length,
                          itemBuilder: (context, index) {
                            final entry = _ledgerEntries[index];
                            final type = entry['type'] as String;
                            final quantity = entry['quantity_change'] as int;
                            final timestamp = DateTime.parse(entry['timestamp']);
                            final formattedDate = '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
                            
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                                vertical: 4.0,
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: _getTypeColor(type).withOpacity(0.2),
                                  child: Icon(
                                    _getTypeIcon(type),
                                    color: _getTypeColor(type),
                                  ),
                                ),
                                title: Text(_formatType(type)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Date: $formattedDate'),
                                    if (entry['notes'] != null)
                                      Text(
                                        entry['notes'] as String,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                                trailing: Text(
                                  'Qty: $quantity',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _getTypeColor(type),
                                  ),
                                ),
                                isThreeLine: entry['notes'] != null,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
} 