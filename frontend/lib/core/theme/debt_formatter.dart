import 'package:intl/intl.dart';

/// Formats a debt in cents (225 -> "2,25 €"). Separate from `AmountFormatter` because debts always show
/// two decimals.
class DebtFormatter {
  DebtFormatter._();

  static final _format = NumberFormat.currency(
    locale: 'es_ES',
    symbol: '€',
    decimalDigits: 2,
  );

  static String format(int cents) => _format.format(cents / 100);
}
