import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/sale.dart';
import '../services/app_state.dart';
import '../utils/currency_formatter.dart';
import 'checkout_screen.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  int? _selectedBranchId;
  int? _selectedTypeId;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final cart = context.watch<CartState>();

    if (appState.branches.isNotEmpty && _selectedBranchId == null) {
      _selectedBranchId = appState.branches.first.id;
    }

    final types = _selectedBranchId == null
        ? <dynamic>[]
        : (appState.typesByBranch[_selectedBranchId] ?? []);

    List products = [];
    if (_selectedTypeId != null) {
      products = appState.productsByType[_selectedTypeId] ?? [];
    } else if (types.isNotEmpty) {
      products = types.expand((t) => appState.productsByType[t.id] ?? []).toList();
    }

    if (_search.isNotEmpty) {
      products = products
          .where((p) => p.name.toString().toLowerCase().contains(_search.toLowerCase()))
          .toList();
    }

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'ابحث عن منتج...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          // اختيار الفرع
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: appState.branches.map((b) {
                final selected = b.id == _selectedBranchId;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(b.name),
                    selected: selected,
                    onSelected: (_) => setState(() {
                      _selectedBranchId = b.id;
                      _selectedTypeId = null;
                    }),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),
          // اختيار النوع
          if (types.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: const Text('الكل'),
                      selected: _selectedTypeId == null,
                      onSelected: (_) => setState(() => _selectedTypeId = null),
                    ),
                  ),
                  ...types.map((t) {
                    final selected = t.id == _selectedTypeId;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(t.name),
                        selected: selected,
                        onSelected: (_) => setState(() => _selectedTypeId = t.id),
                      ),
                    );
                  }),
                ],
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: products.isEmpty
                ? const Center(child: Text('لا توجد منتجات'))
                : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: products.length,
                    itemBuilder: (ctx, i) {
                      final product = products[i];
                      return Card(
                        child: InkWell(
                          onTap: () => cart.addProduct(product),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(product.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                                Text(
                                  CurrencyFormatter.format(product.salePrice),
                                  style: const TextStyle(color: Colors.teal),
                                ),
                                Text(
                                  'متوفر: ${product.quantity.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: product.isLowStock ? Colors.red : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (cart.items.isNotEmpty) _CartBar(),
        ],
      ),
    );
  }
}

class _CartBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartState>();
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8)],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: () => _showCartSheet(context),
                icon: const Icon(Icons.shopping_cart),
                label: Text('${cart.items.length} عناصر'),
              ),
            ),
            Text(
              CurrencyFormatter.format(cart.total),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CheckoutScreen()),
                );
              },
              child: const Text('إتمام البيع'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCartSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          expand: false,
          builder: (ctx, scrollController) {
            return Consumer<CartState>(
              builder: (ctx, cart, _) {
                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text('سلة البيع', style: Theme.of(ctx).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    ...cart.items.map((item) => ListTile(
                          title: Text(item.product.name),
                          subtitle: Text(CurrencyFormatter.format(item.product.salePrice)),
                          leading: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () => cart.updateQuantity(
                                    item.product.id!, item.quantity - 1),
                              ),
                              Text(item.quantity.toStringAsFixed(0)),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () => cart.updateQuantity(
                                    item.product.id!, item.quantity + 1),
                              ),
                            ],
                          ),
                          trailing: Text(CurrencyFormatter.format(item.subtotal)),
                        )),
                    const Divider(),
                    ListTile(
                      title: const Text('المجموع', style: TextStyle(fontWeight: FontWeight.bold)),
                      trailing: Text(
                        CurrencyFormatter.format(cart.total),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}
