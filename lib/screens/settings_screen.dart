import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

import '../services/app_state.dart';
import '../services/bluetooth_print_service.dart';
import '../services/backup_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<BluetoothDevice> _devices = [];
  bool _scanning = false;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final btService = BluetoothPrintService.instance;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('معلومات المتجر', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextFormField(
                  initialValue: appState.shopName,
                  decoration: const InputDecoration(labelText: 'اسم المتجر'),
                  onFieldSubmitted: (v) => appState.updateShopInfo(name: v),
                  onEditingComplete: () {},
                ),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: appState.shopPhone,
                  decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                  keyboardType: TextInputType.phone,
                  onFieldSubmitted: (v) => appState.updateShopInfo(phone: v),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('اضغط Enter لحفظ كل حقل',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('طابعة الإيصالات (بلوتوث)', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      btService.isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                      color: btService.isConnected ? Colors.blue : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        btService.isConnected
                            ? 'متصل: ${btService.connectedDevice?.name ?? ''}'
                            : 'غير متصل بأي طابعة',
                      ),
                    ),
                    if (btService.isConnected)
                      TextButton(
                        onPressed: () async {
                          await btService.disconnect();
                          setState(() {});
                        },
                        child: const Text('قطع الاتصال'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'ملاحظة: يجب إقران الطابعة الحرارية أولاً من إعدادات بلوتوث في نظام الجوال، ثم الضغط أدناه لإظهارها.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _scanning
                      ? null
                      : () async {
                          setState(() => _scanning = true);
                          await btService.requestPermissions();
                          await btService.enableBluetooth();
                          final devices = await btService.getPairedDevices();
                          setState(() {
                            _devices = devices;
                            _scanning = false;
                          });
                        },
                  icon: _scanning
                      ? const SizedBox(
                          width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.bluetooth_searching),
                  label: const Text('عرض الأجهزة المقترنة'),
                ),
                if (_devices.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ..._devices.map((d) => ListTile(
                        leading: const Icon(Icons.print),
                        title: Text(d.name ?? 'جهاز غير معروف'),
                        subtitle: Text(d.address),
                        trailing: ElevatedButton(
                          onPressed: () async {
                            final ok = await btService.connect(d);
                            setState(() {});
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(ok ? 'تم الاتصال' : 'فشل الاتصال')),
                              );
                            }
                          },
                          child: const Text('اتصال'),
                        ),
                      )),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('النسخ الاحتياطي', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'احفظ نسخة من جميع بياناتك (منتجات، مبيعات، ديون) وشاركها لتأمينها، أو استعد نسخة سابقة.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.upload),
                        label: const Text('مشاركة نسخة احتياطية'),
                        onPressed: () async {
                          try {
                            await BackupService.exportAndShare();
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(content: Text('فشل: $e')));
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.download),
                        label: const Text('استعادة نسخة'),
                        style: FilledButton.styleFrom(backgroundColor: Colors.orange),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('تأكيد الاستعادة'),
                              content: const Text(
                                  'سيتم استبدال جميع البيانات الحالية بالنسخة المختارة. هل أنت متأكد؟'),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('إلغاء')),
                                FilledButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('متابعة')),
                              ],
                            ),
                          );
                          if (confirm != true) return;
                          try {
                            final success = await BackupService.pickAndRestore();
                            if (success && context.mounted) {
                              await appState.loadInitialData();
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('تمت الاستعادة بنجاح، أعد تشغيل التطبيق')));
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(content: Text('فشل: $e')));
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('إدارة الفروع', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: appState.branches
                .map((b) => ListTile(
                      leading: const Icon(Icons.store),
                      title: Text(b.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () {
                              final ctrl = TextEditingController(text: b.name);
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('تعديل اسم الفرع'),
                                  content: TextField(controller: ctrl),
                                  actions: [
                                    TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('إلغاء')),
                                    FilledButton(
                                      onPressed: () {
                                        appState.renameBranch(b, ctrl.text.trim());
                                        Navigator.pop(ctx);
                                      },
                                      child: const Text('حفظ'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 32),
        Center(
          child: Text(
            'تطبيق المحاسبة - البائع المتنقل\nالإصدار 1.0.0',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ),
      ],
    );
  }
}
