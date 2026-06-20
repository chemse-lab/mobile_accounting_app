import 'package:flutter/foundation.dart';
import '../db/database_helper.dart';
import '../models/branch.dart';
import '../models/product_type.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/expense.dart';

class AppState extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  List<Branch> branches = [];
  Map<int, List<ProductType>> typesByBranch = {};
  Map<int, List<Product>> productsByType = {};

  String shopName = 'متجري المتنقل';
  String shopPhone = '';

  Future<void> loadInitialData() async {
    branches = await _db.getBranches();
    for (final b in branches) {
      typesByBranch[b.id!] = await _db.getTypesByBranch(b.id!);
      for (final t in typesByBranch[b.id!]!) {
        productsByType[t.id!] = await _db.getProductsByType(t.id!);
      }
    }
    shopName = await _db.getSetting('shop_name') ?? shopName;
    shopPhone = await _db.getSetting('shop_phone') ?? '';
    notifyListeners();
  }

  // ---------------- Branches ----------------
  Future<void> addBranch(String name, {String? description}) async {
    await _db.insertBranch(Branch(name: name, description: description));
    await loadInitialData();
  }

  Future<void> renameBranch(Branch branch, String newName) async {
    await _db.updateBranch(branch.copyWith(name: newName));
    await loadInitialData();
  }

  Future<void> deleteBranch(int id) async {
    await _db.deleteBranch(id);
    await loadInitialData();
  }

  // ---------------- Types ----------------
  Future<void> addType(int branchId, String name) async {
    await _db.insertProductType(ProductType(branchId: branchId, name: name));
    await loadInitialData();
  }

  Future<void> renameType(ProductType type, String newName) async {
    await _db.updateProductType(type.copyWith(name: newName));
    await loadInitialData();
  }

  Future<void> deleteType(int id) async {
    await _db.deleteProductType(id);
    await loadInitialData();
  }

  // ---------------- Products ----------------
  Future<void> addProduct(Product product) async {
    await _db.insertProduct(product);
    await loadInitialData();
  }

  Future<void> updateProduct(Product product) async {
    await _db.updateProduct(product);
    await loadInitialData();
  }

  Future<void> deleteProduct(int id) async {
    await _db.deleteProduct(id);
    await loadInitialData();
  }

  List<Product> get allProducts =>
      productsByType.values.expand((list) => list).toList();

  List<Product> get lowStockProducts =>
      allProducts.where((p) => p.isLowStock).toList();

  // ---------------- Settings ----------------
  Future<void> updateShopInfo({String? name, String? phone}) async {
    if (name != null) {
      shopName = name;
      await _db.setSetting('shop_name', name);
    }
    if (phone != null) {
      shopPhone = phone;
      await _db.setSetting('shop_phone', phone);
    }
    notifyListeners();
  }

  // ---------------- Sales (delegated, no caching needed) ----------------
  Future<String> nextInvoiceNumber() => _db.generateInvoiceNumber();

  Future<int> recordSale(Sale sale, List<SaleItem> items) async {
    final id = await _db.insertSale(sale, items);
    await loadInitialData(); // لتحديث المخزون المعروض
    return id;
  }
}

// عنصر في سلة البيع الحالية (قبل تأكيد الفاتورة)
class CartItem {
  final Product product;
  double quantity;

  CartItem({required this.product, this.quantity = 1});

  double get subtotal => quantity * product.salePrice;
}

class CartState extends ChangeNotifier {
  final List<CartItem> items = [];
  String? customerName;
  String? customerPhone;
  String paymentMethod = 'نقدي';
  double paidAmount = 0;

  double get total => items.fold(0, (sum, item) => sum + item.subtotal);

  void addProduct(Product product) {
    final existing = items.indexWhere((i) => i.product.id == product.id);
    if (existing >= 0) {
      items[existing].quantity += 1;
    } else {
      items.add(CartItem(product: product));
    }
    notifyListeners();
  }

  void updateQuantity(int productId, double qty) {
    final existing = items.indexWhere((i) => i.product.id == productId);
    if (existing >= 0) {
      if (qty <= 0) {
        items.removeAt(existing);
      } else {
        items[existing].quantity = qty;
      }
      notifyListeners();
    }
  }

  void removeItem(int productId) {
    items.removeWhere((i) => i.product.id == productId);
    notifyListeners();
  }

  void clear() {
    items.clear();
    customerName = null;
    customerPhone = null;
    paymentMethod = 'نقدي';
    paidAmount = 0;
    notifyListeners();
  }
}
