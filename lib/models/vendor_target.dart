import 'package:equatable/equatable.dart';
import 'product.dart';
import 'vendor.dart';

enum TargetType {
  units,
  revenue,
}

extension TargetTypeExtension on TargetType {
  String toJson() => toString().split('.').last;

  static TargetType fromJson(String json) {
    return TargetType.values.firstWhere(
      (type) => type.toString().split('.').last == json,
      orElse: () => TargetType.units,
    );
  }

  String get displayName {
    switch (this) {
      case TargetType.units:
        return 'Units';
      case TargetType.revenue:
        return 'Revenue';
    }
  }
}

class VendorTarget extends Equatable {
  final String id;
  final String vendorId;
  final String targetName;
  final String? targetDescription;
  final DateTime startDate;
  final DateTime endDate;
  final TargetType targetType;
  final double targetValue;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? productId;

  // Non-database fields for UI display
  final Vendor? vendor;
  final Product? product;
  final double? achievedValue;
  final double? progressPercentage;

  const VendorTarget({
    required this.id,
    required this.vendorId,
    required this.targetName,
    this.targetDescription,
    required this.startDate,
    required this.endDate,
    required this.targetType,
    required this.targetValue,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.productId,
    this.vendor,
    this.product,
    this.achievedValue,
    this.progressPercentage,
  });

  factory VendorTarget.fromJson(Map<String, dynamic> json) {
    return VendorTarget(
      id: json['id'],
      vendorId: json['vendor_id'],
      targetName: json['target_name'],
      targetDescription: json['target_description'],
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      targetType: TargetTypeExtension.fromJson(json['target_type']),
      targetValue: double.parse(json['target_value'].toString()),
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      createdBy: json['created_by'],
      productId: json['product_id'],
      vendor: json['vendor'] != null ? Vendor.fromJson(json['vendor']) : null,
      product:
          json['product'] != null ? Product.fromJson(json['product']) : null,
      achievedValue: json['achieved_value'] != null
          ? double.parse(json['achieved_value'].toString())
          : null,
      progressPercentage: json['progress_percentage'] != null
          ? double.parse(json['progress_percentage'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vendor_id': vendorId,
      'target_name': targetName,
      'target_description': targetDescription,
      'start_date': startDate.toIso8601String().split('T')[0],
      'end_date': endDate.toIso8601String().split('T')[0],
      'target_type': targetType.toJson(),
      'target_value': targetValue,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'created_by': createdBy,
      'product_id': productId,
    };
  }

  VendorTarget copyWith({
    String? id,
    String? vendorId,
    String? targetName,
    String? targetDescription,
    DateTime? startDate,
    DateTime? endDate,
    TargetType? targetType,
    double? targetValue,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? productId,
    Vendor? vendor,
    Product? product,
    double? achievedValue,
    double? progressPercentage,
  }) {
    return VendorTarget(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      targetName: targetName ?? this.targetName,
      targetDescription: targetDescription ?? this.targetDescription,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      targetType: targetType ?? this.targetType,
      targetValue: targetValue ?? this.targetValue,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      productId: productId ?? this.productId,
      vendor: vendor ?? this.vendor,
      product: product ?? this.product,
      achievedValue: achievedValue ?? this.achievedValue,
      progressPercentage: progressPercentage ?? this.progressPercentage,
    );
  }

  String get formattedDateRange {
    final startFormatted =
        '${startDate.day}/${startDate.month}/${startDate.year}';
    final endFormatted = '${endDate.day}/${endDate.month}/${endDate.year}';
    return '$startFormatted - $endFormatted';
  }

  bool get isCurrentlyActive {
    final now = DateTime.now();
    return isActive && startDate.isBefore(now) && endDate.isAfter(now);
  }

  String get formattedTargetValue {
    return targetType == TargetType.units
        ? targetValue.toStringAsFixed(0)
        : 'MAD ${targetValue.toStringAsFixed(2)}';
  }

  String get formattedProgress {
    if (achievedValue == null || progressPercentage == null) {
      return 'Unknown';
    }

    final achievedFormatted = targetType == TargetType.units
        ? achievedValue!.toStringAsFixed(0)
        : 'MAD ${achievedValue!.toStringAsFixed(2)}';

    return '$achievedFormatted (${progressPercentage!.toStringAsFixed(1)}%)';
  }

  @override
  List<Object?> get props => [
        id,
        vendorId,
        targetName,
        targetDescription,
        startDate,
        endDate,
        targetType,
        targetValue,
        isActive,
        createdAt,
        updatedAt,
        createdBy,
        productId,
        achievedValue,
        progressPercentage
      ];
}
