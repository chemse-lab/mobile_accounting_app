import 'dart:typed_data';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/sale.dart';
import '../utils/currency_formatter.dart';

/// خدمة الاتصال بطابعة الإيصالات الحرارية عبر بلوتوث وطباعة الفواتير
class BluetoothPrintService {
  BluetoothPrintService._internal();
  static final BluetoothPrintService instance = BluetoothPrintService._internal();

  BluetoothConnection? _connection;
  BluetoothDevice? _connectedDevice;

  bool get isConnected => _connection?.isConnected ?? false;
  BluetoothDevice? get connectedDevice => _connectedDevice;

  /// طلب أذونات البلوتوث اللازمة (Android 12+)
  Future<bool> requestPermissions() async {
    final statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
    return statuses.values.every(
        (status) => status.isGranted || status.isLimited || status.isProvisional);
  }

  /// إرجاع قائمة الأجهزة المقترنة مسبقاً (يجب إقران الطابعة من إعدادات الجوال أولاً)
  Future<List<BluetoothDevice>> getPairedDevices() async {
    await requestPermissions();
    return FlutterBluetoothSerial.instance.getBondedDevices();
  }

  /// تفعيل البلوتوث إن لم يكن مفعّلاً
  Future<void> enableBluetooth() async {
    final isEnabled = await FlutterBluetoothSerial.instance.isEnabled ?? false;
    if (!isEnabled) {
      await FlutterBluetoothSerial.instance.requestEnable();
    }
  }

  /// الاتصال بطابعة محددة عبر عنوان MAC
  Future<bool> connect(BluetoothDevice device) async {
    try {
      _connection = await BluetoothConnection.toAddress(device.address);
      _connectedDevice = device;
      return true;
    } catch (e) {
      _connection = null;
      _connectedDevice = null;
      return false;
    }
  }

  Future<void> disconnect() async {
    await _connection?.close();
    _connection = null;
    _connectedDevice = null;
  }

  /// طباعة فاتورة كاملة بصيغة إيصال حراري (58mm أو 80mm)
  Future<bool> printInvoice({
    required Sale sale,
    required List<SaleItem> items,
    required String shopName,
    String? shopPhone,
    String paperSize = '58mm', // أو 80mm
  }) async {
    if (_connection == null || !_connection!.isConnected) {
      return false;
    }

    final profile = await CapabilityProfile.load();
    final paper = paperSize == '80mm' ? PaperSize.mm80 : PaperSize.mm58;
    final generator = Generator(paper, profile);

    List<int> bytes = [];

    bytes += generator.text(
      shopName,
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
        bold: true,
      ),
    );
    if (shopPhone != null) {
      bytes += generator.text(
        'هاتف: $shopPhone',
        styles: const PosStyles(align: PosAlign.center),
      );
    }
    bytes += generator.hr();

    bytes += generator.text('رقم الفاتورة: ${sale.invoiceNumber}');
    bytes += generator.text('التاريخ: ${DateFormatter.dateTime(sale.date)}');
    if (sale.customerName != null && sale.customerName!.isNotEmpty) {
      bytes += generator.text('الزبون: ${sale.customerName}');
    }
    bytes += generator.hr();

    for (final item in items) {
      bytes += generator.text(item.productName, styles: const PosStyles(bold: true));
      bytes += generator.row([
        PosColumn(
          text: '${item.quantity.toStringAsFixed(0)} x ${CurrencyFormatter.formatNoSymbol(item.unitPrice)}',
          width: 6,
        ),
        PosColumn(
          text: CurrencyFormatter.formatNoSymbol(item.subtotal),
          width: 6,
          styles: const PosStyles(align: PosAlign.left),
        ),
      ]);
    }

    bytes += generator.hr();
    bytes += generator.row([
      PosColumn(text: 'المجموع', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(
        text: CurrencyFormatter.format(sale.totalAmount),
        width: 6,
        styles: const PosStyles(align: PosAlign.left, bold: true),
      ),
    ]);
    bytes += generator.row([
      PosColumn(text: 'المدفوع', width: 6),
      PosColumn(
        text: CurrencyFormatter.format(sale.paidAmount),
        width: 6,
        styles: const PosStyles(align: PosAlign.left),
      ),
    ]);
    if (sale.remaining > 0) {
      bytes += generator.row([
        PosColumn(text: 'المتبقي', width: 6),
        PosColumn(
          text: CurrencyFormatter.format(sale.remaining),
          width: 6,
          styles: const PosStyles(align: PosAlign.left),
        ),
      ]);
    }

    bytes += generator.hr();
    bytes += generator.text(
      'شكراً لتعاملكم معنا',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.feed(2);
    bytes += generator.cut();

    try {
      _connection!.output.add(Uint8List.fromList(bytes));
      await _connection!.output.allSent;
      return true;
    } catch (e) {
      return false;
    }
  }
}
