import 'package:equatable/equatable.dart';
import 'market.dart';
import 'product.dart';
import 'vendor.dart';

class SpoiledStock extends Equatable {
  final String id;
  final String vendorId;
  final Vendor? vendor;
  final String productId;
  final Product? product;
  final int quantity;
  final String? marketId;
  final Market? market;
  final String? reason;
  final DateTime date;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SpoiledStock({
    required this.id,
    required this.vendorId,
    this.vendor,
    required this.productId,
    this.product,
    required this.quantity,
    this.marketId,
    this.market,
    this.reason,
    required this.date,
    this.createdAt,
    this.updatedAt,
  });

  factory SpoiledStock.fromJson(Map<String, dynamic> json) {
    return SpoiledStock(
      id: json['id'],
      vendorId: json['vendor_id'],
      vendor: json['vendors'] != null ? Vendor.fromJson(json['vendors']) : null,
      productId: json['product_id'],
      product:
          json['products'] != null ? Product.fromJson(json['products']) : null,
      quantity: json['quantity'],
      marketId: json['market_id'],
      market: json['markets'] != null ? Market.fromJson(json['markets']) : null,
      reason: json['reason'],
      date: DateTime.parse(json['date']),
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : null,
      updatedAt:
          json['updated_at'] != null
              ? DateTime.parse(json['updated_at'])
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vendor_id': vendorId,
      'product_id': productId,
      'quantity': quantity,
      'market_id': marketId,
      'reason': reason,
      'date': date.toIso8601String(),
    };
  }

  SpoiledStock copyWith({
    String? id,
    String? vendorId,
    Vendor? vendor,
    String? productId,
    Product? product,
    int? quantity,
    String? marketId,
    Market? market,
    String? reason,
    DateTime? date,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SpoiledStock(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      vendor: vendor ?? this.vendor,
      productId: productId ?? this.productId,
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      marketId: marketId ?? this.marketId,
      market: market ?? this.market,
      reason: reason ?? this.reason,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    vendorId,
    vendor,
    productId,
    product,
    quantity,
    marketId,
    market,
    reason,
    date,
    createdAt,
    updatedAt,
  ];
}
