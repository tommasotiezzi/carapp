import 'package:intl/intl.dart';

/// Italian formatting for prices, km and vehicle data.
/// Enum labels (fuel, transmission) live in the ARB: see `VehicleLabels`.
class Formatters {
  Formatters._();

  static final _number = NumberFormat.decimalPattern('it_IT');

  /// 1490000 cents -> "€ 14.900"
  static String price(int? cents) =>
      cents == null ? '' : '€ ${_number.format(cents ~/ 100)}';

  /// 78400 -> "78.400 km"
  static String km(int? km) => km == null ? '' : '${_number.format(km)} km';

  /// "1 ott 2026" (day, short month, year) in the app's locale.
  static String date(DateTime d) => DateFormat.yMMMd('it').format(d);

  /// "14:32"
  static String time(DateTime d) => DateFormat.Hm('it').format(d);

  /// Inbox row: "14:32" today, [yesterday] ("Ieri"), weekday ("lun")
  /// within a week, then "12/09/26".
  static String chatListTime(DateTime d, {required String yesterday, DateTime? now}) {
    final today = _day(now ?? DateTime.now());
    final days = today.difference(_day(d)).inDays;
    if (days <= 0) return time(d);
    if (days == 1) return yesterday;
    if (days < 7) return DateFormat.E('it').format(d);
    return DateFormat('dd/MM/yy', 'it').format(d);
  }

  /// Midnight of [d] (local), for "same day" checks.
  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool sameDay(DateTime a, DateTime b) => _day(a) == _day(b);

  /// kW -> CV, rounded
  static String horsepower(int? kw) =>
      kw == null ? '' : '${(kw * 1.35962).round()} CV';

  /// "AB" from "Auto Bianchi"
  static String initials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    final first = parts.first.substring(0, 1);
    final second = parts.length > 1 ? parts[1].substring(0, 1) : '';
    return (first + second).toUpperCase();
  }
}
