import 'package:flutter/foundation.dart';
import 'package:equatable/equatable.dart';

@immutable
class Sale extends Equatable {
  final String id;
  final String marketId;
  final String productId;
  final String productName;
  final String marketName;
  final double quantity;
  final double unitPrice;
  final double total;
  final DateTime createdAt;
  final String? notes;
  final String? promotionId;
  final double? discount;
  final String? paymentMethod;

  const Sale({
    required this.id,
    required this.marketId,
    required this.productId,
    required this.productName,
    required this.marketName,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    required this.createdAt,
    this.notes,
    this.promotionId,
    this.discount,
    this.paymentMethod,
  });

  factory Sale.fromMap(Map<String, dynamic> map) {
    // Handle different data structures based on join queries vs direct queries
    String? productName;
    String? marketName;

    // Handle nested product object
    if (map['products'] != null) {
      productName = map['products']['name'] as String?;
    } else {
      productName = map['product_name'] as String?;
    }

    // Handle nested market object
    if (map['markets'] != null) {
      marketName = map['markets']['name'] as String?;
    } else {
      marketName = map['market_name'] as String?;
    }

    return Sale(
      id: map['id'] as String,
      marketId: map['market_id'] as String,
      productId: map['product_id'] as String,
      productName: productName ?? 'Unknown Product',
      marketName: marketName ?? 'Unknown Market',
      quantity: (map['quantity'] as num).toDouble(),
      unitPrice: (map['unit_price'] as num).toDouble(),
      total: (map['total'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
      notes: map['notes'] as String?,
      promotionId: map['promotion_id'] as String?,
      discount:
          map['discount'] != null ? (map['discount'] as num).toDouble() : null,
      paymentMethod: map['payment_method'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'market_id': marketId,
      'product_id': productId,
      'product_name': productName,
      'market_name': marketName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total': total,
      'created_at': createdAt.toIso8601String(),
      'notes': notes,
      'promotion_id': promotionId,
      'discount': discount,
      'payment_method': paymentMethod,
    };
  }

  @override
  List<Object?> get props => [
    id,
    marketId,
    productId,
    productName,
    marketName,
    quantity,
    unitPrice,
    total,
    createdAt,
    notes,
    promotionId,
    discount,
    paymentMethod,
  ];
}

class SaleItem {
  final String id;
  final String salesRecordId;
  final String productId;
  final int quantity;
  final double unitPrice;
  final DateTime createdAt;
  final DateTime updatedAt;

  SaleItem({
    required this.id,
    required this.salesRecordId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SaleItem.fromJson(Map<String, dynamic> json) {
    return SaleItem(
      id: json['id'],
      salesRecordId: json['sales_record_id'],
      productId: json['product_id'],
      quantity: json['quantity'],
      unitPrice: (json['unit_price'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sales_record_id': salesRecordId,
      'product_id': productId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
