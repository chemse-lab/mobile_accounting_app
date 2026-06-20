import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/database_helper.dart';
import '../models/sale.dart';
import '../services/app_state.dart';
import '../services/invoice_service.dart';
import '../utils/currency_formatter.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  List<Sale> _sales = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final sales = await DatabaseHelper.instance.getSales();
    setState(() {
      _sales = sales;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_sales.isEmpty) {
      return const Center(child: Text('لا توجد فواتير بعد'));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        itemCount: _sales.length,
        itemBuilder: (ctx, i) {
          final sale = _sales[i];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: sale.isFullyPaid
                  ? Colors.green.withOpacity(0.15)
                  : Colors.orange.withOpacity(0.15),
              child: Icon(
                sale.isFullyPaid ? Icons.check : Icons.hourglass_bottom,
                color: sale.isFullyPaid ? Colors.green : Colors.orange,
              ),
            ),
            title: Text(sale.invoiceNumber),
            subtitle: Text(
                '${DateFormatter.dateTime(sale.date)}${sale.customerName != null ? ' - ${sale.customerName}' : ''}'),
            trailing: Text(
              CurrencyFormatter.format(sale.totalAmount),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onTap: () => _showSaleDetails(sale),
          );
        },
      ),
    );
  }

  void _showSaleDetails(Sale sale) async {
    final items = await DatabaseHelper.instance.getSaleItems(sale.id!);
    final appState = context.read<AppState>();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            Text(sale.invoiceNumber, style: Theme.of(ctx).textTheme.titleLarge),
            Text(DateFormatter.dateTime(sale.date)),
            if (sale.customerName != null) Text('الزبون: ${sale.customerName}'),
            const Divider(),
            ...items.map((i) => ListTile(
                  title: Text(i.productName),
                  subtitle: Text('${i.quantity.toStringAsFixed(0)} × ${CurrencyFormatter.format(i.unitPrice)}'),
                  trailing: Text(CurrencyFormatter.format(i.subtotal)),
                )),
            const Divider(),
            ListTile(
              title: const Text('المجموع', style: TextStyle(fontWeight: FontWeight.bold)),
              trailing: Text(CurrencyFormatter.format(sale.totalAmount),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            ListTile(
              title: const Text('المدفوع'),
              trailing: Text(CurrencyFormatter.format(sale.paidAmount)),
            ),
            if (sale.remaining > 0)
              ListTile(
                title: const Text('المتبقي', style: TextStyle(color: Colors.orange)),
                trailing: Text(CurrencyFormatter.format(sale.remaining),
                    style: const TextStyle(color: Colors.orange)),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.share),
                    label: const Text('مشاركة PDF'),
                    onPressed: () => InvoicePdfService.shareInvoice(
                      sale: sale,
                      items: items,
                      shopName: appState.shopName,
                      shopPhone: appState.shopPhone.isEmpty ? null : appState.shopPhone,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('حذف الفاتورة'),
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () async {
                      await DatabaseHelper.instance.deleteSale(sale.id!);
                      if (ctx.mounted) Navigator.pop(ctx);
                      _load();
                      appState.loadInitialData();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
