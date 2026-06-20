class ProductType {
  final int? id;
  final int branchId; // ينتمي لأي فرع
  final String name; // اسم النوع (مثال: قمصان، بناطيل)
  final DateTime createdAt;

  ProductType({
    this.id,
    required this.branchId,
    required this.name,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'branch_id': branchId,
      'name': name,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ProductType.fromMap(Map<String, dynamic> map) {
    return ProductType(
      id: map['id'] as int?,
      branchId: map['branch_id'] as int,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  ProductType copyWith({int? id, int? branchId, String? name}) {
    return ProductType(
      id: id ?? this.id,
      branchId: branchId ?? this.branchId,
      name: name ?? this.name,
      createdAt: createdAt,
    );
  }
}
