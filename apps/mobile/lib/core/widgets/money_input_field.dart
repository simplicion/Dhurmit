import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/theme_provider.dart';

class MoneyInputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final ValueChanged<BigInt>? onChangedPaisa;
  final String? Function(String?)? validator;

  const MoneyInputField({
    super.key,
    required this.controller,
    this.label = 'Amount (NPR)',
    this.hint = '0.00',
    this.onChangedPaisa,
    this.validator,
  });

  static BigInt parseToPaisa(String text) {
    final cleaned = text.trim().replaceAll(',', '');
    if (cleaned.isEmpty) return BigInt.zero;
    final parts = cleaned.split('.');
    final rupees = BigInt.tryParse(parts[0]) ?? BigInt.zero;
    var paisa = 0;
    if (parts.length > 1) {
      final pStr = parts[1].padRight(2, '0').substring(0, 2);
      paisa = int.tryParse(pStr) ?? 0;
    }
    return (rupees * BigInt.from(100)) + BigInt.from(paisa);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.watch<ThemeProvider>().tokens;

    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
      ],
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: tokens.onSurface,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: 'Rs. ',
        prefixStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: tokens.primary,
        ),
        filled: true,
        fillColor: tokens.surfaceVariant.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: tokens.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: tokens.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: tokens.primary, width: 2),
        ),
      ),
      onChanged: (val) {
        if (onChangedPaisa != null) {
          onChangedPaisa!(parseToPaisa(val));
        }
      },
      validator: validator,
    );
  }
}
