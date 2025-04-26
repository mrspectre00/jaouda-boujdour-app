import 'package:equatable/equatable.dart';

enum DiscountType { percentage, fixedAmount }

extension DiscountTypeExtension on DiscountType {
  String get value {
    switch (this) {
      case DiscountType.percentage:
        return 'percentage';
      case DiscountType.fixedAmount:
        return 'fixed_amount';
    }
  }

  static DiscountType fromString(String? value) {
    switch (value) {
      case 'percentage':
        return DiscountType.percentage;
      case 'fixed_amount':
        return DiscountType.fixedAmount;
      default:
        return DiscountType.fixedAmount; // Default type
    }
  }
}

class Promotion extends Equatable {
  final String id;
  final String name;
  final String? description;
  final DiscountType discountType;
  final double discountValue;
  final String? productId; // Optional: Link to a specific product
  final String? productName; // Product name for display purposes
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Promotion({
    required this.id,
    required this.name,
    this.description,
    required this.discountType,
    required this.discountValue,
    this.productId,
    this.productName,
    this.startDate,
    this.endDate,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory Promotion.fromJson(Map<String, dynamic> json) {
    return Promotion(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown Promotion',
      description: json['description'] as String?,
      discountType: json['discount_type'] == 'percentage'
          ? DiscountType.percentage
          : DiscountType.fixedAmount,
      discountValue: (json['discount_value'] ?? 0.0).toDouble(),
      productId: json['product_id'],
      productName: json['product_name'],
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'])
          : null,
      endDate:
          json['end_date'] != null ? DateTime.parse(json['end_date']) : null,
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'discount_type': discountType.value,
      'discount_value': discountValue,
      'product_id': productId,
      'product_name': productName,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'is_active': isActive,
      // createdAt and updatedAt are usually handled by the database
    };
  }

  Promotion copyWith({
    String? id,
    String? name,
    String? description,
    DiscountType? discountType,
    double? discountValue,
    String? productId,
    String? productName,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Promotion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        discountType,
        discountValue,
        productId,
        productName,
        startDate,
        endDate,
        isActive,
        createdAt,
        updatedAt,
      ];
}
