import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme.dart';
import '../../../models/market.dart';
import '../providers/markets_provider.dart';
import '../../../widgets/app_layout.dart';

class MarketDetailScreen extends ConsumerStatefulWidget {
  final String marketId;

  const MarketDetailScreen({super.key, required this.marketId});

  @override
  ConsumerState<MarketDetailScreen> createState() => _MarketDetailScreenState();
}

class _MarketDetailScreenState extends ConsumerState<MarketDetailScreen> {
  Market? _market;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMarketDetails();
  }

  Future<void> _loadMarketDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final market = await ref
          .read(marketsProvider.notifier)
          .getMarketById(widget.marketId);

      setState(() {
        _market = market;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Failed to load market details: ${e.toString()}";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      title: _market?.name ?? 'Market Details',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadMarketDetails,
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadMarketDetails,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _market == null
                  ? const Center(
                      child: Text('Market not found',
                          style: TextStyle(fontSize: 18)),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header with status
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _market!.name,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(_market!.status),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  _getStatusText(_market!.status),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Market details card
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Market Information',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Divider(),
                                  _buildInfoRow(
                                    'Address',
                                    _market!.address ?? 'No address provided',
                                    Icons.location_on,
                                  ),
                                  _buildInfoRow(
                                    'Coordinates',
                                    '${_market!.location.latitude.toStringAsFixed(6)}, ${_market!.location.longitude.toStringAsFixed(6)}',
                                    Icons.my_location,
                                  ),
                                  _buildInfoRow(
                                    'Region',
                                    _market!.region?.name ?? 'Unknown Region',
                                    Icons.public,
                                  ),
                                  if (_market!.notes != null &&
                                      _market!.notes!.isNotEmpty)
                                    _buildInfoRow(
                                      'Notes',
                                      _market!.notes!,
                                      Icons.note,
                                    ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Action buttons
                          const Text(
                            'Actions',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),

                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    context.push('/map',
                                        extra: {'market': _market});
                                  },
                                  icon: const Icon(Icons.map),
                                  label: const Text('View on Map'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed:
                                      _market!.status == MarketStatus.toVisit
                                          ? () {
                                              context.push(
                                                '/sales/record/${_market!.id}',
                                              );
                                            }
                                          : null,
                                  icon: const Icon(Icons.shopping_cart),
                                  label: const Text('Record Sale'),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Status management
                          if (_market!.status != MarketStatus.toVisit) ...[
                            const Text(
                              'Market Status',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed:
                                        _market!.status == MarketStatus.toVisit
                                            ? null
                                            : () => _updateMarketStatus(
                                                  MarketStatus.toVisit,
                                                ),
                                    icon: const Icon(Icons.check_circle),
                                    label: const Text('Mark as To Visit'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor:
                                          AppTheme.activeMarketColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed:
                                        _market!.status == MarketStatus.saleMade
                                            ? null
                                            : () => _updateMarketStatus(
                                                  MarketStatus.saleMade,
                                                ),
                                    icon: const Icon(Icons.check_circle),
                                    label: const Text('Mark as Sale Made'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor:
                                          AppTheme.activeMarketColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed:
                                        _market!.status == MarketStatus.closed
                                            ? null
                                            : () => _updateMarketStatus(
                                                  MarketStatus.closed,
                                                ),
                                    icon: const Icon(Icons.cancel),
                                    label: const Text('Mark as Closed'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor:
                                          AppTheme.inactiveMarketColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed:
                                        _market!.status == MarketStatus.noNeed
                                            ? null
                                            : () => _updateMarketStatus(
                                                  MarketStatus.noNeed,
                                                ),
                                    icon: const Icon(Icons.cancel),
                                    label: const Text('Mark as No Need'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor:
                                          AppTheme.inactiveMarketColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                Text(value, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateMarketStatus(MarketStatus status) async {
    if (_market == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await ref
          .read(marketsProvider.notifier)
          .updateMarketStatus(_market!.id, status);
      // Reload market details
      _loadMarketDetails();
    } catch (e) {
      setState(() {
        _error = "Failed to update market status: ${e.toString()}";
        _isLoading = false;
      });
    }
  }

  Color _getStatusColor(MarketStatus status) {
    switch (status) {
      case MarketStatus.toVisit:
        return Colors.yellow;
      case MarketStatus.saleMade:
        return Colors.green;
      case MarketStatus.closed:
        return Colors.red;
      case MarketStatus.noNeed:
        return Colors.grey;
      case MarketStatus.visited:
        return Colors.green;
    }
  }

  String _getStatusText(MarketStatus status) {
    switch (status) {
      case MarketStatus.toVisit:
        return 'To Visit';
      case MarketStatus.saleMade:
        return 'Sale Made';
      case MarketStatus.closed:
        return 'Closed';
      case MarketStatus.noNeed:
        return 'No Need';
      case MarketStatus.visited:
        return 'Visited';
    }
  }
}
