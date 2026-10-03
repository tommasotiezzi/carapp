import 'package:intl/intl.dart';

/// Italian formatting for prices, km and vehicle data.
class Formatters {
  Formatters._();

  static final _number = NumberFormat.decimalPattern('it_IT');

  /// 1490000 cents -> "€ 14.900"
  static String price(int? cents) =>
      cents == null ? '' : '€ ${_number.format(cents ~/ 100)}';

  /// 78400 -> "78.400 km"
  static String km(int? km) => km == null ? '' : '${_number.format(km)} km';

  /// kW -> CV, rounded
  static String horsepower(int? kw) =>
      kw == null ? '' : '${(kw * 1.35962).round()} CV';

  static String fuel(String? dbValue) => switch (dbValue) {
        'petrol' => 'Benzina',
        'diesel' => 'Diesel',
        'hybrid' => 'Ibrida',
        'plugin_hybrid' => 'Ibrida plug-in',
        'electric' => 'Elettrica',
        'lpg' => 'GPL',
        'cng' => 'Metano',
        'other' => 'Altro',
        _ => '',
      };

  /// "AB" from "Auto Bianchi"
  static String initials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    final first = parts.first.substring(0, 1);
    final second = parts.length > 1 ? parts[1].substring(0, 1) : '';
    return (first + second).toUpperCase();
  }
}
