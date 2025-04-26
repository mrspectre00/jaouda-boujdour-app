import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/promotion.dart';
import '../../../widgets/app_drawer.dart';
import '../providers/promotions_provider.dart';
import '../../sales/providers/sales_provider.dart';
import '../../../widgets/app_layout.dart';

class PromotionsManagementScreen extends ConsumerWidget {
  const PromotionsManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promotionsState = ref.watch(promotionsProvider);
    final promotionsNotifier = ref.read(promotionsProvider.notifier);

    return AppLayout(
      title: 'Promotions Management',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh Promotions',
          onPressed: () => promotionsNotifier.loadPromotions(),
        ),
      ],
      body: promotionsState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : promotionsState.error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Error: ${promotionsState.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => promotionsNotifier.loadPromotions(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : promotionsState.promotions.isEmpty
                  ? Center(
                      child: Text(
                        'No promotions found.',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    )
                  : ListView.builder(
                      itemCount: promotionsState.promotions.length,
                      itemBuilder: (context, index) {
                        final promotion = promotionsState.promotions[index];
                        return PromotionCard(promotion: promotion);
                      },
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showPromotionDialog(context, ref),
        tooltip: 'Add Promotion',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class PromotionCard extends ConsumerWidget {
  final Promotion promotion;
  const PromotionCard({super.key, required this.promotion});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('yyyy-MM-dd');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    promotion.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Switch(
                  value: promotion.isActive,
                  onChanged: (value) async {
                    await ref
                        .read(promotionsProvider.notifier)
                        .savePromotion(promotion.copyWith(isActive: value));
                  },
                ),
              ],
            ),
            if (promotion.description != null &&
                promotion.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
                child: Text(promotion.description!),
              ),
            Text('Type: ${promotion.discountType.name}'),
            Text(
              'Value: ${promotion.discountType == DiscountType.percentage ? '${promotion.discountValue}%' : '\$${promotion.discountValue.toStringAsFixed(2)}'}',
            ),
            if (promotion.productId != null)
              Text('Product: ${promotion.productName ?? promotion.productId}'),
            if (promotion.startDate != null)
              Text('Starts: ${dateFormat.format(promotion.startDate!)}'),
            if (promotion.endDate != null)
              Text('Ends: ${dateFormat.format(promotion.endDate!)}'),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  label: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Confirm Deletion'),
                        content: const Text(
                          'Are you sure you want to delete this promotion?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await ref
                          .read(promotionsProvider.notifier)
                          .deletePromotion(promotion.id);
                    }
                  },
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                  onPressed: () => _showPromotionDialog(
                    context,
                    ref,
                    promotionToEdit: promotion,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- Add/Edit Promotion Dialog ---
void _showPromotionDialog(
  BuildContext context,
  WidgetRef ref, {
  Promotion? promotionToEdit,
}) {
  final isEditing = promotionToEdit != null;
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController(text: promotionToEdit?.name);
  final descriptionController = TextEditingController(
    text: promotionToEdit?.description,
  );
  final valueController = TextEditingController(
    text: promotionToEdit?.discountValue.toString(),
  );

  String? selectedProductId = promotionToEdit?.productId;
  DiscountType selectedDiscountType =
      promotionToEdit?.discountType ?? DiscountType.fixedAmount;
  DateTime? startDate = promotionToEdit?.startDate;
  DateTime? endDate = promotionToEdit?.endDate;
  bool isActive = promotionToEdit?.isActive ?? true;
  bool isLoading = false;

  // Load products for dropdown
  final products = ref.read(salesProvider).products;

  Future<void> selectDate(BuildContext context, bool isStart) async {
    final initial = isStart
        ? (startDate ?? DateTime.now())
        : (endDate ?? startDate ?? DateTime.now());
    final first = isStart ? DateTime(2020) : (startDate ?? DateTime(2020));
    final last = DateTime(2101);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );

    if (picked != null) {
      if (isStart) {
        startDate = picked;
        // Ensure end date is not before start date
        if (endDate != null && endDate!.isBefore(startDate!)) {
          endDate = startDate;
        }
      } else {
        endDate = picked;
      }
    }
  }

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final dateFormat = DateFormat('yyyy-MM-dd');
          return AlertDialog(
            title: Text(isEditing ? 'Edit Promotion' : 'Add New Promotion'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Promotion Name',
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Name is required' : null,
                    ),
                    TextFormField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                      ),
                      maxLines: 2,
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<DiscountType>(
                            value: selectedDiscountType,
                            decoration: const InputDecoration(
                              labelText: 'Discount Type',
                            ),
                            items: DiscountType.values.map((type) {
                              return DropdownMenuItem(
                                value: type,
                                child: Text(type.name),
                              );
                            }).toList(),
                            onChanged: (DiscountType? newValue) {
                              if (newValue != null) {
                                setDialogState(
                                  () => selectedDiscountType = newValue,
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: valueController,
                            decoration: InputDecoration(
                              labelText: 'Discount Value',
                              prefixText: selectedDiscountType ==
                                      DiscountType.fixedAmount
                                  ? '\$'
                                  : null,
                              suffixText: selectedDiscountType ==
                                      DiscountType.percentage
                                  ? '%'
                                  : null,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Value required';
                              }
                              final val = double.tryParse(v);
                              if (val == null) return 'Invalid number';
                              if (selectedDiscountType ==
                                      DiscountType.percentage &&
                                  (val <= 0 || val > 100)) {
                                return 'Must be 1-100';
                              }
                              if (val <= 0) return 'Must be > 0';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String?>(
                      value: selectedProductId,
                      decoration: const InputDecoration(
                        labelText: 'Apply to Specific Product (Optional)',
                        helperText: 'Leave empty to apply to all products',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All Products'),
                        ),
                        ...products.map((product) {
                          final id = product['id'] as String?;
                          final name =
                              product['name'] as String? ?? 'Unknown Product';
                          return DropdownMenuItem<String?>(
                            value: id,
                            child: Text(name, overflow: TextOverflow.ellipsis),
                          );
                        }),
                      ],
                      onChanged: (String? newValue) {
                        setDialogState(() {
                          selectedProductId = newValue;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              await selectDate(context, true);
                              setDialogState(
                                () {},
                              ); // Update UI after date pick
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Start Date (Optional)',
                              ),
                              child: Text(
                                startDate != null
                                    ? dateFormat.format(startDate!)
                                    : 'Not Set',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              await selectDate(context, false);
                              setDialogState(() {});
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'End Date (Optional)',
                              ),
                              child: Text(
                                endDate != null
                                    ? dateFormat.format(endDate!)
                                    : 'Not Set',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SwitchListTile(
                      title: const Text('Active'),
                      value: isActive,
                      onChanged: (bool value) =>
                          setDialogState(() => isActive = value),
                    ),
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed:
                    isLoading ? null : () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (formKey.currentState!.validate()) {
                          setDialogState(() => isLoading = true);

                          // Find the product name if a product ID is selected
                          String? productName;
                          if (selectedProductId != null) {
                            final product = products.firstWhere(
                              (p) => p['id'] == selectedProductId,
                              orElse: () => <String, dynamic>{},
                            );
                            productName = product['name'] as String?;
                          }

                          final promotion = Promotion(
                            id: promotionToEdit?.id ??
                                '', // Let provider handle ID generation if empty
                            name: nameController.text,
                            description: descriptionController.text.isEmpty
                                ? null
                                : descriptionController.text,
                            discountType: selectedDiscountType,
                            discountValue: double.parse(valueController.text),
                            productId: selectedProductId,
                            productName: productName,
                            startDate: startDate,
                            endDate: endDate,
                            isActive: isActive,
                          );

                          final success = await ref
                              .read(promotionsProvider.notifier)
                              .savePromotion(promotion);
                          setDialogState(() => isLoading = false);

                          if (success && context.mounted) {
                            Navigator.of(dialogContext).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Promotion ${isEditing ? 'updated' : 'added'} successfully',
                                ),
                              ),
                            );
                          } else if (!success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to save promotion'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(isEditing ? 'Save Changes' : 'Add'),
              ),
            ],
          );
        },
      );
    },
  );
}
