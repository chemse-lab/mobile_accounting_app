import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/expense.dart';
import '../utils/currency_formatter.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  List<Expense> _expenses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await DatabaseHelper.instance.getExpenses();
    setState(() {
      _expenses = list;
      _loading = false;
    });
  }

  double get _total => _expenses.fold(0, (sum, e) => sum + e.amount);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Card(
                      color: Colors.red.withOpacity(0.08),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('إجمالي المصاريف', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(CurrencyFormatter.format(_total),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, color: Colors.red, fontSize: 18)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_expenses.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('لا توجد مصاريف مسجلة')),
                    )
                  else
                    ..._expenses.map((e) => Dismissible(
                          key: ValueKey(e.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 20),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (_) async {
                            await DatabaseHelper.instance.deleteExpense(e.id!);
                            _load();
                          },
                          child: ListTile(
                            leading: const Icon(Icons.receipt),
                            title: Text(e.category),
                            subtitle: Text(DateFormatter.shortDate(e.date) +
                                (e.note != null ? ' - ${e.note}' : '')),
                            trailing: Text(
                              CurrencyFormatter.format(e.amount),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                            ),
                          ),
                        )),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddExpenseDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('مصروف جديد'),
      ),
    );
  }

  void _showAddExpenseDialog(BuildContext context) {
    String category = expenseCategories.first;
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('مصروف جديد'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(labelText: 'التصنيف'),
                items: expenseCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setStateDialog(() => category = v ?? category),
              ),
              TextField(
                controller: amountCtrl,
                decoration: const InputDecoration(labelText: 'المبلغ'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                await DatabaseHelper.instance.insertExpense(Expense(
                  category: category,
                  amount: amount,
                  note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                ));
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}
