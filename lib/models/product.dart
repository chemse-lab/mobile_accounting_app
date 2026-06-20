class Product {
  final int? id;
  final int typeId; // ينتمي لأي نوع
  final String name;
  final String unit; // وحدة البيع: قطعة، كيلو، علبة...
  final double purchasePrice; // سعر الشراء (التكلفة)
  final double salePrice; // سعر البيع
  final double quantity; // الكمية المتوفرة في المخزون
  final double minStock; // حد التنبيه لنقص المخزون
  final String? barcode;
  final DateTime createdAt;

  Product({
    this.id,
    required this.typeId,
    required this.name,
    this.unit = 'قطعة',
    required this.purchasePrice,
    required this.salePrice,
    this.quantity = 0,
    this.minStock = 5,
    this.barcode,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  double get profitPerUnit => salePrice - purchasePrice;
  bool get isLowStock => quantity <= minStock;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type_id': typeId,
      'name': name,
      'unit': unit,
      'purchase_price': purchasePrice,
      'sale_price': salePrice,
      'quantity': quantity,
      'min_stock': minStock,
      'barcode': barcode,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      typeId: map['type_id'] as int,
      name: map['name'] as String,
      unit: map['unit'] as String? ?? 'قطعة',
      purchasePrice: (map['purchase_price'] as num).toDouble(),
      salePrice: (map['sale_price'] as num).toDouble(),
      quantity: (map['quantity'] as num).toDouble(),
      minStock: (map['min_stock'] as num).toDouble(),
      barcode: map['barcode'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Product copyWith({
    int? id,
    int? typeId,
    String? name,
    String? unit,
    double? purchasePrice,
    double? salePrice,
    double? quantity,
    double? minStock,
    String? barcode,
  }) {
    return Product(
      id: id ?? this.id,
      typeId: typeId ?? this.typeId,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      salePrice: salePrice ?? this.salePrice,
      quantity: quantity ?? this.quantity,
      minStock: minStock ?? this.minStock,
      barcode: barcode ?? this.barcode,
      createdAt: createdAt,
    );
  }
}
