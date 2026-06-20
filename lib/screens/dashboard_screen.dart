import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/database_helper.dart';
import '../services/app_state.dart';
import '../utils/currency_formatter.dart';
import '../widgets/stat_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _todaySummary;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day);
    final to = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final summary =
        await DatabaseHelper.instance.getSummary(from: from, to: to);
    setState(() {
      _todaySummary = summary;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final summary = _todaySummary!;
    final lowStock = appState.lowStockProducts;

    return RefreshIndicator(
      onRefresh: () async {
        await appState.loadInitialData();
        await _load();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('مرحباً بك 👋', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(appState.shopName,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey)),
          const SizedBox(height: 16),
          Text('ملخص اليوم', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              StatCard(
                title: 'مبيعات اليوم',
                value: CurrencyFormatter.format(summary['total_sales']),
                icon: Icons.point_of_sale,
                color: Colors.teal,
              ),
              StatCard(
                title: 'ربح اليوم',
                value: CurrencyFormatter.format(summary['total_profit']),
                icon: Icons.trending_up,
                color: Colors.green,
              ),
              StatCard(
                title: 'مصاريف اليوم',
                value: CurrencyFormatter.format(summary['total_expenses']),
                icon: Icons.money_off,
                color: Colors.red,
              ),
              StatCard(
                title: 'صافي الربح',
                value: CurrencyFormatter.format(summary['net_profit']),
                icon: Icons.account_balance_wallet,
                color: Colors.indigo,
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (lowStock.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                const SizedBox(width: 6),
                Text('منتجات منخفضة المخزون (${lowStock.length})',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: lowStock
                    .map((p) => ListTile(
                          leading: const Icon(Icons.inventory_2_outlined),
                          title: Text(p.name),
                          subtitle: Text('المتوفر: ${p.quantity.toStringAsFixed(0)} ${p.unit}'),
                          trailing: Chip(
                            label: Text('حد التنبيه: ${p.minStock.toStringAsFixed(0)}'),
                            backgroundColor: Colors.orange.withOpacity(0.15),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text('الفروع', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...appState.branches.map((b) {
            final types = appState.typesByBranch[b.id] ?? [];
            final productCount = types.fold<int>(
                0, (sum, t) => sum + (appState.productsByType[t.id]?.length ?? 0));
            return Card(
              child: ListTile(
                leading: const Icon(Icons.store),
                title: Text(b.name),
                subtitle: Text('${types.length} أنواع - $productCount منتج'),
              ),
            );
          }),
        ],
      ),
    );
  }
}
