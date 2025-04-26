import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
// Import for debugPrint

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final vendor = authState.vendor;
    final isManagement = authState.isManagement;

    debugPrint('Building AppDrawer. Is Management: $isManagement');

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(vendor?.name ?? 'Jaouda Vendor'),
            accountEmail: Text(vendor?.email ?? ''),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                vendor?.name.isNotEmpty == true
                    ? vendor!.name.substring(0, 1).toUpperCase()
                    : 'J',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
            decoration: const BoxDecoration(color: AppTheme.primaryColor),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  context,
                  title: 'Dashboard',
                  icon: Icons.dashboard,
                  route: '/dashboard',
                ),
                _buildDrawerItem(
                  context,
                  title: 'Map View',
                  icon: Icons.map,
                  route: '/map',
                ),
                _buildDrawerItem(
                  context,
                  title: 'Markets',
                  icon: Icons.store,
                  route: '/markets',
                ),
                _buildDrawerItem(
                  context,
                  title: 'Add Market',
                  icon: Icons.add_business,
                  route: '/add-market',
                ),
                _buildDrawerItem(
                  context,
                  title: 'Sales',
                  icon: Icons.point_of_sale,
                  route: '/sales',
                ),
                _buildDrawerItem(
                  context,
                  title: 'Record Sale',
                  icon: Icons.add_shopping_cart,
                  route: '/sales/record',
                ),
                // Daily Stock for all users
                _buildDrawerItem(
                  context,
                  title: 'My Daily Stock',
                  icon: Icons.inventory,
                  route: '/daily-stock',
                ),
                if (isManagement) ...[
                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Text(
                      'Management',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  _buildDrawerItem(
                    context,
                    title: 'Review Markets',
                    icon: Icons.rate_review,
                    route: '/review-markets',
                  ),
                  _buildDrawerItem(
                    context,
                    title: 'Manage Products',
                    icon: Icons.inventory_2,
                    route: '/products',
                  ),
                  _buildDrawerItem(
                    context,
                    title: 'Stock Dashboard',
                    icon: Icons.dashboard_customize,
                    route: '/stock/dashboard',
                  ),
                  _buildDrawerItem(
                    context,
                    title: 'Manage Stock',
                    icon: Icons.warehouse,
                    route: '/stock',
                  ),
                  _buildDrawerItem(
                    context,
                    title: 'Assign Stock',
                    icon: Icons.assignment,
                    route: '/stock/assign',
                  ),
                  _buildDrawerItem(
                    context,
                    title: 'Manage Vendors',
                    icon: Icons.people,
                    route: '/vendors',
                  ),
                  _buildDrawerItem(
                    context,
                    title: 'Manage Promotions',
                    icon: Icons.discount,
                    route: '/promotions',
                  ),
                  _buildDrawerItem(
                    context,
                    title: 'Vendor Targets',
                    icon: Icons.track_changes,
                    route: '/targets',
                  ),
                ],
                const Divider(),
                _buildDrawerItem(
                  context,
                  title: 'Settings',
                  icon: Icons.settings,
                  route: '/settings',
                ),
                _buildDrawerItem(
                  context,
                  title: 'Navigation Test',
                  icon: Icons.bug_report,
                  route: '/test',
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Logout'),
                  onTap: () async {
                    debugPrint('Logout tapped');
                    Navigator.of(context).pop(); // Close drawer first
                    await ref.read(authProvider.notifier).signOut();
                    if (context.mounted) {
                      context.go('/login');
                    }
                  },
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Jaouda Boujdour v1.0.0',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String route,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () {
        debugPrint('Tapped on: $title, navigating to: $route');
        Navigator.of(context).pop(); // Close the drawer
        try {
          context.go(route);
          debugPrint('Navigation successful to: $route');
        } catch (e) {
          debugPrint('Error navigating to $route: $e');
          // Optionally show a snackbar or dialog
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error navigating to $title: $e')),
            );
          }
        }
      },
    );
  }
}
