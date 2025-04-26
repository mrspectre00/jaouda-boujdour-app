import 'package:equatable/equatable.dart';
import 'product.dart';

class Stock extends Equatable {
  final String id;
  final String productId;
  final int quantity;
  final Product product;
  final String vendorId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Stock({
    required this.id,
    required this.productId,
    required this.quantity,
    required this.product,
    required this.vendorId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Stock.fromJson(Map<String, dynamic> json) {
    return Stock(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      quantity: json['quantity'] as int,
      product: Product.fromJson(json['product'] as Map<String, dynamic>),
      vendorId: json['vendor_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'quantity': quantity,
      'product': product.toJson(),
      'vendor_id': vendorId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Stock copyWith({
    String? id,
    String? productId,
    int? quantity,
    Product? product,
    String? vendorId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Stock(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      product: product ?? this.product,
      vendorId: vendorId ?? this.vendorId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props =>
      [id, productId, quantity, product, vendorId, createdAt, updatedAt];
}
