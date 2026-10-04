import 'package:intl/intl.dart';

/// Shared display formatters so currency and dates look identical everywhere.
///
/// Dates are formatted from an explicit Indonesian month table instead of
/// `DateFormat(..., 'id_ID')`. The `intl` locale data must be initialised
/// asynchronously before use, which is easy to forget and throws at runtime the
/// first time a date is rendered. The currency formatter is safe because `intl`
/// bundles the default number symbols eagerly.
class Formatters {
  const Formatters._();

  static const List<String> _months = <String>[
    'Jan', //
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  /// Rupiah with thousands separators and no decimals: `Rp275.000`.
  static String rupiah(num value) => _currency.format(value);

  /// Compact form used inside tight list tiles: `Rp275rb`.
  static String rupiahShort(num value) {
    if (value >= 1000000) {
      final millions = value / 1000000;
      return 'Rp${millions.toStringAsFixed(millions % 1 == 0 ? 0 : 1)}jt';
    }
    if (value >= 1000) {
      final thousands = value / 1000;
      return 'Rp${thousands.toStringAsFixed(thousands % 1 == 0 ? 0 : 1)}rb';
    }
    return rupiah(value);
  }

  /// `15 Jan 2026`, or a dash when the timestamp is missing.
  static String date(DateTime? value) {
    if (value == null) return '-';
    return '${value.day} ${_months[value.month - 1]} ${value.year}';
  }

  /// `15 Jan 2026, 09:30`, or a dash when the timestamp is missing.
  static String dateTime(DateTime? value) {
    if (value == null) return '-';

    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');

    return '${date(value)}, $hour:$minute';
  }

  /// `4.8` / `4.8 (12)` — the rating shown under a product name.
  static String rating(double avg, int count) {
    final text = avg.toStringAsFixed(1);
    return count > 0 ? '$text ($count)' : 'Belum ada rating';
  }
}
