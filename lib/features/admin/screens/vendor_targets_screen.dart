import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/vendor_target.dart';
import '../../../providers/vendor_targets_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/app_layout.dart';
import '../../../providers/vendor_provider.dart';
import 'package:uuid/uuid.dart';

class VendorTargetsScreen extends ConsumerStatefulWidget {
  final String? vendorId;

  const VendorTargetsScreen({
    super.key,
    this.vendorId,
  });

  @override
  ConsumerState<VendorTargetsScreen> createState() =>
      _VendorTargetsScreenState();
}

class _VendorTargetsScreenState extends ConsumerState<VendorTargetsScreen> {
  bool _showActiveOnly = true;
  String? _filterType;
  final uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(vendorTargetsProvider.notifier).loadTargets(
            vendorId: widget.vendorId,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final targetsState = ref.watch(vendorTargetsProvider);
    final authState = ref.watch(authProvider);
    final isAdmin = authState.isManagement;

    // Filter targets based on active status and type
    final filteredTargets = targetsState.targets.where((target) {
      if (_showActiveOnly && !target.isCurrentlyActive) return false;
      if (_filterType != null && target.targetType.toJson() != _filterType) {
        return false;
      }
      return true;
    }).toList();

    return AppLayout(
      title: widget.vendorId == null
          ? 'Vendor Targets'
          : 'Targets for ${targetsState.targets.isNotEmpty ? targetsState.targets.first.vendor?.name ?? 'Vendor' : 'Vendor'}',
      actions: [
        IconButton(
          icon: const Icon(Icons.filter_list),
          tooltip: 'Filter',
          onPressed: _showFilterDialog,
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: targetsState.isLoading
              ? null
              : () => ref
                  .read(vendorTargetsProvider.notifier)
                  .loadTargets(vendorId: widget.vendorId),
        ),
      ],
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: _showAddTargetDialog,
              tooltip: 'Add Target',
              child: const Icon(Icons.add),
            )
          : null,
      body: targetsState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : targetsState.error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Error loading targets: ${targetsState.error}',
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => ref
                            .read(vendorTargetsProvider.notifier)
                            .loadTargets(vendorId: widget.vendorId),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : filteredTargets.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'No targets found',
                            style: TextStyle(fontSize: 18),
                          ),
                          const SizedBox(height: 16),
                          if (isAdmin)
                            ElevatedButton(
                              onPressed: _showAddTargetDialog,
                              child: const Text('Create New Target'),
                            ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        await ref
                            .read(vendorTargetsProvider.notifier)
                            .loadTargets(vendorId: widget.vendorId);
                      },
                      child: Column(
                        children: [
                          // Filter chips
                          _buildFilterChips(),

                          // Targets list
                          Expanded(
                            child: ListView.builder(
                              itemCount: filteredTargets.length,
                              padding: const EdgeInsets.all(8),
                              itemBuilder: (context, index) {
                                final target = filteredTargets[index];
                                return _buildTargetCard(target, isAdmin);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Wrap(
        spacing: 8,
        children: [
          FilterChip(
            label: const Text('Active Only'),
            selected: _showActiveOnly,
            onSelected: (value) {
              setState(() {
                _showActiveOnly = value;
              });
            },
          ),
          FilterChip(
            label: const Text('Units'),
            selected: _filterType == 'units',
            onSelected: (value) {
              setState(() {
                _filterType = value ? 'units' : null;
              });
            },
          ),
          FilterChip(
            label: const Text('Revenue'),
            selected: _filterType == 'revenue',
            onSelected: (value) {
              setState(() {
                _filterType = value ? 'revenue' : null;
              });
            },
          ),
          const SizedBox(width: 8),
          if (_showActiveOnly || _filterType != null)
            TextButton.icon(
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('Clear Filters'),
              onPressed: () {
                setState(() {
                  _showActiveOnly = false;
                  _filterType = null;
                });
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTargetCard(VendorTarget target, bool isAdmin) {
    final now = DateTime.now();
    final isActive = target.isActive &&
        target.startDate.isBefore(now) &&
        target.endDate.isAfter(now);
    final isPast = target.endDate.isBefore(now);
    final isFuture = target.startDate.isAfter(now);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    target.targetName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildStatusChip(isActive, isPast, isFuture),
              ],
            ),
            const SizedBox(height: 8),
            if (target.targetDescription != null &&
                target.targetDescription!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  target.targetDescription!,
                  style: TextStyle(
                    color: Colors.grey[700],
                  ),
                ),
              ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Type: ${target.targetType.displayName}'),
                      const SizedBox(height: 4),
                      Text(
                        'Target: ${target.formattedTargetValue}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'Product: ${target.product?.name ?? 'All Products'}'),
                      const SizedBox(height: 4),
                      if (widget.vendorId == null && target.vendor != null)
                        Text('Vendor: ${target.vendor!.name}'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Period: ${target.formattedDateRange}'),
            const SizedBox(height: 16),

            // Progress section
            if (target.achievedValue != null &&
                target.progressPercentage != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progress: ${target.formattedProgress}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${target.progressPercentage!.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _getProgressColor(target.progressPercentage!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: target.progressPercentage! / 100,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getProgressColor(target.progressPercentage!),
                    ),
                    minHeight: 8,
                  ),
                ],
              ),

            // Admin actions
            if (isAdmin)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                      onPressed: () => _showEditTargetDialog(target),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      icon: Icon(Icons.delete, color: Colors.red[700]),
                      label: const Text('Delete',
                          style: TextStyle(color: Colors.red)),
                      onPressed: () => _showDeleteDialog(target),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(bool isActive, bool isPast, bool isFuture) {
    if (isActive) {
      return Chip(
        label: const Text('Active'),
        backgroundColor: Colors.green[100],
        labelStyle: TextStyle(color: Colors.green[800]),
      );
    } else if (isPast) {
      return Chip(
        label: const Text('Completed'),
        backgroundColor: Colors.grey[300],
        labelStyle: TextStyle(color: Colors.grey[800]),
      );
    } else if (isFuture) {
      return Chip(
        label: const Text('Upcoming'),
        backgroundColor: Colors.blue[100],
        labelStyle: TextStyle(color: Colors.blue[800]),
      );
    } else {
      return Chip(
        label: const Text('Inactive'),
        backgroundColor: Colors.red[100],
        labelStyle: TextStyle(color: Colors.red[800]),
      );
    }
  }

  Color _getProgressColor(double percentage) {
    if (percentage >= 100) {
      return Colors.green;
    } else if (percentage >= 75) {
      return Colors.lightGreen;
    } else if (percentage >= 50) {
      return Colors.amber;
    } else if (percentage >= 25) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Filter Targets'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CheckboxListTile(
                    title: const Text('Show Active Only'),
                    value: _showActiveOnly,
                    onChanged: (value) {
                      setDialogState(() {
                        _showActiveOnly = value ?? false;
                      });
                      setState(() {
                        _showActiveOnly = value ?? false;
                      });
                    },
                  ),
                  const Divider(),
                  const Text('Target Type:'),
                  RadioListTile<String?>(
                    title: const Text('All Types'),
                    value: null,
                    groupValue: _filterType,
                    onChanged: (value) {
                      setDialogState(() {
                        _filterType = value;
                      });
                      setState(() {
                        _filterType = value;
                      });
                    },
                  ),
                  RadioListTile<String?>(
                    title: const Text('Units'),
                    value: 'units',
                    groupValue: _filterType,
                    onChanged: (value) {
                      setDialogState(() {
                        _filterType = value;
                      });
                      setState(() {
                        _filterType = value;
                      });
                    },
                  ),
                  RadioListTile<String?>(
                    title: const Text('Revenue'),
                    value: 'revenue',
                    groupValue: _filterType,
                    onChanged: (value) {
                      setDialogState(() {
                        _filterType = value;
                      });
                      setState(() {
                        _filterType = value;
                      });
                    },
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
              ],
            );
          },
        );
      },
    );
  }

  void _showAddTargetDialog() {
    final isManagement = ref.read(authProvider).isManagement;
    final targetNameController = TextEditingController();
    final targetDescriptionController = TextEditingController();
    String? selectedVendorId;
    TargetType targetType = TargetType.units;
    final targetValueController = TextEditingController();
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 30));
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Target'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: targetNameController,
                    decoration: const InputDecoration(labelText: 'Target Name'),
                    validator: (value) =>
                        value!.isEmpty ? 'Please enter a target name' : null,
                  ),
                  TextFormField(
                    controller: targetDescriptionController,
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  if (isManagement) ...[
                    const Text('Vendor'),
                    Consumer(
                      builder: (context, ref, _) {
                        final vendorState = ref.watch(vendorProvider);

                        if (vendorState.isLoading) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        if (vendorState.error != null) {
                          return Text('Error: ${vendorState.error}',
                              style: const TextStyle(color: Colors.red));
                        }

                        final vendors = vendorState.vendors;

                        return DropdownButtonFormField<String>(
                          value: selectedVendorId,
                          items: vendors.map((vendor) {
                            return DropdownMenuItem<String>(
                              value: vendor.id,
                              child: Text(vendor.name),
                            );
                          }).toList(),
                          onChanged: (value) {
                            selectedVendorId = value;
                          },
                          decoration: const InputDecoration(
                            hintText: 'Select Vendor',
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Please select a vendor'
                              : null,
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Text('Target Type'),
                  DropdownButtonFormField<TargetType>(
                    value: targetType,
                    items: TargetType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type.displayName),
                      );
                    }).toList(),
                    onChanged: (value) {
                      targetType = value!;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: targetValueController,
                    decoration:
                        const InputDecoration(labelText: 'Target Value'),
                    keyboardType: TextInputType.number,
                    validator: (value) =>
                        value!.isEmpty || double.tryParse(value) == null
                            ? 'Please enter a valid number'
                            : null,
                  ),
                  const SizedBox(height: 16),
                  const Text('Date Range'),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: startDate,
                              firstDate: DateTime.now()
                                  .subtract(const Duration(days: 30)),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null) {
                              startDate = date;
                            }
                          },
                          child: Text(
                              'From: ${DateFormat('yyyy-MM-dd').format(startDate)}'),
                        ),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: endDate,
                              firstDate: startDate,
                              lastDate:
                                  startDate.add(const Duration(days: 365)),
                            );
                            if (date != null) {
                              endDate = date;
                            }
                          },
                          child: Text(
                              'To: ${DateFormat('yyyy-MM-dd').format(endDate)}'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  // Get the vendor ID (either selected or current user's)
                  final vendorId = isManagement
                      ? selectedVendorId
                      : ref.read(authProvider).vendor?.id;

                  if (vendorId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Vendor selection required')),
                    );
                    return;
                  }

                  // Create a new target
                  ref.read(vendorTargetsProvider.notifier).createTarget(
                        vendorId: vendorId,
                        targetName: targetNameController.text,
                        targetDescription: targetDescriptionController.text,
                        targetType: targetType,
                        targetValue: double.parse(targetValueController.text),
                        startDate: startDate,
                        endDate: endDate,
                      );

                  Navigator.of(context).pop();
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showEditTargetDialog(VendorTarget target) {
    final isManagement = ref.read(authProvider).isManagement;
    final targetNameController = TextEditingController(text: target.targetName);
    final targetDescriptionController =
        TextEditingController(text: target.targetDescription);
    String? selectedVendorId = target.vendorId;
    TargetType targetType = target.targetType;
    final targetValueController =
        TextEditingController(text: target.targetValue.toString());
    DateTime startDate = target.startDate;
    DateTime endDate = target.endDate;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Target'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: targetNameController,
                    decoration: const InputDecoration(labelText: 'Target Name'),
                    validator: (value) =>
                        value!.isEmpty ? 'Please enter a target name' : null,
                  ),
                  TextFormField(
                    controller: targetDescriptionController,
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  if (isManagement) ...[
                    const Text('Vendor'),
                    Consumer(
                      builder: (context, ref, _) {
                        final vendorState = ref.watch(vendorProvider);

                        if (vendorState.isLoading) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        if (vendorState.error != null) {
                          return Text('Error: ${vendorState.error}',
                              style: const TextStyle(color: Colors.red));
                        }

                        final vendors = vendorState.vendors;

                        return DropdownButtonFormField<String>(
                          value: selectedVendorId,
                          items: vendors.map((vendor) {
                            return DropdownMenuItem<String>(
                              value: vendor.id,
                              child: Text(vendor.name),
                            );
                          }).toList(),
                          onChanged: (value) {
                            selectedVendorId = value;
                          },
                          decoration: const InputDecoration(
                            hintText: 'Select Vendor',
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Please select a vendor'
                              : null,
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Text('Target Type'),
                  DropdownButtonFormField<TargetType>(
                    value: targetType,
                    items: TargetType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type.displayName),
                      );
                    }).toList(),
                    onChanged: (value) {
                      targetType = value!;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: targetValueController,
                    decoration:
                        const InputDecoration(labelText: 'Target Value'),
                    keyboardType: TextInputType.number,
                    validator: (value) =>
                        value!.isEmpty || double.tryParse(value) == null
                            ? 'Please enter a valid number'
                            : null,
                  ),
                  const SizedBox(height: 16),
                  const Text('Date Range'),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: startDate,
                              firstDate: DateTime.now()
                                  .subtract(const Duration(days: 30)),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null) {
                              startDate = date;
                            }
                          },
                          child: Text(
                              'From: ${DateFormat('yyyy-MM-dd').format(startDate)}'),
                        ),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: endDate,
                              firstDate: startDate,
                              lastDate:
                                  startDate.add(const Duration(days: 365)),
                            );
                            if (date != null) {
                              endDate = date;
                            }
                          },
                          child: Text(
                              'To: ${DateFormat('yyyy-MM-dd').format(endDate)}'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  // Get the vendor ID (either selected or current user's)
                  final vendorId = isManagement
                      ? selectedVendorId
                      : ref.read(authProvider).vendor?.id;

                  if (vendorId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Vendor selection required')),
                    );
                    return;
                  }

                  // Update the target
                  final updatedTarget = target.copyWith(
                    vendorId: vendorId,
                    targetName: targetNameController.text,
                    targetDescription: targetDescriptionController.text,
                    targetType: targetType,
                    targetValue: double.parse(targetValueController.text),
                    startDate: startDate,
                    endDate: endDate,
                    updatedAt: DateTime.now(),
                  );

                  // Update the target
                  ref
                      .read(vendorTargetsProvider.notifier)
                      .updateTarget(updatedTarget);
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteDialog(VendorTarget target) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: Text(
              'Are you sure you want to delete the target "${target.targetName}"?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                ref
                    .read(vendorTargetsProvider.notifier)
                    .deleteTarget(target.id);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}
