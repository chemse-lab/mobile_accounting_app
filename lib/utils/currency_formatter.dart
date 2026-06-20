import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _format = NumberFormat('#,##0.00', 'en_US');

  static String format(double value) {
    return '${_format.format(value)} د.ج';
  }

  static String formatNoSymbol(double value) {
    return _format.format(value);
  }
}

class DateFormatter {
  static String shortDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  static String dateTime(DateTime date) {
    return DateFormat('yyyy-MM-dd HH:mm').format(date);
  }

  static String time(DateTime date) {
    return DateFormat('HH:mm').format(date);
  }
}
