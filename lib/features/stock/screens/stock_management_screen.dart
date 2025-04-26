import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../providers/stock_provider.dart';
import '../../../models/stock.dart';
import '../../../models/stock_update.dart';
import '../../../models/product.dart';
import '../../../widgets/app_layout.dart';
import '../../../config/theme.dart';

class StockManagementScreen extends ConsumerStatefulWidget {
  const StockManagementScreen({super.key});

  @override
  ConsumerState<StockManagementScreen> createState() =>
      _StockManagementScreenState();
}

class _StockManagementScreenState extends ConsumerState<StockManagementScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  final bool _showHistory = false;
  late TabController _tabController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Synchronize stock counts between products and stock tables
      await ref.read(stockProvider.notifier).synchronizeStockCounts();

      // Load the stock and history after synchronization
      ref.read(stockProvider.notifier).loadStock();
      ref.read(stockProvider.notifier).loadStockHistory();
    });

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stockState = ref.watch(stockProvider);

    return AppLayout(
      title: 'Stock Management',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTabBar(),

          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search products...',
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppTheme.primaryColor, width: 2),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              ),
            ),
          ),

          // Stats card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _buildStatsCard(stockState),
          ),

          const SizedBox(height: 16),

          // Main content based on the selected tab
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Stock tab
                stockState.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : stockState.error != null
                        ? _buildErrorWidget(stockState.error!)
                        : stockState.stock.isEmpty
                            ? _buildEmptyState()
                            : _buildStockList(stockState),

                // History tab
                stockState.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : stockState.error != null
                        ? _buildErrorWidget(stockState.error!)
                        : stockState.stockHistory.isEmpty
                            ? _buildEmptyHistoryState()
                            : _buildHistoryList(stockState),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: AppTheme.primaryColor,
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey.shade700,
        tabs: const [
          Tab(
            icon: Icon(Icons.inventory_2_outlined),
            text: 'Current Stock',
          ),
          Tab(
            icon: Icon(Icons.history),
            text: 'History',
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(StockState state) {
    final totalProducts = state.stock.length;
    final totalQuantity =
        state.stock.fold(0, (sum, stock) => sum + stock.quantity);
    final lowStockCount =
        state.stock.where((stock) => stock.quantity < 10).length;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryColor,
              AppTheme.primaryDarkColor,
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('Products', totalProducts, Icons.category),
            _buildStatItem('Total Stock', totalQuantity, Icons.inventory),
            _buildStatItem('Low Stock', lowStockCount, Icons.warning_amber,
                isWarning: lowStockCount > 0),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int value, IconData icon,
      {bool isWarning = false}) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: isWarning ? Colors.amber : Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildStockList(StockState state) {
    // Filter the stock list based on search query
    final filteredStock = _searchQuery.isEmpty
        ? state.stock
        : state.stock
            .where((stock) => stock.product.name
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()))
            .toList();

    if (filteredStock.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No products found matching "$_searchQuery"',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(stockProvider.notifier).loadStock();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: ListView.builder(
          itemCount: filteredStock.length,
          itemBuilder: (context, index) {
            final stock = filteredStock[index];
            return _buildStockCard(stock);
          },
        ),
      ),
    );
  }

  Widget _buildStockCard(Stock stock) {
    final isLowStock = stock.quantity < 10;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isLowStock
            ? const BorderSide(color: Colors.orange, width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isLowStock
                        ? Colors.orange.withOpacity(0.1)
                        : AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isLowStock ? Icons.warning_amber : Icons.inventory_2,
                    color: isLowStock ? Colors.orange : AppTheme.primaryColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stock.product.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        stock.product.description ?? 'No description available',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isLowStock
                              ? Colors.orange.withOpacity(0.1)
                              : Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isLowStock
                              ? 'Low Stock: ${stock.quantity} left'
                              : 'In Stock: ${stock.quantity}',
                          style: TextStyle(
                            color: isLowStock ? Colors.orange : Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.remove),
                  label: const Text('Remove'),
                  onPressed: () => _showRemoveStockDialog(stock),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                  onPressed: () => _showAddStockDialog(stock),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList(StockState state) {
    final filteredHistory = _searchQuery.isEmpty
        ? state.stockHistory
        : state.stockHistory
            .where((update) => update.product.name
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()))
            .toList();

    if (filteredHistory.isEmpty && _searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No history found matching "$_searchQuery"',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(stockProvider.notifier).loadStockHistory();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: ListView.builder(
          itemCount: filteredHistory.length,
          itemBuilder: (context, index) {
            final update = filteredHistory[index];
            return _buildHistoryCard(update);
          },
        ),
      ),
    );
  }

  Widget _buildHistoryCard(StockUpdate update) {
    final isAddition = update.quantityChange > 0;
    final dateFormat = DateTime.now().difference(update.createdAt).inDays < 1
        ? 'Today, ${update.createdAt.hour}:${update.createdAt.minute.toString().padLeft(2, '0')}'
        : '${update.createdAt.day}/${update.createdAt.month}/${update.createdAt.year}';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isAddition
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isAddition ? Icons.add_circle : Icons.remove_circle,
                color: isAddition ? Colors.green : Colors.red,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        update.product.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        dateFormat,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    update.notes ?? 'No notes available',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isAddition
                              ? Colors.green.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isAddition
                              ? '+${update.quantityChange}'
                              : '${update.quantityChange}',
                          style: TextStyle(
                            color: isAddition ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${update.previousQuantity} → ${update.newQuantity}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No stock items found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add products to manage your inventory',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            onPressed: () {
              ref.read(stockProvider.notifier).loadStock();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHistoryState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No stock history found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Stock changes will appear here',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            onPressed: () {
              ref.read(stockProvider.notifier).loadStockHistory();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading data',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            onPressed: () {
              ref.read(stockProvider.notifier).loadStock();
              ref.read(stockProvider.notifier).loadStockHistory();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddStockDialog(Stock stock) {
    final quantityController = TextEditingController();
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isAdding = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.add_circle,
                color: AppTheme.primaryColor,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text('Add Stock'),
            ],
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.inventory_2,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stock.product.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Current Quantity: ${stock.quantity}',
                              style: const TextStyle(
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  enabled: !isAdding,
                  decoration: const InputDecoration(
                    labelText: 'Add Quantity',
                    border: OutlineInputBorder(),
                    helperText: 'Number of units to add',
                    prefixIcon: Icon(Icons.add_shopping_cart),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a quantity';
                    }
                    final quantity = int.tryParse(value);
                    if (quantity == null) {
                      return 'Please enter a valid number';
                    }
                    if (quantity <= 0) {
                      return 'Quantity must be greater than 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: notesController,
                  enabled: !isAdding,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                    helperText: 'Source, invoice number, etc.',
                    prefixIcon: Icon(Icons.note),
                  ),
                ),
                if (isAdding)
                  const Padding(
                    padding: EdgeInsets.only(top: 16.0),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isAdding ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isAdding
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) {
                        return;
                      }

                      final quantity = int.tryParse(quantityController.text);
                      if (quantity == null) {
                        return;
                      }

                      setState(() {
                        isAdding = true;
                      });

                      try {
                        final result =
                            await ref.read(stockProvider.notifier).addStock(
                                  product: stock.product,
                                  quantity: quantity,
                                  notes: notesController.text.isNotEmpty
                                      ? notesController.text
                                      : 'Added $quantity units',
                                );

                        if (mounted) {
                          Navigator.pop(context);

                          if (result.startsWith('Error')) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(result),
                                backgroundColor: Colors.red,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text('Added $quantity units successfully'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        if (mounted) {
                          setState(() {
                            isAdding = false;
                          });

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to add stock: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: const Text('Add Stock'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRemoveStockDialog(Stock stock) {
    final quantityController = TextEditingController();
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isRemoving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.remove_circle,
                color: Colors.red,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text('Remove Stock'),
            ],
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.inventory_2,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stock.product.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Current Quantity: ${stock.quantity}',
                              style: const TextStyle(
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  enabled: !isRemoving,
                  decoration: const InputDecoration(
                    labelText: 'Remove Quantity',
                    border: OutlineInputBorder(),
                    helperText: 'Number of units to remove',
                    prefixIcon: Icon(Icons.remove_shopping_cart),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a quantity';
                    }
                    final quantity = int.tryParse(value);
                    if (quantity == null) {
                      return 'Please enter a valid number';
                    }
                    if (quantity <= 0) {
                      return 'Quantity must be greater than 0';
                    }
                    if (quantity > stock.quantity) {
                      return 'Cannot remove more than current stock (${stock.quantity})';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: notesController,
                  enabled: !isRemoving,
                  decoration: const InputDecoration(
                    labelText: 'Reason (optional)',
                    border: OutlineInputBorder(),
                    helperText: 'Damage, spoilage, sale, etc.',
                    prefixIcon: Icon(Icons.note),
                  ),
                ),
                if (isRemoving)
                  const Padding(
                    padding: EdgeInsets.only(top: 16.0),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isRemoving ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isRemoving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) {
                        return;
                      }

                      final quantity = int.tryParse(quantityController.text);
                      if (quantity == null) {
                        return;
                      }

                      setState(() {
                        isRemoving = true;
                      });

                      try {
                        final result =
                            await ref.read(stockProvider.notifier).removeStock(
                                  product: stock.product,
                                  quantity: quantity,
                                  notes: notesController.text.isNotEmpty
                                      ? notesController.text
                                      : 'Removed $quantity units',
                                );

                        if (mounted) {
                          Navigator.pop(context);

                          if (result.startsWith('Error')) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(result),
                                backgroundColor: Colors.red,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Removed $quantity units successfully'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        if (mounted) {
                          setState(() {
                            isRemoving = false;
                          });

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to remove stock: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Remove Stock'),
            ),
          ],
        ),
      ),
    );
  }
}
