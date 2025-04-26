import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../providers/auth_provider.dart';
import '../../../models/vendor.dart';
import '../../../models/region.dart';
import '../../../services/supabase_client.dart';
import '../../../widgets/app_drawer.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../../../widgets/app_layout.dart';

class VendorsListScreen extends ConsumerStatefulWidget {
  const VendorsListScreen({super.key});

  @override
  ConsumerState<VendorsListScreen> createState() => _VendorsListScreenState();
}

class _VendorsListScreenState extends ConsumerState<VendorsListScreen> {
  List<Vendor> _vendors = [];
  List<Region> _regions = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    await Future.wait([_loadVendors(), _loadRegions()]);
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadVendors() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Query vendors table with region join
      debugPrint('Querying vendors table...');
      final response = await supabase
          .from('vendors')
          .select('*, region:regions(*)')
          .order('name');

      debugPrint('Response received: ${response.length} vendors found');
      if (response.isNotEmpty) {
        debugPrint('First vendor data: ${response.first}');
      }

      // Convert the response to Vendor objects
      final vendors = response.map((data) {
        // Extract region data
        final Map<String, dynamic> regionData = data['region'] ?? {};
        final region = Region(
          id: regionData['id'] ?? '',
          name: regionData['name'] ?? '',
          createdAt: regionData['created_at'] != null
              ? DateTime.parse(regionData['created_at'])
              : null,
          updatedAt: regionData['updated_at'] != null
              ? DateTime.parse(regionData['updated_at'])
              : null,
        );

        // Create vendor with region
        return Vendor(
          id: data['id'] ?? '',
          name: data['name'] ?? '',
          email: data['email'] ?? '',
          phone: data['phone'],
          address: data['address'],
          regionId: data['region_id'],
          region: region,
          isActive: data['is_active'] ?? true,
          isManagement: data['is_management'] ?? false,
          createdAt: data['created_at'] != null
              ? DateTime.parse(data['created_at'])
              : DateTime.now(),
          updatedAt: data['updated_at'] != null
              ? DateTime.parse(data['updated_at'])
              : DateTime.now(),
        );
      }).toList();

      setState(() {
        _vendors = vendors;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        debugPrint('Error loading vendors: $e');
        setState(() {
          _error = 'Failed to load vendors: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadRegions() async {
    try {
      debugPrint('Querying regions table...');
      final response = await supabase.from('regions').select();
      final regions =
          (response as List).map((data) => Region.fromJson(data)).toList();
      if (mounted) {
        setState(() => _regions = regions);
      }
      debugPrint('Loaded ${regions.length} regions');
    } catch (e) {
      debugPrint('Failed to load regions: $e');
      if (mounted) {
        setState(() => _error = '${_error ?? ''}\nFailed to load regions: $e');
      }
    }
  }

  // Add this utility method for showing copyable error messages
  void _showCopyableError(
      BuildContext context, String title, String errorMessage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Error details:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
              width: double.infinity,
              child: SelectableText(
                errorMessage,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: errorMessage));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Error copied to clipboard'),
                    duration: Duration(seconds: 2),
                  ),
                );
                Navigator.of(context).pop();
              }
            },
            child: const Text('Copy Error'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteVendor(Vendor vendor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vendor'),
        content: Text('Are you sure you want to delete ${vendor.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Call the Edge Function to delete the vendor user
        final response = await supabase.functions.invoke(
          'delete-vendor-with-auth',
          body: {
            'vendorId': vendor.id,
          },
        );

        if (response.status != 200) {
          final error =
              response.data is Map ? response.data['error'] : 'Unknown error';
          throw Exception(error);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${vendor.name} deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }

        // Reload the list
        await _loadVendors();
      } catch (e) {
        if (mounted) {
          debugPrint('Error deleting vendor: $e');
          _showCopyableError(context, 'Error Deleting Vendor', e.toString());
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<bool> _checkVendorRelatedData(String vendorId) async {
    try {
      // Check for markets
      final marketsResponse =
          await supabase.from('markets').select('id').eq('vendor_id', vendorId);

      if (marketsResponse.isNotEmpty) {
        return true;
      }

      // Check for sales
      final salesResponse =
          await supabase.from('sales').select('id').eq('vendor_id', vendorId);

      if (salesResponse.isNotEmpty) {
        return true;
      }

      // No related data found
      return false;
    } catch (e) {
      debugPrint('Error checking vendor related data: $e');
      // On error, assume there's related data to prevent accidental deletion
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isManagement = authState.isManagement;

    if (!isManagement) {
      return const Center(
        child: Text('You do not have permission to access this page.'),
      );
    }

    return AppLayout(
      title: 'Manage Vendors',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadInitialData,
          tooltip: 'Refresh',
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: $_error', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadInitialData,
                        child: const Text('Retry'),
                      ),
                      TextButton(
                        onPressed: () {
                          _showCopyableError(context, 'Error Details',
                              _error ?? 'Unknown error');
                        },
                        child: const Text('View Details'),
                      ),
                    ],
                  ),
                )
              : _vendors.isEmpty
                  ? const Center(child: Text('No vendors found'))
                  : RefreshIndicator(
                      onRefresh: _loadInitialData,
                      child: ListView.builder(
                        itemCount: _vendors.length,
                        itemBuilder: (context, index) {
                          final vendor = _vendors[index];
                          return _buildVendorCard(context, vendor);
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddVendorDialog(context),
        tooltip: 'Add Vendor',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildVendorCard(BuildContext context, Vendor vendor) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vendor.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (vendor.email.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            vendor.email,
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                        ),
                      if (vendor.phone != null && vendor.phone!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            vendor.phone!,
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                        ),
                      if (vendor.regionId != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Region: ${vendor.region?.name ?? 'Unknown'}',
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Chip(
                      label: Text(
                        vendor.isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          color: vendor.isActive ? Colors.white : Colors.black,
                        ),
                      ),
                      backgroundColor:
                          vendor.isActive ? Colors.green : Colors.grey[300],
                    ),
                    const SizedBox(height: 4),
                    Chip(
                      label: Text(
                        vendor.isManagement ? 'Admin' : 'Vendor',
                        style: TextStyle(
                          color:
                              vendor.isManagement ? Colors.white : Colors.black,
                        ),
                      ),
                      backgroundColor:
                          vendor.isManagement ? Colors.blue : Colors.grey[300],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Reset Password Button
                OutlinedButton.icon(
                  icon: const Icon(Icons.lock_reset),
                  label: const Text('Reset Password'),
                  onPressed: () => _showResetPasswordDialog(context, vendor),
                ),
                const SizedBox(width: 8),
                // Edit Button
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                  onPressed: () => _showAddVendorDialog(
                    context,
                    vendorToEdit: vendor,
                  ),
                ),
                const SizedBox(width: 8),
                // Delete Button
                OutlinedButton.icon(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  label: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                  onPressed: () => _deleteVendor(vendor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Add password reset dialog for vendor
  Future<void> _showResetPasswordDialog(
      BuildContext context, Vendor vendor) async {
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isLoading = false;
    bool obscurePassword = true;
    bool obscureConfirmPassword = true;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Reset Password for ${vendor.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter a new password for this account:',
                ),
                const SizedBox(height: 16),
                Text(
                  vendor.email,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() => obscurePassword = !obscurePassword);
                      },
                    ),
                  ),
                  obscureText: obscurePassword,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() =>
                            obscureConfirmPassword = !obscureConfirmPassword);
                      },
                    ),
                  ),
                  obscureText: obscureConfirmPassword,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Alternative: You can also send a password reset email to the user.',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      try {
                        setState(() => isLoading = true);
                        await supabase.auth.resetPasswordForEmail(vendor.email);
                        Navigator.pop(context);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Password reset email sent to ${vendor.email}'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setState(() => isLoading = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: ${e.toString()}'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: const Text('Send Reset Email'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      // Validate passwords
                      if (passwordController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a password'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (passwordController.text.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Password must be at least 6 characters'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (passwordController.text !=
                          confirmPasswordController.text) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Passwords do not match'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      try {
                        // Show loading indicator
                        setState(() => isLoading = true);

                        // Call the Edge Function to reset the password
                        final response = await supabase.functions.invoke(
                          'reset-vendor-password',
                          body: {
                            'email': vendor.email,
                            'newPassword': passwordController.text,
                          },
                        );

                        // Close the dialog
                        Navigator.pop(context);

                        if (response.status != 200) {
                          final error = response.data is Map
                              ? response.data['error']
                              : 'Unknown error';
                          _showCopyableError(
                              context, 'Password Reset Failed', error);
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Password reset successful'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        setState(() => isLoading = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: ${e.toString()}'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: const Text('Reset Password'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddVendorDialog(BuildContext context,
      {Vendor? vendorToEdit}) async {
    final nameController =
        TextEditingController(text: vendorToEdit?.name ?? '');
    final emailController =
        TextEditingController(text: vendorToEdit?.email ?? '');
    final phoneController =
        TextEditingController(text: vendorToEdit?.phone ?? '');
    final addressController =
        TextEditingController(text: vendorToEdit?.address ?? '');

    String? selectedRegionId = vendorToEdit?.regionId;
    bool isActive = vendorToEdit?.isActive ?? true;
    bool isManagement = vendorToEdit?.isManagement ?? false;
    bool isCreatingNew = vendorToEdit == null;

    // Only ask for password when creating a new vendor
    final passwordController = TextEditingController();
    bool obscurePassword = true;
    bool isLoading = false;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isCreatingNew ? 'Add New Vendor' : 'Edit Vendor'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name *'),
                ),
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email *'),
                  keyboardType: TextInputType.emailAddress,
                ),
                if (isCreatingNew)
                  TextFormField(
                    controller: passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password *',
                      suffixIcon: IconButton(
                        icon: Icon(obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setState(() => obscurePassword = !obscurePassword),
                      ),
                    ),
                    obscureText: obscurePassword,
                  ),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  keyboardType: TextInputType.phone,
                ),
                TextFormField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedRegionId,
                  hint: const Text('Select Region'),
                  items: _regions.map((region) {
                    return DropdownMenuItem(
                      value: region.id,
                      child: Text(region.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => selectedRegionId = value);
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Active: '),
                    Switch(
                      value: isActive,
                      onChanged: (value) => setState(() => isActive = value),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text('Admin: '),
                    Switch(
                      value: isManagement,
                      onChanged: (value) =>
                          setState(() => isManagement = value),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      // Validate inputs
                      if (nameController.text.isEmpty ||
                          emailController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Name and Email are required'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (isCreatingNew && passwordController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Password is required for new vendors'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      setState(() => isLoading = true);

                      try {
                        if (isCreatingNew) {
                          // Create new vendor
                          await supabase.functions.invoke(
                            'create-vendor-user',
                            body: {
                              'email': emailController.text,
                              'password': passwordController.text,
                              'userData': {
                                'name': nameController.text,
                                'email': emailController.text,
                                'phone': phoneController.text,
                                'address': addressController.text,
                                'region_id': selectedRegionId,
                                'is_active': isActive,
                                'is_management': isManagement,
                                'created_at': DateTime.now().toIso8601String(),
                                'updated_at': DateTime.now().toIso8601String(),
                              },
                            },
                          );
                        } else {
                          // Update existing vendor
                          await supabase.from('vendors').update({
                            'name': nameController.text,
                            'email': emailController.text,
                            'phone': phoneController.text,
                            'address': addressController.text,
                            'region_id': selectedRegionId,
                            'is_active': isActive,
                            'is_management': isManagement,
                            'updated_at': DateTime.now().toIso8601String(),
                          }).eq('id', vendorToEdit!.id);
                        }

                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isCreatingNew
                                  ? 'Vendor created successfully'
                                  : 'Vendor updated successfully',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );

                        // Reload vendors
                        await _loadVendors();
                      } catch (e) {
                        setState(() => isLoading = false);
                        _showCopyableError(
                          context,
                          isCreatingNew
                              ? 'Error Creating Vendor'
                              : 'Error Updating Vendor',
                          e.toString(),
                        );
                      }
                    },
              child: Text(isCreatingNew ? 'Create' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }
}
