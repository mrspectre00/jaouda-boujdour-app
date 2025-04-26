import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../../../widgets/app_layout.dart';
import '../../../config/theme.dart';
import 'package:go_router/go_router.dart';
import '../../../features/analytics/screens/inventory_analytics_screen.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Dashboard data is loaded in the provider constructor
  }

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(dashboardProvider);
    final authState = ref.watch(authProvider);
    final vendor = authState.vendor;
    final user = authState.user;
    final isManagement = authState.isManagement;

    return AppLayout(
      title: 'Dashboard',
      body: dashboardState.isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
              ),
            )
          : dashboardState.error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Error loading dashboard data: ${dashboardState.error}',
                        style: TextStyle(color: Colors.red[700]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          ref
                              .read(dashboardProvider.notifier)
                              .loadDashboardData();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await ref
                        .read(dashboardProvider.notifier)
                        .loadDashboardData();
                  },
                  color: AppTheme.primaryColor,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Welcome section with user info
                        _buildWelcomeCard(context, vendor, user, isManagement),
                        const SizedBox(height: 24),

                        // Stats overview section
                        Row(
                          children: [
                            const Icon(
                              Icons.insights,
                              color: AppTheme.primaryColor,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Business Overview',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildSummaryCards(context, dashboardState),

                        const SizedBox(height: 24),

                        // Quick actions section
                        Row(
                          children: [
                            const Icon(
                              Icons.bolt,
                              color: AppTheme.primaryColor,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Quick Actions',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildQuickActions(context),

                        const SizedBox(height: 24),

                        // Recent sales section
                        Row(
                          children: [
                            const Icon(
                              Icons.receipt_long,
                              color: AppTheme.primaryColor,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Recent Sales',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () {
                                context.go('/sales');
                              },
                              icon: const Icon(
                                Icons.arrow_forward,
                                size: 16,
                              ),
                              label: const Text('View All'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildRecentSales(context, dashboardState),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildWelcomeCard(
    BuildContext context,
    dynamic vendor,
    dynamic user,
    bool isManagement,
  ) {
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good Morning'
        : now.hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              isManagement ? Colors.purple.shade600 : AppTheme.primaryColor,
              isManagement
                  ? Colors.deepPurple.shade900
                  : AppTheme.primaryDarkColor,
            ],
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white.withOpacity(0.2),
              radius: 32,
              child: Icon(
                isManagement ? Icons.admin_panel_settings : Icons.person,
                color: Colors.white,
                size: 36,
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isManagement
                        ? 'Administrator'
                        : (vendor?.name ??
                            user?.email?.split('@').first ??
                            'User'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isManagement
                          ? 'Management Account'
                          : 'Sales Representative',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Text(
                  DateFormat('EEE, MMM d').format(DateTime.now()),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat('yyyy').format(DateTime.now()),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context, DashboardState state) {
    return GridView.count(
      crossAxisCount: MediaQuery.of(context).size.width < 600 ? 1 : 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildSummaryCard(
          context,
          'Today\'s Sales',
          '${state.todaySalesCount}',
          Icons.shopping_cart,
          AppTheme.primaryColor,
          'Transactions',
        ),
        _buildSummaryCard(
          context,
          'Revenue',
          '${state.todayTotalSales}',
          Icons.attach_money,
          Colors.green.shade700,
          'MAD',
        ),
        _buildSummaryCard(
          context,
          'Active Markets',
          '${state.activeMarketsCount}',
          Icons.store,
          Colors.blue.shade700,
          'Markets',
        ),
        _buildSummaryCard(
          context,
          'Products in Stock',
          '${state.productsInStockCount}',
          Icons.inventory_2,
          Colors.teal.shade700,
          'Items',
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return GridView.count(
      crossAxisCount: MediaQuery.of(context).size.width < 600 ? 2 : 4,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildActionCard(
          context,
          'Record Sale',
          Icons.add_shopping_cart,
          Colors.green.shade700,
          () {
            context.go('/sales/record');
          },
        ),
        _buildActionCard(
          context,
          'View Markets',
          Icons.store,
          Colors.blue.shade700,
          () {
            context.go('/markets');
          },
        ),
        _buildActionCard(
          context,
          'Sales History',
          Icons.history,
          Colors.purple.shade700,
          () {
            context.go('/sales');
          },
        ),
        _buildActionCard(
          context,
          'Inventory',
          Icons.analytics,
          Colors.orange.shade700,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const InventoryAnalyticsScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade800,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentSales(BuildContext context, DashboardState state) {
    if (state.recentSales == null || state.recentSales!.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.receipt_long,
                  size: 48,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No recent sales',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    context.go('/sales/record');
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Record a Sale'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: state.recentSales!.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final sale = state.recentSales![index];
            return ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: AppTheme.primaryColor,
                ),
              ),
              title: Text(
                sale.productName ?? "Product",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${sale.quantity} items · ${_formatDate(sale.createdAt)}',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${sale.total} MAD',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Sale #${sale.id.toString().substring(0, 8)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              onTap: () {
                context.go('/sales/detail/${sale.id}');
              },
            );
          },
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }
}
