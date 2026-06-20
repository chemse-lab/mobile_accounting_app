import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/branch.dart';
import '../models/product_type.dart';
import '../models/product.dart';
import '../services/app_state.dart';
import '../utils/currency_formatter.dart';

class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      body: appState.branches.isEmpty
          ? const Center(child: Text('لا توجد فروع بعد'))
          : DefaultTabController(
              length: appState.branches.length,
              child: Column(
                children: [
                  TabBar(
                    isScrollable: true,
                    tabs: appState.branches.map((b) => Tab(text: b.name)).toList(),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: appState.branches
                          .map((b) => _BranchTypesView(branch: b))
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddBranchDialog(context),
        icon: const Icon(Icons.add_business),
        label: const Text('فرع جديد'),
      ),
    );
  }

  void _showAddBranchDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة فرع جديد'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'اسم الفرع'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                context.read<AppState>().addBranch(controller.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }
}

class _BranchTypesView extends StatelessWidget {
  final Branch branch;
  const _BranchTypesView({required this.branch});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final types = appState.typesByBranch[branch.id] ?? [];

    return Scaffold(
      body: types.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.category_outlined, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text('لا توجد أنواع في هذا الفرع بعد'),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => _showAddTypeDialog(context, branch.id!),
                      icon: const Icon(Icons.add),
                      label: const Text('إضافة نوع'),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: types.length,
              itemBuilder: (ctx, i) {
                final type = types[i];
                final products = appState.productsByType[type.id] ?? [];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ExpansionTile(
                    title: Text(type.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${products.length} منتج'),
                    children: [
                      ...products.map((p) => _ProductTile(product: p)),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _showAddProductDialog(context, type),
                                icon: const Icon(Icons.add),
                                label: const Text('منتج جديد'),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => context.read<AppState>().deleteType(type.id!),
                              tooltip: 'حذف النوع',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: types.isEmpty
          ? null
          : FloatingActionButton.small(
              onPressed: () => _showAddTypeDialog(context, branch.id!),
              child: const Icon(Icons.add),
            ),
    );
  }

  void _showAddTypeDialog(BuildContext context, int branchId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة نوع جديد'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'اسم النوع'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                context.read<AppState>().addType(branchId, controller.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  void _showAddProductDialog(BuildContext context, ProductType type) {
    showDialog(
      context: context,
      builder: (ctx) => _ProductFormDialog(typeId: type.id!),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final Product product;
  const _ProductTile({required this.product});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(product.name),
      subtitle: Text(
        'بيع: ${CurrencyFormatter.format(product.salePrice)}  |  شراء: ${CurrencyFormatter.format(product.purchasePrice)}',
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${product.quantity.toStringAsFixed(0)} ${product.unit}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: product.isLowStock ? Colors.red : Colors.green,
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                showDialog(
                  context: context,
                  builder: (ctx) =>
                      _ProductFormDialog(typeId: product.typeId, existing: product),
                );
              } else if (value == 'delete') {
                context.read<AppState>().deleteProduct(product.id!);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'edit', child: Text('تعديل')),
              const PopupMenuItem(value: 'delete', child: Text('حذف')),
            ],
            child: const Icon(Icons.more_vert, size: 18),
          ),
        ],
      ),
    );
  }
}

class _ProductFormDialog extends StatefulWidget {
  final int typeId;
  final Product? existing;
  const _ProductFormDialog({required this.typeId, this.existing});

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  late final TextEditingController _name;
  late final TextEditingController _unit;
  late final TextEditingController _purchasePrice;
  late final TextEditingController _salePrice;
  late final TextEditingController _quantity;
  late final TextEditingController _minStock;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _unit = TextEditingController(text: e?.unit ?? 'قطعة');
    _purchasePrice = TextEditingController(text: e?.purchasePrice.toString() ?? '');
    _salePrice = TextEditingController(text: e?.salePrice.toString() ?? '');
    _quantity = TextEditingController(text: e?.quantity.toString() ?? '0');
    _minStock = TextEditingController(text: e?.minStock.toString() ?? '5');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'منتج جديد' : 'تعديل المنتج'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'اسم المنتج')),
            TextField(
                controller: _unit,
                decoration: const InputDecoration(labelText: 'وحدة البيع (قطعة، كيلو...)')),
            TextField(
                controller: _purchasePrice,
                decoration: const InputDecoration(labelText: 'سعر الشراء'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true)),
            TextField(
                controller: _salePrice,
                decoration: const InputDecoration(labelText: 'سعر البيع'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true)),
            TextField(
                controller: _quantity,
                decoration: const InputDecoration(labelText: 'الكمية المتوفرة'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true)),
            TextField(
                controller: _minStock,
                decoration: const InputDecoration(labelText: 'حد التنبيه للمخزون'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(
          onPressed: () {
            if (_name.text.trim().isEmpty) return;
            final product = Product(
              id: widget.existing?.id,
              typeId: widget.typeId,
              name: _name.text.trim(),
              unit: _unit.text.trim().isEmpty ? 'قطعة' : _unit.text.trim(),
              purchasePrice: double.tryParse(_purchasePrice.text) ?? 0,
              salePrice: double.tryParse(_salePrice.text) ?? 0,
              quantity: double.tryParse(_quantity.text) ?? 0,
              minStock: double.tryParse(_minStock.text) ?? 5,
            );
            if (widget.existing == null) {
              context.read<AppState>().addProduct(product);
            } else {
              context.read<AppState>().updateProduct(product);
            }
            Navigator.pop(context);
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}
