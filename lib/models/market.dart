import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';
import 'region.dart';
import 'package:flutter/foundation.dart';

enum MarketStatus { toVisit, visited, closed, noNeed, saleMade }

extension MarketStatusExtension on MarketStatus {
  String get value => toString().split('.').last;

  static MarketStatus fromString(String value) {
    return MarketStatus.values.firstWhere(
      (e) => e.toString().split('.').last == value,
      orElse: () => MarketStatus.toVisit,
    );
  }
}

@immutable
class Market extends Equatable {
  final String id;
  final String name;
  final String? address;
  final double? latitude;
  final double? longitude;
  final MarketStatus status;
  final DateTime? lastVisit;
  final double? salesAmount;
  final int? productsSold;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? notes;
  final List<String> assignedProducts;
  final DateTime? visitDate;
  final Region? region;

  const Market({
    required this.id,
    required this.name,
    this.address,
    this.latitude,
    this.longitude,
    this.status = MarketStatus.toVisit,
    this.lastVisit,
    this.salesAmount,
    this.productsSold,
    this.createdAt,
    this.updatedAt,
    this.notes,
    this.assignedProducts = const [],
    this.visitDate,
    this.region,
  });

  // Add a getter for the location
  LatLng get location => LatLng(latitude ?? 0, longitude ?? 0);

  factory Market.fromJson(Map<String, dynamic> json) {
    return Market(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String?,
      latitude: json['latitude'] as double?,
      longitude: json['longitude'] as double?,
      status: MarketStatusExtension.fromString(
        json['status'] as String? ?? 'toVisit',
      ),
      lastVisit:
          json['lastVisit'] == null
              ? null
              : DateTime.parse(json['lastVisit'] as String),
      salesAmount: json['salesAmount'] as double?,
      productsSold: json['productsSold'] as int?,
      createdAt:
          json['createdAt'] == null
              ? null
              : DateTime.parse(json['createdAt'] as String),
      updatedAt:
          json['updatedAt'] == null
              ? null
              : DateTime.parse(json['updatedAt'] as String),
      notes: json['notes'] as String?,
      assignedProducts:
          (json['assignedProducts'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      visitDate:
          json['visitDate'] == null
              ? null
              : DateTime.parse(json['visitDate'] as String),
      region:
          json['region'] == null
              ? null
              : Region.fromJson(json['region'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'status': status.value,
      'lastVisit': lastVisit?.toIso8601String(),
      'salesAmount': salesAmount,
      'productsSold': productsSold,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'notes': notes,
      'assignedProducts': assignedProducts,
      'visitDate': visitDate?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
    id,
    name,
    address,
    latitude,
    longitude,
    status,
    lastVisit,
    salesAmount,
    productsSold,
    createdAt,
    updatedAt,
    notes,
    assignedProducts,
    visitDate,
    region,
  ];

  Market copyWith({
    String? id,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    MarketStatus? status,
    DateTime? lastVisit,
    double? salesAmount,
    int? productsSold,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? notes,
    List<String>? assignedProducts,
    DateTime? visitDate,
    Region? region,
  }) {
    return Market(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      status: status ?? this.status,
      lastVisit: lastVisit ?? this.lastVisit,
      salesAmount: salesAmount ?? this.salesAmount,
      productsSold: productsSold ?? this.productsSold,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      notes: notes ?? this.notes,
      assignedProducts: assignedProducts ?? this.assignedProducts,
      visitDate: visitDate ?? this.visitDate,
      region: region ?? this.region,
    );
  }
}

@immutable
class MarketLocation {
  final double latitude;
  final double longitude;

  const MarketLocation({required this.latitude, required this.longitude});

  factory MarketLocation.fromMap(Map<String, dynamic> map) {
    return MarketLocation(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'latitude': latitude, 'longitude': longitude};
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is MarketLocation &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;

  @override
  String toString() => 'MarketLocation(lat: $latitude, lng: $longitude)';
}
