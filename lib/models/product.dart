import 'package:flutter/foundation.dart';
import 'package:equatable/equatable.dart';

@immutable
class Product extends Equatable {
  final String id;
  final String name;
  final String? description;
  final double unitPrice;
  final String? category;
  final String? imageUrl;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? stockQuantity;

  const Product({
    required this.id,
    required this.name,
    this.description,
    required this.unitPrice,
    this.category,
    this.imageUrl,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.stockQuantity,
  });

  // Add a getter for the price for backward compatibility
  double get price => unitPrice;

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      unitPrice: json['unit_price'] != null
          ? (json['unit_price'] as num).toDouble()
          : 0.0,
      category: json['category'] as String?,
      imageUrl: json['image_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      stockQuantity: json['stock_quantity'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    // Only include image_url if it's not null to avoid database errors
    final result = {
      'id': id,
      'name': name,
      'description': description,
      'unit_price': unitPrice,
      'category': category,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'stock_quantity': stockQuantity,
    };

    // Only add image_url if it's not null
    if (imageUrl != null) {
      result['image_url'] = imageUrl;
    }

    return result;
  }

  Product copyWith({
    String? id,
    String? name,
    String? description,
    double? unitPrice,
    String? category,
    String? imageUrl,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? stockQuantity,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      unitPrice: unitPrice ?? this.unitPrice,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      stockQuantity: stockQuantity ?? this.stockQuantity,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        unitPrice,
        category,
        imageUrl,
        isActive,
        createdAt,
        updatedAt,
        stockQuantity,
      ];

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Product &&
        other.id == id &&
        other.name == name &&
        other.description == description &&
        other.unitPrice == unitPrice &&
        other.category == category &&
        other.imageUrl == imageUrl &&
        other.isActive == isActive &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.stockQuantity == stockQuantity;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        description.hashCode ^
        unitPrice.hashCode ^
        category.hashCode ^
        imageUrl.hashCode ^
        isActive.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode ^
        stockQuantity.hashCode;
  }

  @override
  String toString() {
    return 'Product(id: $id, name: $name, price: $unitPrice)';
  }
}
