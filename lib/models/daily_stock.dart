import 'package:equatable/equatable.dart';
import 'product.dart';
import 'vendor.dart';

class DailyStock extends Equatable {
  final String id;
  final String vendorId;
  final Vendor? vendor;
  final String productId;
  final Product? product;
  final DateTime date;
  final int quantityAssigned;
  final int quantitySold;
  final int quantityReturned;
  final int quantityDamaged;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DailyStock({
    required this.id,
    required this.vendorId,
    this.vendor,
    required this.productId,
    this.product,
    required this.date,
    required this.quantityAssigned,
    required this.quantitySold,
    required this.quantityReturned,
    required this.quantityDamaged,
    required this.createdAt,
    required this.updatedAt,
  });

  int get quantityRemaining =>
      quantityAssigned - (quantitySold + quantityReturned + quantityDamaged);

  factory DailyStock.fromJson(Map<String, dynamic> json) {
    return DailyStock(
      id: json['id'],
      vendorId: json['vendor_id'],
      vendor: json['vendor'] != null ? Vendor.fromJson(json['vendor']) : null,
      productId: json['product_id'],
      product:
          json['product'] != null ? Product.fromJson(json['product']) : null,
      date: DateTime.parse(json['date']),
      quantityAssigned: json['quantity_assigned'] ?? 0,
      quantitySold: json['quantity_sold'] ?? 0,
      quantityReturned: json['quantity_returned'] ?? 0,
      quantityDamaged: json['quantity_damaged'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    final data = {
      'id': id,
      'vendor_id': vendorId,
      'product_id': productId,
      'date': date.toIso8601String(),
      'quantity_assigned': quantityAssigned,
    };

    // Only include fields that are not 0, as they might not exist in the database
    if (quantitySold != 0) {
      data['quantity_sold'] = quantitySold;
    }

    if (quantityReturned != 0) {
      data['quantity_returned'] = quantityReturned;
    }

    if (quantityDamaged != 0) {
      data['quantity_damaged'] = quantityDamaged;
    }

    return data;
  }

  DailyStock copyWith({
    String? id,
    String? vendorId,
    Vendor? vendor,
    String? productId,
    Product? product,
    DateTime? date,
    int? quantityAssigned,
    int? quantitySold,
    int? quantityReturned,
    int? quantityDamaged,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DailyStock(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      vendor: vendor ?? this.vendor,
      productId: productId ?? this.productId,
      product: product ?? this.product,
      date: date ?? this.date,
      quantityAssigned: quantityAssigned ?? this.quantityAssigned,
      quantitySold: quantitySold ?? this.quantitySold,
      quantityReturned: quantityReturned ?? this.quantityReturned,
      quantityDamaged: quantityDamaged ?? this.quantityDamaged,
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
        date,
        quantityAssigned,
        quantitySold,
        quantityReturned,
        quantityDamaged,
        createdAt,
        updatedAt,
      ];
}
