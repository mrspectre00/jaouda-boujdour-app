import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class NavigationTestScreen extends StatelessWidget {
  const NavigationTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Navigation Test')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Special Tests',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildNavigationButton(
                      context,
                      title: 'Database Test',
                      route: '/db-test',
                      description:
                          'Test database connection and check table structure',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Authentication Tests',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildNavigationButton(
              context,
              title: 'Login',
              route: '/login',
              description:
                  'If authenticated: redirect to dashboard, else: show login',
            ),
            _buildNavigationButton(
              context,
              title: 'Dashboard',
              route: '/dashboard',
              description:
                  'If authenticated: show dashboard, else: redirect to login',
            ),
            const SizedBox(height: 20),
            const Text(
              'Main Features',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildNavigationButton(
              context,
              title: 'Map View',
              route: '/map',
              description: 'Map showing all markets',
            ),
            _buildNavigationButton(
              context,
              title: 'Markets List',
              route: '/markets',
              description: 'List of all markets',
            ),
            _buildNavigationButton(
              context,
              title: 'Add Market',
              route: '/add-market',
              description: 'Form to add a new market',
            ),
            _buildNavigationButton(
              context,
              title: 'Record Sale (with test market ID)',
              route: '/sales/record/00000000-0000-0000-0000-000000000001',
              description: 'Form to record a sale for a specific market',
            ),
            _buildNavigationButton(
              context,
              title: 'Sales History',
              route: '/sales',
              description: 'List of all sales',
            ),
            _buildNavigationButton(
              context,
              title: 'Add Sale (with test market ID)',
              route: '/add-sale/00000000-0000-0000-0000-000000000001',
              description: 'Form to add a new sale',
            ),
            _buildNavigationButton(
              context,
              title: 'Settings',
              route: '/settings',
              description: 'User profile and app settings',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationButton(
    BuildContext context, {
    required String title,
    required String route,
    required String description,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(title),
        subtitle: Text(description),
        trailing: const Icon(Icons.arrow_forward),
        onTap: () {
          context.go(route);
        },
      ),
    );
  }
}
