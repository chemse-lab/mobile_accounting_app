class Customer {
  final int? id;
  final String name;
  final String? phone;
  final DateTime createdAt;

  Customer({
    this.id,
    required this.name,
    this.phone,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as int?,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

/// دفعة سداد من الزبون (تسديد جزء أو كل الدين)
class CustomerPayment {
  final int? id;
  final int customerId;
  final int? saleId; // الفاتورة المرتبطة إن وجدت
  final double amount;
  final DateTime date;
  final String? note;

  CustomerPayment({
    this.id,
    required this.customerId,
    this.saleId,
    required this.amount,
    DateTime? date,
    this.note,
  }) : date = date ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'sale_id': saleId,
      'amount': amount,
      'date': date.toIso8601String(),
      'note': note,
    };
  }

  factory CustomerPayment.fromMap(Map<String, dynamic> map) {
    return CustomerPayment(
      id: map['id'] as int?,
      customerId: map['customer_id'] as int,
      saleId: map['sale_id'] as int?,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      note: map['note'] as String?,
    );
  }
}
