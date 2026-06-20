import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../db/database_helper.dart';
import '../utils/currency_formatter.dart';

enum ReportPeriod { today, week, month, custom }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  ReportPeriod _period = ReportPeriod.today;
  DateTime _customFrom = DateTime.now().subtract(const Duration(days: 7));
  DateTime _customTo = DateTime.now();
  Map<String, dynamic>? _summary;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  (DateTime, DateTime) _range() {
    final now = DateTime.now();
    switch (_period) {
      case ReportPeriod.today:
        return (DateTime(now.year, now.month, now.day), DateTime(now.year, now.month, now.day, 23, 59, 59));
      case ReportPeriod.week:
        return (now.subtract(const Duration(days: 7)), now);
      case ReportPeriod.month:
        return (DateTime(now.year, now.month, 1), now);
      case ReportPeriod.custom:
        return (_customFrom, _customTo);
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final (from, to) = _range();
    final summary = await DatabaseHelper.instance.getSummary(from: from, to: to);
    setState(() {
      _summary = summary;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('اليوم'),
                  selected: _period == ReportPeriod.today,
                  onSelected: (_) {
                    setState(() => _period = ReportPeriod.today);
                    _load();
                  },
                ),
                ChoiceChip(
                  label: const Text('آخر 7 أيام'),
                  selected: _period == ReportPeriod.week,
                  onSelected: (_) {
                    setState(() => _period = ReportPeriod.week);
                    _load();
                  },
                ),
                ChoiceChip(
                  label: const Text('هذا الشهر'),
                  selected: _period == ReportPeriod.month,
                  onSelected: (_) {
                    setState(() => _period = ReportPeriod.month);
                    _load();
                  },
                ),
                ChoiceChip(
                  label: const Text('فترة مخصصة'),
                  selected: _period == ReportPeriod.custom,
                  onSelected: (_) async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() {
                        _period = ReportPeriod.custom;
                        _customFrom = picked.start;
                        _customTo = picked.end;
                      });
                      _load();
                    }
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _buildReport(),
          ),
        ],
      ),
    );
  }

  Widget _buildReport() {
    final s = _summary!;
    final byBranch = s['by_branch'] as List;
    final byType = s['by_type'] as List;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: _summaryTile('المبيعات', s['total_sales'], Colors.teal),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _summaryTile('الأرباح', s['total_profit'], Colors.green),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _summaryTile('المصاريف', s['total_expenses'], Colors.red),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _summaryTile('صافي الربح', s['net_profit'], Colors.indigo),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (byBranch.isNotEmpty) ...[
          Text('المبيعات حسب الفرع', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                sections: byBranch.asMap().entries.map((entry) {
                  final colors = [Colors.teal, Colors.orange, Colors.purple, Colors.blue];
                  final data = entry.value;
                  final total = (data['total_sales'] as num?)?.toDouble() ?? 0;
                  return PieChartSectionData(
                    value: total,
                    title: data['branch_name'] as String,
                    color: colors[entry.key % colors.length],
                    radius: 60,
                    titleStyle: const TextStyle(fontSize: 11, color: Colors.white),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...byBranch.map((b) => Card(
                child: ListTile(
                  title: Text(b['branch_name'] as String),
                  subtitle: Text(
                      'ربح: ${CurrencyFormatter.format((b['total_profit'] as num?)?.toDouble() ?? 0)}'),
                  trailing: Text(
                    CurrencyFormatter.format((b['total_sales'] as num?)?.toDouble() ?? 0),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              )),
        ],
        const SizedBox(height: 24),
        if (byType.isNotEmpty) ...[
          Text('المبيعات حسب النوع', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          ...byType.map((t) => Card(
                child: ListTile(
                  title: Text(t['type_name'] as String),
                  subtitle: Text('${t['branch_name']} - الكمية المباعة: ${(t['total_qty'] as num?)?.toStringAsFixed(0) ?? '0'}'),
                  trailing: Text(
                    CurrencyFormatter.format((t['total_sales'] as num?)?.toDouble() ?? 0),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              )),
        ],
        if (byBranch.isEmpty && byType.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('لا توجد مبيعات في هذه الفترة')),
          ),
      ],
    );
  }

  Widget _summaryTile(String title, dynamic value, Color color) {
    final v = (value as num?)?.toDouble() ?? 0;
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(height: 6),
            Text(CurrencyFormatter.format(v),
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
