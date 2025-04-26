import 'package:equatable/equatable.dart';

class Region extends Equatable {
  final String id;
  final String name;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Region({
    required this.id,
    required this.name,
    this.createdAt,
    this.updatedAt,
  });

  factory Region.fromJson(Map<String, dynamic> json) {
    return Region(
      id: json['id'],
      name: json['name'],
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
    return {'id': id, 'name': name};
  }

  Region copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Region(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, name, createdAt, updatedAt];
}
