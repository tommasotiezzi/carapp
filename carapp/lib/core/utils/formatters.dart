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
