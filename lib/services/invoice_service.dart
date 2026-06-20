import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/sale.dart';
import '../utils/currency_formatter.dart';

class InvoicePdfService {
  static Future<void> shareInvoice({
    required Sale sale,
    required List<SaleItem> items,
    required String shopName,
    String? shopPhone,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        textDirection: pw.TextDirection.rtl,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  shopName,
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                ),
              ),
              if (shopPhone != null)
                pw.Center(child: pw.Text('هاتف: $shopPhone')),
              pw.Divider(),
              pw.Text('رقم الفاتورة: ${sale.invoiceNumber}'),
              pw.Text('التاريخ: ${DateFormatter.dateTime(sale.date)}'),
              if (sale.customerName != null)
                pw.Text('الزبون: ${sale.customerName}'),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                headers: ['المجموع', 'سعر الوحدة', 'الكمية', 'المنتج'],
                data: items
                    .map((i) => [
                          CurrencyFormatter.formatNoSymbol(i.subtotal),
                          CurrencyFormatter.formatNoSymbol(i.unitPrice),
                          i.quantity.toStringAsFixed(0),
                          i.productName,
                        ])
                    .toList(),
              ),
              pw.Divider(),
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  'المجموع الكلي: ${CurrencyFormatter.format(sale.totalAmount)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
                ),
              ),
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text('المدفوع: ${CurrencyFormatter.format(sale.paidAmount)}'),
              ),
              if (sale.remaining > 0)
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text('المتبقي: ${CurrencyFormatter.format(sale.remaining)}'),
                ),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: '${sale.invoiceNumber}.pdf',
    );
  }

  /// طباعة عبر أي طابعة متوافقة (Wi-Fi/USB) مسجلة في نظام التشغيل، بديل عن البلوتوث الحراري
  static Future<void> printStandard({
    required Sale sale,
    required List<SaleItem> items,
    required String shopName,
    String? shopPhone,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        textDirection: pw.TextDirection.rtl,
        build: (context) => pw.Text(shopName),
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }
}
