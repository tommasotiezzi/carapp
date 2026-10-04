import 'package:flutter/services.dart';

/// "1234567" -> "1.234.567" while typing.
class ThousandsFormatter extends TextInputFormatter {
  const ThousandsFormatter();

  static String format(int value) =>
      value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');

  static int? parse(String text) => int.tryParse(text.replaceAll(RegExp(r'\D'), ''));

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final text = format(int.parse(digits.length > 12 ? digits.substring(0, 12) : digits));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
