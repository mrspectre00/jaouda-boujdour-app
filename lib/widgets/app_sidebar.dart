import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';

// State provider to manage sidebar collapsed state globally
final sidebarCollapsedProvider = StateProvider<bool>((ref) => false);

// Provider for favorite menu items
final favoriteMenuItemsProvider = StateProvider<List<String>>((ref) => []);

class NavGroup {
  final String title;
  final IconData icon;
  final List<NavItem> items;
  final bool requiresManagement;
  final String id;

  const NavGroup({
    required this.title,
    required this.icon,
    required this.items,
    required this.id,
    this.requiresManagement = false,
  });
}

class NavItem {
  final String title;
  final IconData icon;
  final String route;
  final bool requiresManagement;
  final String id;

  const NavItem({
    required this.title,
    required this.icon,
    required this.route,
    required this.id,
    this.requiresManagement = false,
  });
}

class AppSidebar extends ConsumerStatefulWidget {
  const AppSidebar({super.key});

  @override
  ConsumerState<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends ConsumerState<AppSidebar> {
  // Track expanded groups
  final Map<String, bool> _expandedGroups = {};

  // Define all navigation groups and items
  List<NavGroup> get navigationGroups => [
        NavGroup(
          id: 'dashboard',
          title: 'Dashboard',
          icon: Icons.dashboard,
          items: [
            NavItem(
              id: 'overview',
              title: 'Overview',
              icon: Icons.home,
              route: '/dashboard',
            ),
            NavItem(
              id: 'daily-summary',
              title: 'Daily Summary',
              icon: Icons.summarize,
              route: '/daily-summary',
            ),
          ],
        ),
        NavGroup(
          id: 'markets',
          title: 'Markets',
          icon: Icons.store,
          items: [
            NavItem(
              id: 'markets-list',
              title: 'Markets List',
              icon: Icons.list,
              route: '/markets',
            ),
            NavItem(
              id: 'add-market',
              title: 'Add Market',
              icon: Icons.add_business,
              route: '/add-market',
            ),
            NavItem(
              id: 'map-view',
              title: 'Map View',
              icon: Icons.map,
              route: '/map',
            ),
            NavItem(
              id: 'review-markets',
              title: 'Review Markets',
              icon: Icons.rate_review,
              route: '/review-markets',
              requiresManagement: true,
            ),
          ],
        ),
        NavGroup(
          id: 'sales',
          title: 'Sales',
          icon: Icons.point_of_sale,
          items: [
            NavItem(
              id: 'sales-list',
              title: 'Sales List',
              icon: Icons.receipt_long,
              route: '/sales',
            ),
            NavItem(
              id: 'record-sale',
              title: 'Record Sale',
              icon: Icons.add_shopping_cart,
              route: '/sales/record',
            ),
          ],
        ),
        NavGroup(
          id: 'stock',
          title: 'Stock',
          icon: Icons.inventory,
          items: [
            NavItem(
              id: 'daily-stock',
              title: 'My Daily Stock',
              icon: Icons.inventory_2,
              route: '/daily-stock',
            ),
            NavItem(
              id: 'stock-dashboard',
              title: 'Stock Dashboard',
              icon: Icons.dashboard_customize,
              route: '/stock/dashboard',
              requiresManagement: true,
            ),
            NavItem(
              id: 'manage-stock',
              title: 'Manage Stock',
              icon: Icons.warehouse,
              route: '/stock',
              requiresManagement: true,
            ),
            NavItem(
              id: 'assign-stock',
              title: 'Assign Stock',
              icon: Icons.assignment_turned_in,
              route: '/stock/assign',
              requiresManagement: true,
            ),
          ],
        ),
        NavGroup(
          id: 'admin',
          title: 'Administration',
          icon: Icons.admin_panel_settings,
          requiresManagement: true,
          items: [
            NavItem(
              id: 'manage-vendors',
              title: 'Manage Vendors',
              icon: Icons.people,
              route: '/vendors',
              requiresManagement: true,
            ),
            NavItem(
              id: 'manage-products',
              title: 'Manage Products',
              icon: Icons.category,
              route: '/products',
              requiresManagement: true,
            ),
            NavItem(
              id: 'manage-promotions',
              title: 'Manage Promotions',
              icon: Icons.discount,
              route: '/promotions',
              requiresManagement: true,
            ),
            NavItem(
              id: 'vendor-targets',
              title: 'Vendor Targets',
              icon: Icons.track_changes,
              route: '/targets',
              requiresManagement: true,
            ),
          ],
        ),
        NavGroup(
          id: 'settings',
          title: 'Settings',
          icon: Icons.settings,
          items: [
            NavItem(
              id: 'settings',
              title: 'Settings',
              icon: Icons.settings,
              route: '/settings',
            ),
          ],
        ),
      ];

  @override
  void initState() {
    super.initState();
    // Initialize first two groups as expanded by default
    _expandedGroups['dashboard'] = true;
    _expandedGroups['markets'] = true;
  }

  void _toggleFavorite(String itemId) {
    final favorites = [...ref.read(favoriteMenuItemsProvider)];

    if (favorites.contains(itemId)) {
      favorites.remove(itemId);
    } else {
      favorites.add(itemId);
    }

    ref.read(favoriteMenuItemsProvider.notifier).state = favorites;
  }

  bool _isFavorite(String itemId) {
    return ref.watch(favoriteMenuItemsProvider).contains(itemId);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final vendor = authState.vendor;
    final isManagement = authState.isManagement;
    final isSidebarCollapsed = ref.watch(sidebarCollapsedProvider);
    final currentPath = GoRouterState.of(context).uri.toString();

    // Get favorite menu items for showing at the top
    final favoriteItems = ref.watch(favoriteMenuItemsProvider);

    return Material(
      color: const Color(0xFF2C3A47),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: isSidebarCollapsed ? 80 : 250,
        child: Column(
          children: [
            // Profile header
            Container(
              height: isSidebarCollapsed ? 70 : 150,
              padding: EdgeInsets.symmetric(
                vertical: isSidebarCollapsed ? 8 : 16,
                horizontal: isSidebarCollapsed ? 8 : 16,
              ),
              decoration: const BoxDecoration(
                color: AppTheme.primaryDarkColor,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.primaryDarkColor,
                  ],
                ),
              ),
              child: isSidebarCollapsed
                  ? Center(
                      child: CircleAvatar(
                        backgroundColor:
                            isManagement ? Colors.amber : Colors.white,
                        radius: 22,
                        child: Text(
                          vendor?.name.isNotEmpty == true
                              ? vendor!.name.substring(0, 1).toUpperCase()
                              : 'J',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isManagement
                                ? AppTheme.primaryDarkColor
                                : AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor:
                                  isManagement ? Colors.amber : Colors.white,
                              radius: 28,
                              child: Text(
                                vendor?.name.isNotEmpty == true
                                    ? vendor!.name.substring(0, 1).toUpperCase()
                                    : 'J',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: isManagement
                                      ? AppTheme.primaryDarkColor
                                      : AppTheme.primaryColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    vendor?.name ?? 'Jaouda Vendor',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    vendor?.email ?? '',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white70,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isManagement
                                          ? Colors.amber.withOpacity(0.2)
                                          : Colors.lightBlue.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      isManagement ? 'Admin' : 'Vendor',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isManagement
                                            ? Colors.amber
                                            : Colors.lightBlue,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            icon: const Icon(
                              Icons.menu_open,
                              color: Colors.white70,
                              size: 20,
                            ),
                            onPressed: () {
                              ref
                                  .read(sidebarCollapsedProvider.notifier)
                                  .state = true;
                            },
                            tooltip: 'Collapse Menu',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                      ],
                    ),
            ),

            // Collapsible toggle (only in collapsed mode)
            if (isSidebarCollapsed)
              IconButton(
                icon: const Icon(
                  Icons.menu,
                  color: Colors.white70,
                ),
                onPressed: () {
                  ref.read(sidebarCollapsedProvider.notifier).state = false;
                },
                tooltip: 'Expand Menu',
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),

            // Favorites section (if any favorites exist)
            if (favoriteItems.isNotEmpty && !isSidebarCollapsed) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 16,
                ),
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    const Icon(
                      Icons.star,
                      color: Colors.amber,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Favorites',
                      style: TextStyle(
                        color: Colors.amber[100],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              ...favoriteItems.map((itemId) {
                NavItem? item;
                // Find the item in all groups
                for (final group in navigationGroups) {
                  for (final navItem in group.items) {
                    if (navItem.id == itemId) {
                      item = navItem;
                      break;
                    }
                  }
                  if (item != null) break;
                }
                if (item != null) {
                  return _buildNavItemSimple(
                    item,
                    isActive: currentPath == item.route,
                    isFavorite: true,
                  );
                }
                return const SizedBox.shrink();
              }).toList(),
              const Divider(color: Colors.white12, height: 1),
            ],

            // Navigation items
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Build each navigation group
                  ...navigationGroups
                      .where(
                          (group) => !group.requiresManagement || isManagement)
                      .map((group) => _buildNavGroup(
                            group,
                            currentPath: currentPath,
                          ))
                      .toList(),
                ],
              ),
            ),

            // Logout and version
            Container(
              color: AppTheme.primaryDarkColor,
              padding: EdgeInsets.symmetric(
                vertical: 8,
                horizontal: isSidebarCollapsed ? 8 : 16,
              ),
              child: Column(
                children: [
                  if (isSidebarCollapsed)
                    IconButton(
                      icon: const Icon(
                        Icons.logout,
                        color: Colors.white70,
                      ),
                      onPressed: () async {
                        if (Navigator.canPop(context)) {
                          Navigator.of(context).pop();
                        }
                        await ref.read(authProvider.notifier).signOut();
                        if (context.mounted) {
                          context.go('/login');
                        }
                      },
                    )
                  else
                    ListTile(
                      dense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      leading: const Icon(
                        Icons.logout,
                        color: Colors.white70,
                      ),
                      title: const Text(
                        'Logout',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () async {
                        // Close drawer if on mobile
                        if (Navigator.canPop(context)) {
                          Navigator.of(context).pop();
                        }
                        await ref.read(authProvider.notifier).signOut();
                        if (context.mounted) {
                          context.go('/login');
                        }
                      },
                    ),
                  if (!isSidebarCollapsed)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Jaouda Boujdour v1.0.0',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavGroup(NavGroup group, {required String currentPath}) {
    final isExpanded = _expandedGroups[group.id] ?? false;
    final authState = ref.read(authProvider);
    final isManagement = authState.isManagement;
    final isSidebarCollapsed = ref.watch(sidebarCollapsedProvider);

    // Filter items based on management status
    final visibleItems = group.items
        .where((item) => !item.requiresManagement || isManagement)
        .toList();

    // Don't show empty groups
    if (visibleItems.isEmpty) {
      return const SizedBox.shrink();
    }

    // Check if any item in the group is active
    final isGroupActive = visibleItems.any((item) => currentPath == item.route);

    return Column(
      children: [
        // Group header (expandable)
        if (isSidebarCollapsed)
          InkWell(
            onTap: () {
              // Navigate to the first item in the group when in collapsed mode
              if (visibleItems.isNotEmpty) {
                final firstItem = visibleItems.first;
                if (Navigator.canPop(context)) {
                  Navigator.of(context).pop();
                }
                try {
                  context.go(firstItem.route);
                } catch (e) {
                  debugPrint('Error navigating to ${firstItem.route}: $e');
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: isGroupActive ? Colors.white.withOpacity(0.1) : null,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Icon(
                  group.icon,
                  color: isGroupActive ? Colors.white : Colors.white70,
                  size: 24,
                ),
              ),
            ),
          )
        else
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            leading: Icon(
              group.icon,
              color: isGroupActive ? Colors.white : Colors.white70,
              size: 20,
            ),
            title: Text(
              group.title,
              style: TextStyle(
                color: isGroupActive ? Colors.white : Colors.white70,
                fontWeight: isGroupActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            trailing: Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              color: Colors.white70,
              size: 20,
            ),
            onTap: () {
              setState(() {
                _expandedGroups[group.id] = !isExpanded;
              });
            },
          ),

        // Group items (with animation)
        if (!isSidebarCollapsed)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: isExpanded ? visibleItems.length * 40.0 : 0,
            child: AnimatedOpacity(
              opacity: isExpanded ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: ListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: visibleItems
                    .map((item) => _buildNavItem(
                          item,
                          isActive: currentPath == item.route,
                        ))
                    .toList(),
              ),
            ),
          ),

        if (isSidebarCollapsed && isGroupActive)
          ...visibleItems
              .map((item) => _buildNavItemCollapsed(
                    item,
                    isActive: currentPath == item.route,
                  ))
              .toList(),

        const Divider(color: Colors.white12, height: 1),
      ],
    );
  }

  Widget _buildNavItem(NavItem item, {required bool isActive}) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 56.0, right: 8.0),
      leading: Icon(
        item.icon,
        color: isActive ? Colors.white : Colors.white60,
        size: 18,
      ),
      title: Text(
        item.title,
        style: TextStyle(
          color: isActive ? Colors.white : Colors.white70,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: IconButton(
        icon: Icon(
          _isFavorite(item.id) ? Icons.star : Icons.star_border,
          color: _isFavorite(item.id) ? Colors.amber : Colors.white38,
          size: 18,
        ),
        onPressed: () => _toggleFavorite(item.id),
        tooltip:
            _isFavorite(item.id) ? 'Remove from favorites' : 'Add to favorites',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
      selected: isActive,
      selectedTileColor: Colors.white.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      onTap: () {
        // Close drawer if on mobile
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
        // Navigate
        try {
          context.go(item.route);
        } catch (e) {
          debugPrint('Error navigating to ${item.route}: $e');
          // Show error if navigation fails
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error navigating to ${item.title}: $e')),
            );
          }
        }
      },
    );
  }

  Widget _buildNavItemCollapsed(NavItem item, {required bool isActive}) {
    return InkWell(
      onTap: () {
        // Close drawer if on mobile
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
        // Navigate
        try {
          context.go(item.route);
        } catch (e) {
          debugPrint('Error navigating to ${item.route}: $e');
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withOpacity(0.1) : null,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          item.icon,
          color: isActive ? Colors.white : Colors.white60,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildNavItemSimple(NavItem item,
      {required bool isActive, required bool isFavorite}) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      leading: Icon(
        item.icon,
        color: isActive ? Colors.white : Colors.white60,
        size: 18,
      ),
      title: Text(
        item.title,
        style: TextStyle(
          color: isActive ? Colors.white : Colors.white70,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: IconButton(
        icon: const Icon(
          Icons.star,
          color: Colors.amber,
          size: 18,
        ),
        onPressed: () => _toggleFavorite(item.id),
        tooltip: 'Remove from favorites',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
      selected: isActive,
      selectedTileColor: Colors.white.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      onTap: () {
        // Close drawer if on mobile
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
        // Navigate
        try {
          context.go(item.route);
        } catch (e) {
          debugPrint('Error navigating to ${item.route}: $e');
        }
      },
    );
  }
}
