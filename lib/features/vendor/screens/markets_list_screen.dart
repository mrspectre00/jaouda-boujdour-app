import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jaouda_boujdour_app/providers/markets_provider.dart';

class MarketsListScreen extends ConsumerStatefulWidget {
  const MarketsListScreen({super.key});

  @override
  ConsumerState<MarketsListScreen> createState() => _MarketsListScreenState();
}

class _MarketsListScreenState extends ConsumerState<MarketsListScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load initial markets data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(marketsProvider.notifier).loadMarkets();
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
    final filteredMarkets = marketsState.filteredMarkets;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Markets List'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(marketsProvider.notifier).loadMarkets();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search markets...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        ref.read(marketsProvider.notifier).setSearchQuery('');
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (value) {
                    ref.read(marketsProvider.notifier).setSearchQuery(value);
                  },
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(
                        context,
                        'All',
                        null,
                        marketsState.filterStatus == null,
                      ),
                      _buildFilterChip(
                        context,
                        'To Visit',
                        MarketStatus.toVisit,
                        marketsState.filterStatus == MarketStatus.toVisit,
                      ),
                      _buildFilterChip(
                        context,
                        'Visited',
                        MarketStatus.visited,
                        marketsState.filterStatus == MarketStatus.visited,
                      ),
                      _buildFilterChip(
                        context,
                        'Closed',
                        MarketStatus.closed,
                        marketsState.filterStatus == MarketStatus.closed,
                      ),
                      _buildFilterChip(
                        context,
                        'No Need',
                        MarketStatus.noNeed,
                        marketsState.filterStatus == MarketStatus.noNeed,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Markets List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await ref.read(marketsProvider.notifier).loadMarkets();
              },
              child:
                  marketsState.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : marketsState.error != null
                      ? Center(
                        child: Text(
                          marketsState.error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      )
                      : filteredMarkets.isEmpty
                      ? const Center(child: Text('No markets found'))
                      : ListView.builder(
                        itemCount: filteredMarkets.length,
                        itemBuilder: (context, index) {
                          final market = filteredMarkets[index];
                          return _MarketCard(market: market);
                        },
                      ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    String label,
    MarketStatus? status,
    bool isSelected,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          ref
              .read(marketsProvider.notifier)
              .setFilterStatus(selected ? status : null);
        },
      ),
    );
  }
}

class _MarketCard extends ConsumerWidget {
  final Market market;

  const _MarketCard({required this.market});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () {
          // TODO: Navigate to market details
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      market.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  _buildStatusChip(context, market.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                market.address,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (market.lastVisit != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Last Visit: ${_formatDateTime(market.lastVisit!)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (market.salesAmount != null &&
                  market.productsSold != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Sales: ${market.salesAmount!.toStringAsFixed(2)} MAD',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Products: ${market.productsSold}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(context, 'View Map', Icons.map, () {
                    context.go('/vendor/map', extra: {'marketId': market.id});
                  }),
                  _buildActionButton(
                    context,
                    'Mark Visited',
                    Icons.check_circle,
                    () {
                      ref
                          .read(marketsProvider.notifier)
                          .updateMarketStatus(market.id, MarketStatus.visited);
                    },
                  ),
                  _buildActionButton(context, 'Mark Closed', Icons.close, () {
                    ref
                        .read(marketsProvider.notifier)
                        .updateMarketStatus(market.id, MarketStatus.closed);
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, MarketStatus status) {
    final (color, label) = switch (status) {
      MarketStatus.toVisit => (Colors.amber, 'To Visit'),
      MarketStatus.visited => (Colors.green, 'Visited'),
      MarketStatus.closed => (Colors.red, 'Closed'),
      MarketStatus.noNeed => (Colors.grey, 'No Need'),
    };

    return Chip(
      label: Text(label, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
