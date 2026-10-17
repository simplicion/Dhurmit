import 'package:flutter_test/flutter_test.dart';
import 'package:committee_ledger_mobile/core/money/app_money.dart';

void main() {
  group('AppMoney Value Object Tests', () {
    test('formats paisa to NPR currency string correctly', () {
      final money = AppMoney.fromPaisa(100000); // NPR 1,000.00
      expect(money.format(), equals('NPR 1,000.00'));
      expect(money.formatShort(), equals('NPR 1,000'));
      expect(money.rupees, equals(1000.0));
      expect(money.minorUnits, equals(BigInt.from(100000)));
    });

    test('handles small paisa amounts without precision loss', () {
      final money = AppMoney.fromPaisa(50); // 50 paisa = 0.50 rupees
      expect(money.format(), equals('NPR 0.50'));
      expect(money.formatShort(), equals('NPR 0'));
      expect(money.minorUnits, equals(BigInt.from(50)));
    });

    test('handles single digit paisa amounts with leading zero', () {
      final money = AppMoney.fromPaisa(7); // 7 paisa = 0.07 rupees
      expect(money.format(), equals('NPR 0.07'));
      expect(money.minorUnits, equals(BigInt.from(7)));
    });

    test('parses rupees to paisa accurately without floating point drift', () {
      final money = AppMoney.fromRupeesString('1500.75');
      expect(money.minorUnits, equals(BigInt.from(150075)));
      expect(money.format(), equals('NPR 1,500.75'));
    });

    test('handles empty or invalid string parsing gracefully to zero', () {
      expect(AppMoney.fromRupeesString('').isZero, isTrue);
      expect(AppMoney.fromRupeesString('   ').isZero, isTrue);
      expect(AppMoney.fromRupeesString('invalid-amount').isZero, isTrue);
    });

    test('handles string paisa parsing', () {
      final money = AppMoney.fromPaisa('250000');
      expect(money.minorUnits, equals(BigInt.from(250000)));
      expect(money.format(), equals('NPR 2,500.00'));
    });

    test('arithmetic operations preserve exact integer minor units', () {
      final a = AppMoney.fromPaisa(100000); // 1,000
      final b = AppMoney.fromPaisa(50025); // 500.25
      final sum = a + b;
      expect(sum.minorUnits, equals(BigInt.from(150025)));

      final diff = a - b;
      expect(diff.minorUnits, equals(BigInt.from(49975)));
    });

    test('handles subtraction yielding negative amounts', () {
      final small = AppMoney.fromPaisa(200);
      final big = AppMoney.fromPaisa(500);
      final result = small - big;

      expect(result.minorUnits, equals(BigInt.from(-300)));
      expect(result.isNegative, isTrue);
      expect(result.isPositive, isFalse);
      expect(result.format(), equals('-NPR 3.00'));
    });

    test('evaluates isZero, isPositive, isNegative correctly', () {
      final zero = AppMoney.fromPaisa(0);
      final positive = AppMoney.fromPaisa(100);
      final negative = AppMoney.fromPaisa(-100);

      expect(zero.isZero, isTrue);
      expect(zero.isPositive, isFalse);
      expect(zero.isNegative, isFalse);

      expect(positive.isZero, isFalse);
      expect(positive.isPositive, isTrue);
      expect(positive.isNegative, isFalse);

      expect(negative.isZero, isFalse);
      expect(negative.isPositive, isFalse);
      expect(negative.isNegative, isTrue);
    });

    test('evaluates comparison operators correctly', () {
      final a = AppMoney.fromPaisa(10000);
      final b = AppMoney.fromPaisa(20000);
      final c = AppMoney.fromPaisa(10000);

      expect(b > a, isTrue);
      expect(a < b, isTrue);
      expect(a <= b, isTrue);
      expect(b >= a, isTrue);
      expect(a >= c, isTrue);
      expect(a <= c, isTrue);
      expect(a == c, isTrue);
      expect(a == b, isFalse);
    });

    test('formats large sums with Indian thousand and lakh separators', () {
      final money = AppMoney.fromPaisa(150000000); // 15 Lakh NPR = 1,500,000.00
      expect(money.format(), equals('NPR 15,00,000.00'));
      expect(money.formatShort(), equals('NPR 15,00,000'));
    });

    test('handles BigInt input directly in fromPaisa', () {
      final money = AppMoney.fromPaisa(BigInt.from(750000));
      expect(money.minorUnits, equals(BigInt.from(750000)));
      expect(money.format(), equals('NPR 7,500.00'));
    });
  });
}
