import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../models/product.dart';
import '../../../providers/stock_provider.dart';
import '../../../services/market_service.dart';
import '../../../widgets/app_layout.dart';
import '../../../theme/app_theme.dart';
import '../../../models/promotion.dart';
import '../../promotions/providers/promotions_provider.dart';
import '../../../providers/sales_provider.dart';
import '../../../models/market.dart';
import '../../../providers/markets_provider.dart';

class RecordSaleScreen extends ConsumerStatefulWidget {
  final String? marketId;

  const RecordSaleScreen({super.key, this.marketId});

  @override
  ConsumerState<RecordSaleScreen> createState() => _RecordSaleScreenState();
}

class _RecordSaleScreenState extends ConsumerState<RecordSaleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _unitPriceController = TextEditingController();
  final _notesController = TextEditingController();
  String? _selectedProductId;
  String? _selectedMarketId;
  Promotion? _selectedPromotion;
  double _totalAmount = 0.0;
  double _discountAmount = 0.0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      // Initialize selected market if provided
      _selectedMarketId = widget.marketId;

      // Load data
      if (_selectedMarketId != null) {
        _loadMarketData(_selectedMarketId!);
      }

      // Load products and markets regardless
      ref.read(salesProvider.notifier).loadProducts();
      ref.read(marketsProvider.notifier).loadMarkets();
    });
    _quantityController.addListener(_calculateTotal);
    _unitPriceController.addListener(_calculateTotal);
  }

  @override
  void dispose() {
    _quantityController.removeListener(_calculateTotal);
    _unitPriceController.removeListener(_calculateTotal);
    _quantityController.dispose();
    _unitPriceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadMarketData(String marketId) async {
    try {
      await ref.read(salesProvider.notifier).loadMarketData(marketId);
    } catch (e) {
      debugPrint('Error loading market data in RecordSaleScreen: $e');
    }
  }

  void _calculateTotal() {
    final quantity = double.tryParse(_quantityController.text) ?? 0;
    final unitPrice = double.tryParse(_unitPriceController.text) ?? 0;
    final subtotal = quantity * unitPrice;
    double discount = 0.0;

    if (_selectedPromotion != null) {
      if (_selectedPromotion!.discountType == DiscountType.percentage) {
        discount = subtotal * (_selectedPromotion!.discountValue / 100);
      } else {
        discount = _selectedPromotion!.discountValue;
      }
      discount = discount > subtotal ? subtotal : discount;
    }

    final total = subtotal - discount;

    if (mounted) {
      setState(() {
        _totalAmount = total > 0 ? total : 0;
        _discountAmount = discount > 0 ? discount : 0;
      });
    }
  }

  Future<void> _recordSale() async {
    if (!_formKey.currentState!.validate() ||
        _selectedProductId == null ||
        _selectedMarketId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a market, a product, and fill all required fields.',
          ),
        ),
      );
      return;
    }

    if (mounted) setState(() => _isLoading = true);

    try {
      await ref.read(salesProvider.notifier).recordSale(
            marketId: _selectedMarketId!,
            productId: _selectedProductId!,
            quantity: double.parse(_quantityController.text),
            unitPrice: double.parse(_unitPriceController.text),
            notes: _notesController.text.trim(),
            promotionId: _selectedPromotion?.id,
            discount: _discountAmount,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sale recorded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to record sale: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final salesState = ref.watch(salesProvider);
    final marketsState = ref.watch(marketsProvider);
    final market = _selectedMarketId != null ? salesState.selectedMarket : null;
    final products = salesState.products;
    final markets = marketsState.markets;
    final activePromotions = ref.watch(activePromotionsProvider);
    final providerIsLoading = salesState.isLoading;
    final providerError = salesState.error;

    final applicablePromotions = activePromotions.where((promo) {
      return promo.productId == null || promo.productId == _selectedProductId;
    }).toList();

    final showLoadingIndicator =
        (providerIsLoading && _selectedMarketId != null && market == null) ||
            _isLoading;

    return AppLayout(
      title: 'Record Sale${market != null ? ' - ${market['name']}' : ''}',
      body: showLoadingIndicator
          ? const Center(child: CircularProgressIndicator())
          : providerError != null && _selectedMarketId != null && market == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          providerError,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => _loadMarketData(_selectedMarketId!),
                        child: const Text('Retry'),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => context.go('/markets'),
                        child: const Text('Back to Markets'),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      children: [
                        // Market selector (only show if no marketId was provided)
                        if (widget.marketId == null)
                          DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Select Market',
                              border: OutlineInputBorder(),
                            ),
                            value: _selectedMarketId,
                            items: markets.map((market) {
                              return DropdownMenuItem<String>(
                                value: market.id,
                                child: Text(market.name),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedMarketId = value;
                                });
                                _loadMarketData(value);
                              }
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select a market';
                              }
                              return null;
                            },
                          ),
                        if (widget.marketId == null) const SizedBox(height: 16),

                        // Product selector
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Select Product',
                            border: OutlineInputBorder(),
                          ),
                          value: _selectedProductId,
                          items: products.map((product) {
                            return DropdownMenuItem<String>(
                              value: product['id'],
                              child: Text(product['name']),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedProductId = value;
                              _selectedPromotion = null;
                            });
                            _calculateTotal();
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a product';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Rest of your form elements
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _quantityController,
                                decoration: const InputDecoration(
                                  labelText: 'Quantity',
                                  prefixIcon: Icon(Icons.format_list_numbered),
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Required';
                                  final val = double.tryParse(v);
                                  if (val == null || val <= 0) {
                                    return 'Must be > 0';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _unitPriceController,
                                decoration: const InputDecoration(
                                  labelText: 'Unit Price',
                                  prefixIcon: Icon(Icons.attach_money),
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Required';
                                  final val = double.tryParse(v);
                                  if (val == null || val <= 0) {
                                    return 'Must be > 0';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_selectedProductId != null) ...[
                          const Text(
                            'Promotion (Optional)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<Promotion?>(
                            isExpanded: true,
                            decoration: const InputDecoration(
                              hintText: 'Select a promotion',
                              prefixIcon: Icon(Icons.discount),
                              border: OutlineInputBorder(),
                            ),
                            value: _selectedPromotion,
                            items: [
                              const DropdownMenuItem<Promotion?>(
                                value: null,
                                child: Text('-- None --'),
                              ),
                              ...applicablePromotions.map((promo) {
                                return DropdownMenuItem<Promotion?>(
                                  value: promo,
                                  child: Text(
                                    '${promo.name} (${promo.discountType == DiscountType.percentage ? '${promo.discountValue}%' : '\$${promo.discountValue.toStringAsFixed(2)}'})',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }),
                            ],
                            onChanged: (value) {
                              if (mounted) {
                                setState(() {
                                  _selectedPromotion = value;
                                  _calculateTotal();
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextFormField(
                          controller: _notesController,
                          decoration: const InputDecoration(
                            labelText: 'Notes (Optional)',
                            prefixIcon: Icon(Icons.note),
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 24),
                        Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Summary',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const Divider(),
                                if (_discountAmount > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4.0),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Subtotal:'),
                                        Text(
                                          '\$${(_totalAmount + _discountAmount).toStringAsFixed(2)}',
                                        ),
                                      ],
                                    ),
                                  ),
                                if (_discountAmount > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4.0),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Discount (${_selectedPromotion?.name ?? ''}):',
                                        ),
                                        Text(
                                          '-\$${_discountAmount.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            color: Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Total Amount:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '\$${_totalAmount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.save),
                          label: const Text('Record Sale'),
                          onPressed: _isLoading ? null : _recordSale,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
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
}
