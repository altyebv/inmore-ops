import 'package:intl/intl.dart';

/// Qatar: QAR, two decimals, Gregorian dates.
///
/// Locale-aware for the parts a reader sees (month names, the currency
/// mark), but digits stay Western in both languages — that is what Qatari
/// business paperwork uses, and a supervisor comparing a screen with an
/// Excel sheet should see the same characters in both.
///
/// Words ("today", "3 days") are not here: they belong to the UI layer's
/// translations. This class only formats numbers and dates.
class Fmt {
  const Fmt._();

  static String _locale = 'en';

  /// The language the UI is showing. Set by the app whenever it changes.
  static String get locale => _locale;
  static set locale(String value) {
    if (value == _locale) return;
    _locale = value;
    _date = _dateTime = _time = _dayMonth = null;
  }

  static bool get _arabic => _locale == 'ar';

  // Numbers always use Western digits and the English separators.
  static final NumberFormat _money = NumberFormat('#,##0.00', 'en');
  static final NumberFormat _qty = NumberFormat('#,##0.##', 'en');

  static DateFormat? _date, _dateTime, _time, _dayMonth;

  static DateFormat _fmt(String pattern) =>
      DateFormat(pattern, _locale)..useNativeDigits = false;

  static DateFormat get _dateF => _date ??= _fmt('d MMM yyyy');
  static DateFormat get _dateTimeF => _dateTime ??= _fmt('d MMM yyyy, HH:mm');
  static DateFormat get _timeF => _time ??= _fmt('HH:mm');
  static DateFormat get _dayMonthF => _dayMonth ??= _fmt('d MMM');

  /// The currency mark for the current language.
  static String get currency => _arabic ? 'ر.ق' : 'QAR';

  static String money(num? amount) {
    if (amount == null) return '—';
    final n = _money.format(amount);
    return _arabic ? '$n $currency' : '$currency $n';
  }

  /// Without the currency mark, for columns that already say QAR.
  static String amount(num? value) =>
      value == null ? '—' : _money.format(value);

  /// A whole-riyal figure for headline numbers: "QAR 12,400".
  static String moneyShort(num? amount) {
    if (amount == null) return '—';
    final n = NumberFormat('#,##0', 'en').format(amount.round());
    return _arabic ? '$n $currency' : '$currency $n';
  }

  static String qty(num? value) => value == null ? '—' : _qty.format(value);

  static String date(DateTime? d) => d == null ? '—' : _dateF.format(d);

  /// "3 Feb" — for dense columns where the year is obvious.
  static String dayMonth(DateTime? d) => d == null ? '—' : _dayMonthF.format(d);

  static String dateTime(DateTime? d) => d == null ? '—' : _dateTimeF.format(d);

  static String time(DateTime? d) => d == null ? '—' : _timeF.format(d);
}
