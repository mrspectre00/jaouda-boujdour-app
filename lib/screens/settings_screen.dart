import 'package:flutter/material.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Map<String, dynamic> _vendorData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVendorData();
  }

  // Load mock vendor data
  Future<void> _loadVendorData() async {
    // In a real app, this would fetch data from a backend
    await Future.delayed(
      const Duration(milliseconds: 600),
    ); // Simulate network delay

    final mockVendorData = {
      'id': 'v001',
      'name': 'Mohammed Karimi',
      'email': 'mohammed.k@jaouda.com',
      'phone': '+212 612345678',
      'profile_image': null, // In a real app, this would be a URL
      'assigned_regions': [
        {'id': 'r1', 'name': 'Boujdour North'},
      ],
      'role': 'vendor',
      'vehicle_number': 'AB-12345',
      'joined_date': '2023-05-15',
    };

    setState(() {
      _vendorData = mockVendorData;
      _isLoading = false;
    });
  }

  // Handle logout
  void _handleLogout() {
    // In a real app, this would clear auth tokens, etc.
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirm Logout'),
            content: const Text('Are you sure you want to log out?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
                child: const Text('LOGOUT'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 16),

                    // Profile image
                    CircleAvatar(
                      radius: 60,
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child:
                          _vendorData['profile_image'] != null
                              ? ClipRRect(
                                borderRadius: BorderRadius.circular(60),
                                child: Image.network(
                                  _vendorData['profile_image'],
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.cover,
                                ),
                              )
                              : Text(
                                _getInitials(_vendorData['name']),
                                style: TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                    ),
                    const SizedBox(height: 24),

                    // Vendor name
                    Text(
                      _vendorData['name'],
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),

                    // Vendor role
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _vendorData['role'].toUpperCase(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Information cards
                    Card(
                      margin: EdgeInsets.zero,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _buildInfoTile(
                            'Email',
                            _vendorData['email'],
                            Icons.email_outlined,
                          ),
                          const Divider(height: 1),
                          _buildInfoTile(
                            'Phone',
                            _vendorData['phone'],
                            Icons.phone_outlined,
                          ),
                          const Divider(height: 1),
                          _buildInfoTile(
                            'Vehicle Number',
                            _vendorData['vehicle_number'],
                            Icons.local_shipping_outlined,
                          ),
                          const Divider(height: 1),
                          _buildInfoTile(
                            'Joined Date',
                            _vendorData['joined_date'],
                            Icons.calendar_today_outlined,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Assigned regions
                    const Text(
                      'Assigned Regions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      margin: EdgeInsets.zero,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _vendorData['assigned_regions'].length,
                        separatorBuilder:
                            (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final region = _vendorData['assigned_regions'][index];
                          return ListTile(
                            leading: const Icon(Icons.map_outlined),
                            title: Text(region['name']),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Logout button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _handleLogout,
                        icon: const Icon(Icons.logout),
                        label: const Text(
                          'LOGOUT',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Theme.of(context).colorScheme.error,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  // Build info tile widget
  Widget _buildInfoTile(String label, String value, IconData icon) {
    return ListTile(
      leading: Icon(icon),
      title: Text(
        label,
        style: const TextStyle(fontSize: 14, color: Colors.grey),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
    );
  }

  // Get initials from name
  String _getInitials(String name) {
    if (name.isEmpty) return '';

    final nameParts = name.split(' ');
    if (nameParts.length >= 2) {
      return '${nameParts[0][0]}${nameParts[1][0]}';
    } else {
      return name[0];
    }
  }
}
