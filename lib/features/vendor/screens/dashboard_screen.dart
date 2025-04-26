import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jaouda_boujdour_app/providers/auth_provider.dart';
import 'package:jaouda_boujdour_app/providers/stock_provider.dart';

class VendorDashboardScreen extends ConsumerStatefulWidget {
  const VendorDashboardScreen({super.key});

  @override
  ConsumerState<VendorDashboardScreen> createState() =>
      _VendorDashboardScreenState();
}

class _VendorDashboardScreenState extends ConsumerState<VendorDashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Load initial stock data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(stockProvider.notifier).loadDailyStock();
    });
  }

  @override
  Widget build(BuildContext context) {
    final stockState = ref.watch(stockProvider);
    final user = ref.watch(authProvider).user;

    return Scaffold(
      appBar: AppBar(
        title: Text('Good Morning, ${user?.name ?? 'Vendor'}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(stockProvider.notifier).loadDailyStock();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(stockProvider.notifier).loadDailyStock();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Daily Stock Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Today's Stock",
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      if (stockState.isLoading)
                        const Center(child: CircularProgressIndicator())
                      else if (stockState.error != null)
                        Center(
                          child: Text(
                            stockState.error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        )
                      else if (stockState.dailyStock.isEmpty)
                        const Center(child: Text('No stock assigned for today'))
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: stockState.dailyStock.length,
                          itemBuilder: (context, index) {
                            final item = stockState.dailyStock[index];
                            return ListTile(
                              leading: Icon(
                                _getProductIcon(item.productType),
                                color: Theme.of(context).primaryColor,
                              ),
                              title: Text(item.productName),
                              subtitle: Text('Quantity: ${item.quantity}'),
                              trailing: Text(
                                '${item.unit}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Quick Actions
              Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  _buildQuickAction(
                    context,
                    'View Map',
                    Icons.map,
                    () => context.go('/vendor/map'),
                  ),
                  _buildQuickAction(
                    context,
                    'Markets List',
                    Icons.list,
                    () => context.go('/vendor/markets'),
                  ),
                  _buildQuickAction(
                    context,
                    'Daily Summary',
                    Icons.summarize,
                    () => context.go('/vendor/summary'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getProductIcon(String productType) {
    switch (productType.toLowerCase()) {
      case 'vegetable':
        return Icons.grass;
      case 'fruit':
        return Icons.apple;
      case 'dairy':
        return Icons.local_drink;
      case 'meat':
        return Icons.set_meal;
      default:
        return Icons.shopping_basket;
    }
  }

  Widget _buildQuickAction(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: Theme.of(context).primaryColor),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
