import 'package:flutter/material.dart';
import '../models/market.dart';
import '../services/supabase_client.dart';
import 'record_sale_screen.dart';
import 'record_spoilage_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class MarketDetailScreen extends StatefulWidget {
  final Market market;

  const MarketDetailScreen({super.key, required this.market});

  @override
  State<MarketDetailScreen> createState() => _MarketDetailScreenState();
}

class _MarketDetailScreenState extends State<MarketDetailScreen> {
  String _visitStatus = 'Need to be Visited';
  bool _isLoading = true;
  List<Map<String, dynamic>> _salesHistory = [];

  @override
  void initState() {
    super.initState();
    _loadVisitStatus();
    _loadSalesHistory();
  }

  Future<void> _loadVisitStatus() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final today = DateTime.now().toIso8601String().split('T')[0];
      
      final data = await supabase
          .from('market_visit_status')
          .select('status')
          .eq('vendor_id', userId)
          .eq('market_id', widget.market.id)
          .eq('visit_date', today)
          .maybeSingle();
      
      if (data != null) {
        setState(() {
          _visitStatus = data['status'] as String;
        });
      }
    } catch (e) {
      debugPrint('Error loading visit status: $e');
    }
  }

  Future<void> _loadSalesHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = supabase.auth.currentUser!.id;
      
      final data = await supabase
          .from('sales_records')
          .select('*')
          .eq('vendor_id', userId)
          .eq('market_id', widget.market.id)
          .order('created_at', ascending: false)
          .limit(10);
      
      if (mounted) {
        setState(() {
          _salesHistory = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading sales history: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateVisitStatus(String status) async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final today = DateTime.now().toIso8601String().split('T')[0];
      
      await supabase
          .from('market_visit_status')
          .upsert({
            'vendor_id': userId,
            'market_id': widget.market.id,
            'status': status,
            'visit_date': today,
            'updated_at': DateTime.now().toIso8601String(),
          });
      
      setState(() {
        _visitStatus = status;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Market status updated to: $status')),
      );
    } catch (e) {
      debugPrint('Error updating visit status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update market status')),
      );
    }
  }

  Future<void> _openInMap() async {
    if (widget.market.latitude != null && widget.market.longitude != null) {
      final url = 'https://www.google.com/maps/search/?api=1&query=${widget.market.latitude},${widget.market.longitude}';
      final uri = Uri.parse(url);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open map')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.market.name),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Market info card
            Card(
              margin: const EdgeInsets.all(8.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text(widget.market.address)),
                        ],
                      ),
                    ),
                    if (widget.market.phone != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            const Icon(Icons.phone, size: 20),
                            const SizedBox(width: 8),
                            Text(widget.market.phone!),
                          ],
                        ),
                      ),
                    if (widget.market.latitude != null && widget.market.longitude != null)
                      ElevatedButton.icon(
                        onPressed: _openInMap,
                        icon: const Icon(Icons.map),
                        label: const Text('View on Map'),
                      ),
                  ],
                ),
              ),
            ),
            
            // Visit status section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Today\'s Visit Status',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Current Status: $_visitStatus',
                    style: TextStyle(
                      color: _getStatusColor(_visitStatus),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatusButton('Sale Made', Colors.green),
                      _buildStatusButton('Closed', Colors.red),
                      _buildStatusButton('Don\'t Need Any Product', Colors.orange),
                    ],
                  ),
                ],
              ),
            ),
            
            // Sales history section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sales History',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _salesHistory.isEmpty
                          ? const Center(child: Text('No sales history found'))
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _salesHistory.length,
                              itemBuilder: (context, index) {
                                final sale = _salesHistory[index];
                                return ListTile(
                                  title: Text('Sale #${index + 1}'),
                                  subtitle: Text(
                                    'Amount: \$${sale['total_amount']} - ${DateTime.parse(sale['created_at']).toLocal().toString().split('.')[0]}',
                                  ),
                                  trailing: Text(
                                    sale['status'],
                                    style: TextStyle(
                                      color: _getStatusColor(sale['status']),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              },
                            ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RecordSpoilageScreen(market: widget.market),
                ),
              ).then((_) {
                _loadSalesHistory();
              });
            },
            heroTag: 'record_spoilage',
            icon: const Icon(Icons.delete_outline),
            label: const Text('Record Spoilage'),
            backgroundColor: Colors.orange,
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RecordSaleScreen(market: widget.market),
                ),
              ).then((_) {
                _loadSalesHistory();
                _loadVisitStatus();
              });
            },
            heroTag: 'record_sale',
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text('Record Sale'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusButton(String status, Color color) {
    return ElevatedButton(
      onPressed: () => _updateVisitStatus(status),
      style: ElevatedButton.styleFrom(
        backgroundColor: _visitStatus == status ? color : null,
        foregroundColor: _visitStatus == status ? Colors.white : null,
      ),
      child: Text(status),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Sale Made':
        return Colors.green;
      case 'Closed':
        return Colors.red;
      case 'Don\'t Need Any Product':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }
}