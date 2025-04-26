import 'package:equatable/equatable.dart';
import 'region.dart';

class Vendor extends Equatable {
  final String id;
  final String name;
  final String email;
  final String? regionId;
  final Region? region;
  final String? phone;
  final String? address;
  final bool isActive;
  final bool isManagement;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Vendor({
    required this.id,
    required this.name,
    required this.email,
    this.regionId,
    this.region,
    this.phone,
    this.address,
    this.isActive = true,
    this.isManagement = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Vendor.fromJson(Map<String, dynamic> json) {
    return Vendor(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      regionId: json['region_id'],
      region: json['region'] != null ? Region.fromJson(json['region']) : null,
      phone: json['phone'],
      address: json['address'],
      isActive: json['is_active'] ?? true,
      isManagement: json['is_management'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'region_id': regionId,
      'phone': phone,
      'address': address,
      'is_active': isActive,
      'is_management': isManagement,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Vendor copyWith({
    String? id,
    String? name,
    String? email,
    String? regionId,
    Region? region,
    String? phone,
    String? address,
    bool? isActive,
    bool? isManagement,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Vendor(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      regionId: regionId ?? this.regionId,
      region: region ?? this.region,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      isActive: isActive ?? this.isActive,
      isManagement: isManagement ?? this.isManagement,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    email,
    regionId,
    region,
    phone,
    address,
    isActive,
    isManagement,
    createdAt,
    updatedAt,
  ];
}
