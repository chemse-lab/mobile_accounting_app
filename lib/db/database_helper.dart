import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/branch.dart';
import '../models/product_type.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/expense.dart';
import '../models/customer.dart';

class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    // على سطح المكتب (Windows/Linux/macOS) نستخدم sqflite_common_ffi
    // على Android/iOS نستخدم sqflite العادي مباشرة
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'mobile_accounting.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE branches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE product_types (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        branch_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (branch_id) REFERENCES branches (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        unit TEXT NOT NULL DEFAULT 'قطعة',
        purchase_price REAL NOT NULL,
        sale_price REAL NOT NULL,
        quantity REAL NOT NULL DEFAULT 0,
        min_stock REAL NOT NULL DEFAULT 5,
        barcode TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (type_id) REFERENCES product_types (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE customer_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        sale_id INTEGER,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER,
        invoice_number TEXT NOT NULL,
        date TEXT NOT NULL,
        customer_name TEXT,
        customer_phone TEXT,
        total_amount REAL NOT NULL,
        paid_amount REAL NOT NULL,
        payment_method TEXT NOT NULL DEFAULT 'نقدي',
        note TEXT,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        unit_cost REAL NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        note TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    // فروع افتراضية يمكن للمستخدم تعديلها
    await db.insert('branches', {
      'name': 'الفرع الأول',
      'description': null,
      'created_at': DateTime.now().toIso8601String(),
    });
    await db.insert('branches', {
      'name': 'الفرع الثاني',
      'description': null,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<String> getDbPath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, 'mobile_accounting.db');
  }

  Future<void> closeDb() async {
    await _db?.close();
    _db = null;
  }

  // ---------------- Branches ----------------
  Future<int> insertBranch(Branch b) async {
    final db = await database;
    return db.insert('branches', b.toMap());
  }

  Future<List<Branch>> getBranches() async {
    final db = await database;
    final rows = await db.query('branches', orderBy: 'id ASC');
    return rows.map((e) => Branch.fromMap(e)).toList();
  }

  Future<int> updateBranch(Branch b) async {
    final db = await database;
    return db.update('branches', b.toMap(), where: 'id = ?', whereArgs: [b.id]);
  }

  Future<int> deleteBranch(int id) async {
    final db = await database;
    return db.delete('branches', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------- Product Types ----------------
  Future<int> insertProductType(ProductType t) async {
    final db = await database;
    return db.insert('product_types', t.toMap());
  }

  Future<List<ProductType>> getTypesByBranch(int branchId) async {
    final db = await database;
    final rows = await db.query('product_types',
        where: 'branch_id = ?', whereArgs: [branchId], orderBy: 'id ASC');
    return rows.map((e) => ProductType.fromMap(e)).toList();
  }

  Future<int> updateProductType(ProductType t) async {
    final db = await database;
    return db.update('product_types', t.toMap(), where: 'id = ?', whereArgs: [t.id]);
  }

  Future<int> deleteProductType(int id) async {
    final db = await database;
    return db.delete('product_types', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------- Products ----------------
  Future<int> insertProduct(Product p) async {
    final db = await database;
    return db.insert('products', p.toMap());
  }

  Future<List<Product>> getProductsByType(int typeId) async {
    final db = await database;
    final rows = await db.query('products',
        where: 'type_id = ?', whereArgs: [typeId], orderBy: 'name ASC');
    return rows.map((e) => Product.fromMap(e)).toList();
  }

  Future<List<Product>> getAllProducts() async {
    final db = await database;
    final rows = await db.query('products', orderBy: 'name ASC');
    return rows.map((e) => Product.fromMap(e)).toList();
  }

  Future<List<Product>> getLowStockProducts() async {
    final all = await getAllProducts();
    return all.where((p) => p.isLowStock).toList();
  }

  Future<int> updateProduct(Product p) async {
    final db = await database;
    return db.update('products', p.toMap(), where: 'id = ?', whereArgs: [p.id]);
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    return db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> adjustProductStock(int productId, double deltaQty) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE products SET quantity = quantity + ? WHERE id = ?',
      [deltaQty, productId],
    );
  }

  // ---------------- Sales ----------------
  Future<int> insertSale(Sale sale, List<SaleItem> items) async {
    final db = await database;
    return db.transaction((txn) async {
      final saleId = await txn.insert('sales', sale.toMap());
      for (final item in items) {
        await txn.insert('sale_items', {
          ...item.toMap(),
          'sale_id': saleId,
        });
        // خصم الكمية المباعة من المخزون
        await txn.rawUpdate(
          'UPDATE products SET quantity = quantity - ? WHERE id = ?',
          [item.quantity, item.productId],
        );
      }
      return saleId;
    });
  }

  Future<List<Sale>> getSales({DateTime? from, DateTime? to}) async {
    final db = await database;
    String? where;
    List<Object?>? whereArgs;
    if (from != null && to != null) {
      where = 'date >= ? AND date <= ?';
      whereArgs = [from.toIso8601String(), to.toIso8601String()];
    }
    final rows = await db.query('sales',
        where: where, whereArgs: whereArgs, orderBy: 'date DESC');
    return rows.map((e) => Sale.fromMap(e)).toList();
  }

  Future<List<SaleItem>> getSaleItems(int saleId) async {
    final db = await database;
    final rows =
        await db.query('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);
    return rows.map((e) => SaleItem.fromMap(e)).toList();
  }

  Future<int> deleteSale(int saleId) async {
    final db = await database;
    // إرجاع الكميات للمخزون قبل الحذف
    final items = await getSaleItems(saleId);
    for (final item in items) {
      await adjustProductStock(item.productId, item.quantity);
    }
    await db.delete('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);
    return db.delete('sales', where: 'id = ?', whereArgs: [saleId]);
  }

  Future<String> generateInvoiceNumber() async {
    final db = await database;
    final count = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM sales')) ??
        0;
    final now = DateTime.now();
    return 'INV-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${(count + 1).toString().padLeft(4, '0')}';
  }

  // ---------------- Expenses ----------------
  Future<int> insertExpense(Expense e) async {
    final db = await database;
    return db.insert('expenses', e.toMap());
  }

  Future<List<Expense>> getExpenses({DateTime? from, DateTime? to}) async {
    final db = await database;
    String? where;
    List<Object?>? whereArgs;
    if (from != null && to != null) {
      where = 'date >= ? AND date <= ?';
      whereArgs = [from.toIso8601String(), to.toIso8601String()];
    }
    final rows = await db.query('expenses',
        where: where, whereArgs: whereArgs, orderBy: 'date DESC');
    return rows.map((e) => Expense.fromMap(e)).toList();
  }

  Future<int> deleteExpense(int id) async {
    final db = await database;
    return db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------- Settings ----------------
  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert('settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  // ---------------- Customers & Debts ----------------
  Future<int> insertCustomer(Customer c) async {
    final db = await database;
    return db.insert('customers', c.toMap());
  }

  Future<Customer?> findCustomerByName(String name) async {
    final db = await database;
    final rows = await db.query('customers', where: 'name = ?', whereArgs: [name]);
    if (rows.isEmpty) return null;
    return Customer.fromMap(rows.first);
  }

  /// يبحث عن زبون بنفس الاسم أو ينشئ واحداً جديداً، ويُعيد المعرّف
  Future<int> findOrCreateCustomer(String name, {String? phone}) async {
    final existing = await findCustomerByName(name);
    if (existing != null) return existing.id!;
    return insertCustomer(Customer(name: name, phone: phone));
  }

  Future<List<Customer>> getCustomers() async {
    final db = await database;
    final rows = await db.query('customers', orderBy: 'name ASC');
    return rows.map((e) => Customer.fromMap(e)).toList();
  }

  Future<int> deleteCustomer(int id) async {
    final db = await database;
    return db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertCustomerPayment(CustomerPayment payment) async {
    final db = await database;
    return db.insert('customer_payments', payment.toMap());
  }

  Future<List<CustomerPayment>> getCustomerPayments(int customerId) async {
    final db = await database;
    final rows = await db.query('customer_payments',
        where: 'customer_id = ?', whereArgs: [customerId], orderBy: 'date DESC');
    return rows.map((e) => CustomerPayment.fromMap(e)).toList();
  }

  /// إجمالي الدين على زبون = (مجموع فواتيره غير المسددة بالكامل) - (مجموع دفعاته الإضافية)
  Future<double> getCustomerDebt(int customerId) async {
    final db = await database;
    final salesRows = await db.rawQuery('''
      SELECT SUM(total_amount - paid_amount) as debt
      FROM sales WHERE customer_id = ?
    ''', [customerId]);
    final saleDebt = (salesRows.first['debt'] as num?)?.toDouble() ?? 0;

    final paymentsRows = await db.rawQuery('''
      SELECT SUM(amount) as paid
      FROM customer_payments WHERE customer_id = ? AND sale_id IS NULL
    ''', [customerId]);
    final extraPaid = (paymentsRows.first['paid'] as num?)?.toDouble() ?? 0;

    return saleDebt - extraPaid;
  }

  /// قائمة كل الزبائن مع دينهم الحالي (فقط من لديهم دين أكبر من صفر إن طلب ذلك)
  Future<List<Map<String, dynamic>>> getCustomersWithDebt({bool onlyWithDebt = false}) async {
    final customers = await getCustomers();
    final List<Map<String, dynamic>> result = [];
    for (final c in customers) {
      final debt = await getCustomerDebt(c.id!);
      if (!onlyWithDebt || debt > 0) {
        result.add({'customer': c, 'debt': debt});
      }
    }
    result.sort((a, b) => (b['debt'] as double).compareTo(a['debt'] as double));
    return result;
  }

  /// تسجيل دفعة سداد عامة (تُخفض الدين الكلي للزبون دون ربطها بفاتورة محددة)
  Future<void> recordDebtPayment(int customerId, double amount, {String? note}) async {
    await insertCustomerPayment(CustomerPayment(
      customerId: customerId,
      amount: amount,
      note: note,
    ));
  }

  // ---------------- Reports / Aggregates ----------------

  /// إجمالي المبيعات والأرباح والمصاريف ضمن فترة، مع تفصيل حسب الفرع والنوع
  Future<Map<String, dynamic>> getSummary({
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await database;

    final salesRows = await db.rawQuery('''
      SELECT s.id, s.total_amount, s.date
      FROM sales s
      WHERE s.date >= ? AND s.date <= ?
    ''', [from.toIso8601String(), to.toIso8601String()]);

    double totalSales = 0;
    for (final r in salesRows) {
      totalSales += (r['total_amount'] as num).toDouble();
    }

    final profitRows = await db.rawQuery('''
      SELECT SUM((si.unit_price - si.unit_cost) * si.quantity) as total_profit
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.id
      WHERE s.date >= ? AND s.date <= ?
    ''', [from.toIso8601String(), to.toIso8601String()]);
    final totalProfit = (profitRows.first['total_profit'] as num?)?.toDouble() ?? 0;

    final expenseRows = await db.rawQuery('''
      SELECT SUM(amount) as total_expenses
      FROM expenses
      WHERE date >= ? AND date <= ?
    ''', [from.toIso8601String(), to.toIso8601String()]);
    final totalExpenses =
        (expenseRows.first['total_expenses'] as num?)?.toDouble() ?? 0;

    // تفصيل حسب الفرع
    final branchRows = await db.rawQuery('''
      SELECT b.name as branch_name,
             SUM(si.quantity * si.unit_price) as total_sales,
             SUM((si.unit_price - si.unit_cost) * si.quantity) as total_profit
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.id
      JOIN products p ON si.product_id = p.id
      JOIN product_types pt ON p.type_id = pt.id
      JOIN branches b ON pt.branch_id = b.id
      WHERE s.date >= ? AND s.date <= ?
      GROUP BY b.id
    ''', [from.toIso8601String(), to.toIso8601String()]);

    // تفصيل حسب النوع
    final typeRows = await db.rawQuery('''
      SELECT pt.name as type_name, b.name as branch_name,
             SUM(si.quantity * si.unit_price) as total_sales,
             SUM((si.unit_price - si.unit_cost) * si.quantity) as total_profit,
             SUM(si.quantity) as total_qty
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.id
      JOIN products p ON si.product_id = p.id
      JOIN product_types pt ON p.type_id = pt.id
      JOIN branches b ON pt.branch_id = b.id
      WHERE s.date >= ? AND s.date <= ?
      GROUP BY pt.id
      ORDER BY total_sales DESC
    ''', [from.toIso8601String(), to.toIso8601String()]);

    return {
      'total_sales': totalSales,
      'total_profit': totalProfit,
      'total_expenses': totalExpenses,
      'net_profit': totalProfit - totalExpenses,
      'by_branch': branchRows,
      'by_type': typeRows,
      'sales_count': salesRows.length,
    };
  }
}
