import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../models/product.dart';
import '../../../services/supabase_client.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/stock_provider.dart';

class ProductsState {
  final List<Product> products;
  final bool isLoading;
  final String? error;

  ProductsState({this.products = const [], this.isLoading = false, this.error});

  ProductsState copyWith({
    List<Product>? products,
    bool? isLoading,
    String? error,
  }) {
    return ProductsState(
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final productsProvider = StateNotifierProvider<ProductsNotifier, ProductsState>(
  (ref) {
    return ProductsNotifier(ref);
  },
);

class ProductsNotifier extends StateNotifier<ProductsState> {
  final Ref _ref;

  ProductsNotifier(this._ref) : super(ProductsState()) {
    loadProducts();
  }

  Future<void> loadProducts() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      debugPrint('Loading products...');
      final response = await supabase.from('products').select();
      final products =
          (response as List).map((data) => Product.fromJson(data)).toList();
      // Sort products alphabetically for consistent display
      products.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      state = state.copyWith(products: products, isLoading: false);
      debugPrint('Loaded ${products.length} products.');
    } catch (e) {
      debugPrint('Error loading products: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load products: $e',
      );
    }
  }

  Future<bool> saveProduct(Product product) async {
    state = state.copyWith(isLoading: true);
    final authState = _ref.read(authProvider);
    // Ensure user is management
    if (!authState.isManagement) {
      state = state.copyWith(
        isLoading: false,
        error: 'Access Denied: Only management can save products.',
      );
      return false;
    }

    try {
      final data = product.toJson();
      final existingProduct = state.products.any((p) => p.id == product.id);
      final vendorId = authState.vendor?.id;

      if (vendorId == null) {
        throw Exception('No vendor ID available');
      }

      if (existingProduct) {
        debugPrint('Updating product ${product.id}');
        await supabase.from('products').update(data).eq('id', product.id);

        // Also update the stock table if stockQuantity changed
        if (product.stockQuantity != null) {
          // Check if there's a stock record for this product
          final stockResponse = await supabase
              .from('stock')
              .select()
              .eq('product_id', product.id)
              .eq('vendor_id', vendorId);

          if (stockResponse.isNotEmpty) {
            // Update existing stock record
            await supabase
                .from('stock')
                .update({'quantity': product.stockQuantity})
                .eq('product_id', product.id)
                .eq('vendor_id', vendorId);
          } else {
            // Create new stock record
            await supabase.from('stock').insert({
              'product_id': product.id,
              'vendor_id': vendorId,
              'quantity': product.stockQuantity,
            });
          }

          // Notify stock provider to refresh
          _ref.read(stockProvider.notifier).loadStock();
        }
      } else {
        final productWithId = product.id.isEmpty
            ? product.copyWith(id: const Uuid().v4())
            : product;
        debugPrint('Adding new product ${productWithId.id}');
        await supabase.from('products').insert(productWithId.toJson());

        // Also create a stock record if stockQuantity is provided
        if (product.stockQuantity != null && product.stockQuantity! > 0) {
          await supabase.from('stock').insert({
            'product_id': productWithId.id,
            'vendor_id': vendorId,
            'quantity': product.stockQuantity,
          });

          // Notify stock provider to refresh
          _ref.read(stockProvider.notifier).loadStock();
        }
      }

      await loadProducts(); // Refresh the list
      return true;
    } catch (e) {
      debugPrint('Error saving product: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to save product: $e',
      );
      return false;
    }
  }

  Future<bool> deleteProduct(String productId) async {
    state = state.copyWith(isLoading: true);
    final authState = _ref.read(authProvider);
    if (!authState.isManagement) {
      state = state.copyWith(
        isLoading: false,
        error: 'Access Denied: Only management can delete products.',
      );
      return false;
    }

    try {
      debugPrint('Deleting product $productId');
      await supabase.from('products').delete().eq('id', productId);
      await loadProducts(); // Refresh the list
      return true;
    } catch (e) {
      debugPrint('Error deleting product: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to delete product: $e',
      );
      return false;
    }
  }
}
