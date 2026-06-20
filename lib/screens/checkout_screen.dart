import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

import '../models/sale.dart';
import '../db/database_helper.dart';
import '../services/app_state.dart';
import '../services/bluetooth_print_service.dart';
import '../services/invoice_service.dart';
import '../utils/currency_formatter.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _customerNameCtrl = TextEditingController();
  final _customerPhoneCtrl = TextEditingController();
  final _paidCtrl = TextEditingController();
  String _paymentMethod = 'نقدي';
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartState>();
    final appState = context.watch<AppState>();

    if (_paidCtrl.text.isEmpty) {
      _paidCtrl.text = cart.total.toStringAsFixed(0);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('إتمام البيع')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: cart.items
                    .map((i) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(child: Text('${i.product.name} × ${i.quantity.toStringAsFixed(0)}')),
                              Text(CurrencyFormatter.format(i.subtotal)),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _customerNameCtrl,
            decoration: const InputDecoration(
                labelText: 'اسم الزبون (اختياري)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _customerPhoneCtrl,
            decoration: const InputDecoration(
                labelText: 'رقم هاتف الزبون (اختياري)', border: OutlineInputBorder()),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _paymentMethod,
            decoration: const InputDecoration(labelText: 'طريقة الدفع', border: OutlineInputBorder()),
            items: ['نقدي', 'دين', 'تحويل بنكي']
                .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                .toList(),
            onChanged: (v) => setState(() => _paymentMethod = v ?? 'نقدي'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _paidCtrl,
            decoration: const InputDecoration(labelText: 'المبلغ المدفوع', border: OutlineInputBorder()),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 20),
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('المجموع الكلي', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    CurrencyFormatter.format(cart.total),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            icon: _saving
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check_circle),
            label: const Text('تأكيد البيع'),
            onPressed: _saving
                ? null
                : () async {
                    setState(() => _saving = true);
                    final invoiceNumber = await appState.nextInvoiceNumber();
                    final paid = double.tryParse(_paidCtrl.text) ?? 0;

                    int? customerId;
                    final custName = _customerNameCtrl.text.trim();
                    if (custName.isNotEmpty) {
                      customerId = await DatabaseHelper.instance.findOrCreateCustomer(
                        custName,
                        phone: _customerPhoneCtrl.text.trim().isEmpty
                            ? null
                            : _customerPhoneCtrl.text.trim(),
                      );
                    }

                    final sale = Sale(
                      customerId: customerId,
                      invoiceNumber: invoiceNumber,
                      customerName: custName.isEmpty ? null : custName,
                      customerPhone: _customerPhoneCtrl.text.trim().isEmpty
                          ? null
                          : _customerPhoneCtrl.text.trim(),
                      totalAmount: cart.total,
                      paidAmount: paid,
                      paymentMethod: _paymentMethod,
                    );
                    final items = cart.items
                        .map((i) => SaleItem(
                              saleId: 0,
                              productId: i.product.id!,
                              productName: i.product.name,
                              quantity: i.quantity,
                              unitPrice: i.product.salePrice,
                              unitCost: i.product.purchasePrice,
                            ))
                        .toList();

                    await appState.recordSale(sale, items);
                    cart.clear();
                    setState(() => _saving = false);

                    if (context.mounted) {
                      _showSuccessDialog(context, sale, items, appState.shopName, appState.shopPhone);
                    }
                  },
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(
      BuildContext context, Sale sale, List<SaleItem> items, String shopName, String shopPhone) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('تمت عملية البيع بنجاح ✅'),
        content: Text('رقم الفاتورة: ${sale.invoiceNumber}\nالمجموع: ${CurrencyFormatter.format(sale.totalAmount)}'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.share),
            label: const Text('مشاركة PDF'),
            onPressed: () async {
              await InvoicePdfService.shareInvoice(
                sale: sale,
                items: items,
                shopName: shopName,
                shopPhone: shopPhone.isEmpty ? null : shopPhone,
              );
            },
          ),
          TextButton.icon(
            icon: const Icon(Icons.print),
            label: const Text('طباعة بلوتوث'),
            onPressed: () => _printViaBluetooth(ctx, sale, items, shopName, shopPhone),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx); // close dialog
              Navigator.pop(context); // back to POS
            },
            child: const Text('تم'),
          ),
        ],
      ),
    );
  }

  Future<void> _printViaBluetooth(BuildContext context, Sale sale, List<SaleItem> items,
      String shopName, String shopPhone) async {
    final service = BluetoothPrintService.instance;

    if (!service.isConnected) {
      await service.requestPermissions();
      final devices = await service.getPairedDevices();
      if (!context.mounted) return;

      if (devices.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا توجد طابعة مقترنة. اذهب للإعدادات > الطابعة لإقران واحدة')),
        );
        return;
      }

      final selected = await showDialog<BluetoothDevice>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('اختر الطابعة'),
          children: devices
              .map((d) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(ctx, d),
                    child: Text(d.name ?? d.address),
                  ))
              .toList(),
        ),
      );
      if (selected == null) return;
      final connected = await service.connect(selected);
      if (!connected) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('فشل الاتصال بالطابعة')));
        }
        return;
      }
    }

    final success = await service.printInvoice(
      sale: sale,
      items: items,
      shopName: shopName,
      shopPhone: shopPhone.isEmpty ? null : shopPhone,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? 'تمت الطباعة بنجاح' : 'فشلت الطباعة')),
      );
    }
  }
}
