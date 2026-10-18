import 'package:intl/intl.dart';

class AppMoney {
  static String activeCurrencyCode = 'NPR';
  static String activeLocale = 'en_IN';

  final BigInt minorUnits;
  final String currencyCode;

  AppMoney(this.minorUnits, {String? currencyCode})
      : currencyCode = currencyCode ?? activeCurrencyCode;

  static AppMoney fromPaisa(dynamic paisa, {String? currencyCode}) {
    final code = currencyCode ?? activeCurrencyCode;
    if (paisa is BigInt) return AppMoney(paisa, currencyCode: code);
    if (paisa is int) return AppMoney(BigInt.from(paisa), currencyCode: code);
    if (paisa is String) {
      return AppMoney(BigInt.tryParse(paisa) ?? BigInt.zero, currencyCode: code);
    }
    return AppMoney(BigInt.zero, currencyCode: code);
  }

  static AppMoney fromRupees(double rupees, {String? currencyCode}) {
    final code = currencyCode ?? activeCurrencyCode;
    final paisa = (rupees * 100).round();
    return AppMoney(BigInt.from(paisa), currencyCode: code);
  }

  static AppMoney fromRupeesString(String val, {String? currencyCode}) {
    final code = currencyCode ?? activeCurrencyCode;
    final trimmed = val.trim();
    if (trimmed.isEmpty) return AppMoney(BigInt.zero, currencyCode: code);
    final parsed = double.tryParse(trimmed) ?? 0.0;
    return fromRupees(parsed, currencyCode: code);
  }

  double toRupees() {
    return minorUnits.toInt() / 100.0;
  }

  double get rupees => toRupees();

  bool get isZero => minorUnits == BigInt.zero;
  bool get isPositive => minorUnits > BigInt.zero;
  bool get isNegative => minorUnits < BigInt.zero;

  AppMoney operator +(AppMoney other) {
    return AppMoney(minorUnits + other.minorUnits, currencyCode: currencyCode);
  }

  AppMoney operator -(AppMoney other) {
    return AppMoney(minorUnits - other.minorUnits, currencyCode: currencyCode);
  }

  bool operator >(AppMoney other) => minorUnits > other.minorUnits;
  bool operator <(AppMoney other) => minorUnits < other.minorUnits;
  bool operator >=(AppMoney other) => minorUnits >= other.minorUnits;
  bool operator <=(AppMoney other) => minorUnits <= other.minorUnits;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppMoney &&
          runtimeType == other.runtimeType &&
          minorUnits == other.minorUnits &&
          currencyCode == other.currencyCode;

  @override
  int get hashCode => minorUnits.hashCode ^ currencyCode.hashCode;

  String format() {
    final isNegative = minorUnits < BigInt.zero;
    final absUnits = isNegative ? -minorUnits : minorUnits;

    final rupees = absUnits ~/ BigInt.from(100);
    final paisa = (absUnits % BigInt.from(100)).toInt();

    final formatter = NumberFormat('#,##,##0', activeLocale);
    final formattedRupees = formatter.format(rupees.toInt());
    final formattedPaisa = paisa.toString().padLeft(2, '0');

    final sign = isNegative ? '-' : '';
    return '$sign$currencyCode $formattedRupees.$formattedPaisa';
  }

  String formatShort() {
    final isNegative = minorUnits < BigInt.zero;
    final absUnits = isNegative ? -minorUnits : minorUnits;
    final rupees = (absUnits ~/ BigInt.from(100)).toInt();
    final formatter = NumberFormat('#,##,##0', activeLocale);
    final sign = isNegative ? '-' : '';
    return '$sign$currencyCode ${formatter.format(rupees)}';
  }
}
