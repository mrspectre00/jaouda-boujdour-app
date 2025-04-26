import 'package:flutter/material.dart';
import '../models/sale.dart';
import '../services/supabase_client.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  bool _isLoading = true;
  List<Sale> _sales = [];
  String _selectedPeriod = 'Today';
  final List<String> _periods = ['Today', 'This Week', 'This Month', 'All Time'];

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  Future<void> _loadSales() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = supabase.auth.currentUser!.id;
      
      // Determine date range based on selected period
      DateTime startDate;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      switch (_selectedPeriod) {
        case 'Today':
          startDate = today;
          break;
        case 'This Week':
          startDate = today.subtract(Duration(days: today.weekday - 1));
          break;
        case 'This Month':
          startDate = DateTime(now.year, now.month, 1);
          break;
        case 'All Time':
        default:
          startDate = DateTime(2000); // Far in the past
          break;
      }
      
      // Query sales records
      final data = await supabase
          .from('sales_records')
          .select('''
            *,
            items:sales_items(*)
          ''')
          .eq('vendor_id', userId)
          .gte('created_at', startDate.toIso8601String())
          .order('created_at', ascending: false);
      
      // Parse data into Sale objects
      final sales = data.map((item) => Sale.fromJson(item)).toList();
      
      if (mounted) {
        setState(() {
          _sales = sales as List<Sale>;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading sales: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading sales: ${e.toString()}'))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales History'),
        actions: [
          DropdownButton<String>(
            value: _selectedPeriod,
            icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
            style: const TextStyle(color: Colors.white),
            dropdownColor: Theme.of(context).primaryColor,
            underline: Container(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedPeriod = newValue;
                });
                _loadSales();
              }
            },
            items: _periods.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sales.isEmpty
              ? Center(child: Text('No sales found for $_selectedPeriod'))
              : ListView.builder(
                  itemCount: _sales.length,
                  itemBuilder: (context, index) {
                    final sale = _sales[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ExpansionTile(
                        title: Text('Sale #${sale.id.substring(0, 8)}'),
                        subtitle: Text(
                          'Amount: $${sale.totalAmount.toStringAsFixed(2)} • ${sale.createdAt.toString().substring(0, 16)}',
                        ),
                        children: [
                          if (sale.items != null && sale.items!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  ...sale.items!.map((item) => FutureBuilder(
                                    future: supabase
                                        .from('products')
                                        .select('name')
                                        .eq('id', item.productId)
                                        .single(),
                                    builder: (context, snapshot) {
                                      final productName = snapshot.hasData
                                          ? snapshot.data['name']
                                          : 'Loading...';
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 4.0),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('$productName x ${item.quantity}'),
                                            Text('$${(item.unitPrice * item.quantity).toStringAsFixed(2)}'),
                                          ],
                                        ),
                                      );
                                    },
                                  )).toList(),
                                  const Divider(),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Total:', style: TextStyle(fontWeight: FontWeight.bold)),
                                      Text('$${sale.totalAmount.toStringAsFixed(2)}', 
                                        style: const TextStyle(fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}