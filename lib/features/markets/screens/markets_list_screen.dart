import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/market.dart';
import '../../../providers/markets_provider.dart' show marketsProvider;
import 'package:go_router/go_router.dart';

import '../../../widgets/app_layout.dart';

class MarketsListScreen extends ConsumerStatefulWidget {
  final bool selectionMode;
  final String routePrefix;

  const MarketsListScreen({
    super.key,
    this.selectionMode = false,
    this.routePrefix = '/markets',
  });

  @override
  ConsumerState<MarketsListScreen> createState() => _MarketsListScreenState();
}

class _MarketsListScreenState extends ConsumerState<MarketsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  MarketStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final marketsState = ref.watch(marketsProvider);
    final filteredMarkets = _filterMarkets(marketsState.markets);

    return AppLayout(
      title: 'Markets',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () {
            ref.read(marketsProvider.notifier).loadMarkets();
          },
        ),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push('${widget.routePrefix}/add');
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Search and filter bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search markets...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<MarketStatus?>(
                  icon: const Icon(Icons.filter_list),
                  tooltip: 'Filter by status',
                  onSelected: _onStatusFilterChanged,
                  itemBuilder: (context) => [
                    const PopupMenuItem<MarketStatus?>(
                      value: null,
                      child: Text('All'),
                    ),
                    const PopupMenuItem<MarketStatus>(
                      value: MarketStatus.toVisit,
                      child: Text('To Visit'),
                    ),
                    const PopupMenuItem<MarketStatus>(
                      value: MarketStatus.visited,
                      child: Text('Visited'),
                    ),
                    const PopupMenuItem<MarketStatus>(
                      value: MarketStatus.closed,
                      child: Text('Closed'),
                    ),
                    const PopupMenuItem<MarketStatus>(
                      value: MarketStatus.noNeed,
                      child: Text('No Need'),
                    ),
                    const PopupMenuItem<MarketStatus>(
                      value: MarketStatus.saleMade,
                      child: Text('Sale Made'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Markets list
          Expanded(
            child: marketsState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : marketsState.error != null
                    ? Center(child: Text(marketsState.error!))
                    : filteredMarkets.isEmpty
                        ? const Center(child: Text('No markets found'))
                        : RefreshIndicator(
                            onRefresh: () async {
                              await ref
                                  .read(marketsProvider.notifier)
                                  .loadMarkets();
                            },
                            child: ListView.builder(
                              itemCount: filteredMarkets.length,
                              itemBuilder: (context, index) {
                                final market = filteredMarkets[index];
                                return _buildMarketListItem(market);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  void _onStatusFilterChanged(MarketStatus? status) {
    setState(() {
      _statusFilter = status;
    });
  }

  List<Market> _filterMarkets(List<Market> markets) {
    if (_searchQuery.isEmpty && _statusFilter == null) {
      return markets;
    }

    return markets.where((market) {
      bool matchesSearch = _searchQuery.isEmpty ||
          market.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (market.address?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
              false);

      bool matchesStatus =
          _statusFilter == null || market.status == _statusFilter;

      return matchesSearch && matchesStatus;
    }).toList();
  }

  Widget _buildMarketListItem(Market market) {
    final status = market.status;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(market.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (market.address != null) Text(market.address!),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withAlpha(25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _getStatusText(status),
                    style: TextStyle(
                      color: _getStatusColor(status),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _onEditMarket(market),
            ),
            if (!widget.selectionMode)
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _onDeleteMarket(market),
              ),
          ],
        ),
        onTap: () => _onMarketSelected(market),
      ),
    );
  }

  String _getStatusText(MarketStatus status) {
    switch (status) {
      case MarketStatus.toVisit:
        return 'À visiter';
      case MarketStatus.visited:
        return 'Visité';
      case MarketStatus.closed:
        return 'Fermé';
      case MarketStatus.noNeed:
        return 'Non nécessaire';
      case MarketStatus.saleMade:
        return 'Vente effectuée';
    }
  }

  Color _getStatusColor(MarketStatus status) {
    switch (status) {
      case MarketStatus.toVisit:
        return Colors.orange;
      case MarketStatus.visited:
        return Colors.blue;
      case MarketStatus.closed:
        return Colors.red;
      case MarketStatus.noNeed:
        return Colors.grey;
      case MarketStatus.saleMade:
        return Colors.green;
    }
  }

  void _onEditMarket(Market market) {
    context.push('${widget.routePrefix}/${market.id}/edit');
  }

  void _onDeleteMarket(Market market) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete ${market.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(marketsProvider.notifier).deleteMarket(market.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _onMarketSelected(Market market) {
    if (widget.selectionMode) {
      context.push('${widget.routePrefix}/${market.id}');
    } else {
      context.push('${widget.routePrefix}/${market.id}');
    }
  }
}
