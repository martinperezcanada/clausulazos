import 'package:intl/intl.dart';

/// Formats a whole-euro clause amount, e.g. "48.500.000 €".
class AmountFormatter {
  AmountFormatter._();

  static final _format = NumberFormat.currency(
    locale: 'es_ES',
    symbol: '€',
    decimalDigits: 0,
  );

  static String format(int amount) => _format.format(amount);
}
