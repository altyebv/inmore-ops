import 'package:intl/intl.dart';

/// Qatar: QAR, two decimals, Gregorian dates rendered locally.
class Fmt {
  const Fmt._();

  static final NumberFormat _money = NumberFormat('#,##0.00', 'en');
  static final NumberFormat _qty = NumberFormat('#,##0.##', 'en');
  static final DateFormat _date = DateFormat('d MMM yyyy');
  static final DateFormat _dateTime = DateFormat('d MMM yyyy, HH:mm');
  static final DateFormat _time = DateFormat('HH:mm');

  static String money(num? amount) =>
      amount == null ? '—' : 'QAR ${_money.format(amount)}';

  /// Without the currency prefix, for columns that already say QAR.
  static String amount(num? value) =>
      value == null ? '—' : _money.format(value);

  static String qty(num? value) => value == null ? '—' : _qty.format(value);

  static String date(DateTime? d) => d == null ? '—' : _date.format(d);

  static String dateTime(DateTime? d) => d == null ? '—' : _dateTime.format(d);

  /// "today, 14:30" / "yesterday, 09:05" / "3 Feb 2026, 09:05" — timelines
  /// read better with the recent entries relative.
  static String timelineStamp(DateTime d) {
    final now = DateTime.now();
    final day = DateTime(d.year, d.month, d.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today, ${_time.format(d)}';
    if (diff == 1) return 'Yesterday, ${_time.format(d)}';
    return _dateTime.format(d);
  }

  /// "6 days" / "4h" / "25m" — durations people actually say out loud.
  static String duration(Duration? d) {
    if (d == null) return '—';
    if (d.inDays >= 1) return '${d.inDays} day${d.inDays == 1 ? '' : 's'}';
    if (d.inHours >= 1) return '${d.inHours}h';
    return '${d.inMinutes}m';
  }

  /// How long ago, for "waiting since" labels.
  static String since(DateTime? from) {
    if (from == null) return '—';
    return duration(DateTime.now().difference(from));
  }
}
