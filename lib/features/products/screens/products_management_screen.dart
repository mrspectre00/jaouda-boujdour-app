import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/product.dart';
import '../../../widgets/app_layout.dart';
import '../providers/products_provider.dart';
import '../../../config/theme.dart'; // For consistent styling

class ProductsManagementScreen extends ConsumerWidget {
  const ProductsManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsState = ref.watch(productsProvider);
    final productsNotifier = ref.read(productsProvider.notifier);

    return AppLayout(
      title: 'Manage Products',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh Products',
          onPressed: () => productsNotifier.loadProducts(),
        ),
      ],
      body: productsState.isLoading && productsState.products.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : productsState.error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Error: ${productsState.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => productsNotifier.loadProducts(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : productsState.products.isEmpty
                  ? Center(
                      child: Text(
                        'No products found. Add one!',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    )
                  : ListView.builder(
                      itemCount: productsState.products.length,
                      itemBuilder: (context, index) {
                        final product = productsState.products[index];
                        return ProductCard(product: product);
                      },
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProductDialog(context, ref),
        tooltip: 'Add Product',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class ProductCard extends ConsumerWidget {
  final Product product;
  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    product.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Switch(
                  value: product.isActive,
                  onChanged: (value) async {
                    // Optimistic UI update (optional)
                    // ref.read(productsProvider.notifier).state = ref.read(productsProvider.notifier).state.copyWith(
                    //   products: ref.read(productsProvider.notifier).state.products.map((p) => p.id == product.id ? p.copyWith(isActive: value) : p).toList()
                    // );
                    await ref
                        .read(productsProvider.notifier)
                        .saveProduct(product.copyWith(isActive: value));
                    // Error handling would revert the optimistic update or show snackbar
                  },
                ),
              ],
            ),
            Text(
              'Price: \$${product.price.toStringAsFixed(2)}',
              style: const TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (product.category != null) Text('Category: ${product.category}'),
            if (product.stockQuantity != null)
              Text('Stock: ${product.stockQuantity}'),
            if (product.description != null && product.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(product.description!),
              ),
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
                          'Are you sure you want to delete this product? This might affect existing sales records.',
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
                      final success = await ref
                          .read(productsProvider.notifier)
                          .deleteProduct(product.id);
                      if (!success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Failed to delete product: ${ref.read(productsProvider).error}',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                  onPressed: () => _showProductDialog(
                    context,
                    ref,
                    productToEdit: product,
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

// --- Add/Edit Product Dialog ---
void _showProductDialog(
  BuildContext context,
  WidgetRef ref, {
  Product? productToEdit,
}) {
  final isEditing = productToEdit != null;
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController(text: productToEdit?.name);
  final descriptionController = TextEditingController(
    text: productToEdit?.description,
  );
  final priceController = TextEditingController(
    text: productToEdit?.price.toString(),
  );
  final categoryController = TextEditingController(
    text: productToEdit?.category,
  );
  final stockController = TextEditingController(
    text: productToEdit?.stockQuantity?.toString(),
  );
  final imageUrlController = TextEditingController(
    text: productToEdit?.imageUrl,
  );
  bool isActive = productToEdit?.isActive ?? true;
  bool isLoading = false;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(isEditing ? 'Edit Product' : 'Add New Product'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Product Name',
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Name is required' : null,
                    ),
                    TextFormField(
                      controller: priceController,
                      decoration: const InputDecoration(
                        labelText: 'Price',
                        prefixText: '\$',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Price required';
                        final val = double.tryParse(v);
                        if (val == null || val <= 0) {
                          return 'Invalid price (> 0)';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                      ),
                      maxLines: 3,
                    ),
                    TextFormField(
                      controller: categoryController,
                      decoration: const InputDecoration(
                        labelText: 'Category (Optional)',
                      ),
                    ),
                    TextFormField(
                      controller: stockController,
                      decoration: const InputDecoration(
                        labelText: 'Stock Quantity (Optional)',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v != null &&
                            v.isNotEmpty &&
                            double.tryParse(v) == null) {
                          return 'Invalid number';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: imageUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Image URL (Optional)',
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    SwitchListTile(
                      title: const Text('Active'),
                      value: isActive,
                      onChanged: (bool value) =>
                          setDialogState(() => isActive = value),
                      dense: true,
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

                          final product = Product(
                            // Use existing ID if editing, else provider handles generation via empty string
                            id: productToEdit?.id ?? '',
                            name: nameController.text.trim(),
                            description:
                                descriptionController.text.trim().isEmpty
                                    ? null
                                    : descriptionController.text.trim(),
                            unitPrice: double.parse(
                              priceController.text,
                            ), // Already validated
                            category: categoryController.text.trim().isEmpty
                                ? null
                                : categoryController.text.trim(),
                            stockQuantity: stockController.text.trim().isEmpty
                                ? null
                                : int.tryParse(
                                    stockController.text.trim(),
                                  ),
                            imageUrl: imageUrlController.text.trim().isEmpty
                                ? null
                                : imageUrlController.text.trim(),
                            isActive: isActive,
                            // Timestamps are handled by DB or default values in model not needed for save
                            createdAt: productToEdit?.createdAt ??
                                DateTime.now(), // Placeholder, DB handles this
                            updatedAt:
                                DateTime.now(), // Placeholder, DB handles this
                          );

                          final success = await ref
                              .read(productsProvider.notifier)
                              .saveProduct(product);

                          if (context.mounted) {
                            setDialogState(() => isLoading = false);
                            if (success) {
                              Navigator.of(dialogContext).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Product ${isEditing ? 'updated' : 'added'} successfully',
                                  ),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Failed to save product: ${ref.read(productsProvider).error}',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
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
