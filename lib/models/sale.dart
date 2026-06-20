class Sale {
  final int? id;
  final int? customerId; // ربط بسجل الزبون لتتبع الديون
  final String invoiceNumber;
  final DateTime date;
  final String? customerName;
  final String? customerPhone;
  final double totalAmount;
  final double paidAmount;
  final String paymentMethod; // نقدي، دين، تحويل
  final String? note;

  Sale({
    this.id,
    this.customerId,
    required this.invoiceNumber,
    DateTime? date,
    this.customerName,
    this.customerPhone,
    required this.totalAmount,
    required this.paidAmount,
    this.paymentMethod = 'نقدي',
    this.note,
  }) : date = date ?? DateTime.now();

  double get remaining => totalAmount - paidAmount;
  bool get isFullyPaid => remaining <= 0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'invoice_number': invoiceNumber,
      'date': date.toIso8601String(),
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'total_amount': totalAmount,
      'paid_amount': paidAmount,
      'payment_method': paymentMethod,
      'note': note,
    };
  }

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id: map['id'] as int?,
      customerId: map['customer_id'] as int?,
      invoiceNumber: map['invoice_number'] as String,
      date: DateTime.parse(map['date'] as String),
      customerName: map['customer_name'] as String?,
      customerPhone: map['customer_phone'] as String?,
      totalAmount: (map['total_amount'] as num).toDouble(),
      paidAmount: (map['paid_amount'] as num).toDouble(),
      paymentMethod: map['payment_method'] as String? ?? 'نقدي',
      note: map['note'] as String?,
    );
  }
}

class SaleItem {
  final int? id;
  final int saleId;
  final int productId;
  final String productName; // نسخة عن الاسم وقت البيع (لو تغير المنتج لاحقاً)
  final double quantity;
  final double unitPrice; // سعر البيع وقت البيع
  final double unitCost; // سعر التكلفة وقت البيع (لحساب الربح بدقة)

  SaleItem({
    this.id,
    required this.saleId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.unitCost,
  });

  double get subtotal => quantity * unitPrice;
  double get profit => quantity * (unitPrice - unitCost);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sale_id': saleId,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'unit_cost': unitCost,
    };
  }

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      id: map['id'] as int?,
      saleId: map['sale_id'] as int,
      productId: map['product_id'] as int,
      productName: map['product_name'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      unitPrice: (map['unit_price'] as num).toDouble(),
      unitCost: (map['unit_cost'] as num).toDouble(),
    );
  }
}
