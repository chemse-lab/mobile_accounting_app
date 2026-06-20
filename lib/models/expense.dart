class Expense {
  final int? id;
  final DateTime date;
  final String category; // وقود، صيانة، إيجار، أخرى...
  final double amount;
  final String? note;

  Expense({
    this.id,
    DateTime? date,
    required this.category,
    required this.amount,
    this.note,
  }) : date = date ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'category': category,
      'amount': amount,
      'note': note,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as int?,
      date: DateTime.parse(map['date'] as String),
      category: map['category'] as String,
      amount: (map['amount'] as num).toDouble(),
      note: map['note'] as String?,
    );
  }
}

// تصنيفات المصاريف الجاهزة للبائع المتنقل
const List<String> expenseCategories = [
  'وقود',
  'صيانة المركبة',
  'إيجار موقف/سوق',
  'أكل وشرب',
  'شراء بضاعة',
  'اتصالات',
  'أخرى',
];
