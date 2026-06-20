import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/customer.dart';
import '../utils/currency_formatter.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  List<Map<String, dynamic>> _customers = [];
  bool _loading = true;
  bool _onlyWithDebt = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list =
        await DatabaseHelper.instance.getCustomersWithDebt(onlyWithDebt: _onlyWithDebt);
    setState(() {
      _customers = list;
      _loading = false;
    });
  }

  double get _totalDebt =>
      _customers.fold(0, (sum, c) => sum + (c['debt'] as double));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Card(
              color: Colors.orange.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('إجمالي الديون', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      CurrencyFormatter.format(_totalDebt),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('عرض من لديهم دين فقط'),
                const Spacer(),
                Switch(
                  value: _onlyWithDebt,
                  onChanged: (v) {
                    setState(() => _onlyWithDebt = v);
                    _load();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _customers.isEmpty
                    ? const Center(child: Text('لا يوجد زبائن مدينون 🎉'))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          itemCount: _customers.length,
                          itemBuilder: (ctx, i) {
                            final entry = _customers[i];
                            final customer = entry['customer'] as Customer;
                            final debt = entry['debt'] as double;
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    debt > 0 ? Colors.red.withOpacity(0.15) : Colors.green.withOpacity(0.15),
                                child: Icon(Icons.person,
                                    color: debt > 0 ? Colors.red : Colors.green),
                              ),
                              title: Text(customer.name),
                              subtitle: Text(customer.phone ?? 'لا يوجد رقم هاتف'),
                              trailing: Text(
                                CurrencyFormatter.format(debt),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: debt > 0 ? Colors.red : Colors.green,
                                ),
                              ),
                              onTap: () => _showCustomerDetails(customer, debt),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  void _showCustomerDetails(Customer customer, double debt) async {
    final payments = await DatabaseHelper.instance.getCustomerPayments(customer.id!);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => StatefulBuilder(
          builder: (ctx, setSheetState) => ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              Text(customer.name, style: Theme.of(ctx).textTheme.titleLarge),
              if (customer.phone != null) Text(customer.phone!),
              const SizedBox(height: 12),
              Card(
                color: debt > 0 ? Colors.red.withOpacity(0.08) : Colors.green.withOpacity(0.08),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('الدين الحالي', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        CurrencyFormatter.format(debt),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: debt > 0 ? Colors.red : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (debt > 0)
                FilledButton.icon(
                  icon: const Icon(Icons.payments),
                  label: const Text('تسجيل دفعة سداد'),
                  onPressed: () => _showAddPaymentDialog(ctx, customer, () async {
                    await _load();
                    Navigator.pop(ctx);
                  }),
                ),
              const SizedBox(height: 16),
              Text('سجل الدفعات', style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (payments.isEmpty)
                const Text('لا توجد دفعات سابقة', style: TextStyle(color: Colors.grey))
              else
                ...payments.map((p) => ListTile(
                      leading: const Icon(Icons.check_circle_outline, color: Colors.green),
                      title: Text(CurrencyFormatter.format(p.amount)),
                      subtitle: Text(DateFormatter.dateTime(p.date) +
                          (p.note != null ? ' - ${p.note}' : '')),
                    )),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddPaymentDialog(BuildContext context, Customer customer, VoidCallback onSaved) {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('دفعة من ${customer.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              decoration: const InputDecoration(labelText: 'المبلغ المدفوع'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
            ),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text) ?? 0;
              if (amount <= 0) return;
              await DatabaseHelper.instance.recordDebtPayment(
                customer.id!,
                amount,
                note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx);
              onSaved();
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}
