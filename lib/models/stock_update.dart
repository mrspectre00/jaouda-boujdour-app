import 'package:equatable/equatable.dart';
import 'product.dart';

enum StockUpdateType { in_, out, adjustment, purchase, removal }

class StockUpdate extends Equatable {
  final String id;
  final Product product;
  final int quantityChange;
  final int previousQuantity;
  final int newQuantity;
  final StockUpdateType updateType;
  final String? notes;
  final String? createdBy;
  final DateTime createdAt;

  const StockUpdate({
    required this.id,
    required this.product,
    required this.quantityChange,
    required this.previousQuantity,
    required this.newQuantity,
    required this.updateType,
    this.notes,
    this.createdBy,
    required this.createdAt,
  });

  factory StockUpdate.fromJson(Map<String, dynamic> json) {
    return StockUpdate(
      id: json['id'] as String,
      product: Product.fromJson(json['product'] as Map<String, dynamic>),
      quantityChange: json['quantity_change'] as int,
      previousQuantity: json['previous_quantity'] as int,
      newQuantity: json['new_quantity'] as int,
      updateType: StockUpdateType.values.firstWhere(
        (e) => e.toString().split('.').last == json['update_type'],
        orElse: () => StockUpdateType.adjustment,
      ),
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': product.id,
      'quantity_change': quantityChange,
      'previous_quantity': previousQuantity,
      'new_quantity': newQuantity,
      'update_type': updateType.toString().split('.').last,
      'notes': notes,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        product,
        quantityChange,
        previousQuantity,
        newQuantity,
        updateType,
        notes,
        createdBy,
        createdAt,
      ];
}
