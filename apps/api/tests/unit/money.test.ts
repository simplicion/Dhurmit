// apps/api/tests/unit/money.test.ts
import { describe, it, expect } from 'vitest';
import { Money } from '../../src/shared/domain/money.js';
import { DomainError } from '../../src/shared/domain/errors.js';

describe('Money Value Object Exhaustive Tests', () => {
  describe('Instantiation & Factory methods', () => {
    it('creates money from positive bigint paisa', () => {
      const m = Money.fromPaisa(1200000n);
      expect(m.minorUnits).toBe(1200000n);
      expect(m.currencyCode).toBe('NPR');
      expect(m.toDecimalString()).toBe('12000.00');
    });

    it('creates money from safe integer number', () => {
      const m = new Money(5000);
      expect(m.minorUnits).toBe(5000n);
      expect(m.toDecimalString()).toBe('50.00');
    });

    it('throws DomainError when constructed with unsafe/fractional number', () => {
      expect(() => new Money(123.45)).toThrow(DomainError);
      expect(() => new Money(Number.MAX_SAFE_INTEGER + 100)).toThrow(DomainError);
    });

    it('creates zero money correctly', () => {
      const zero = Money.zero();
      expect(zero.minorUnits).toBe(0n);
      expect(zero.isZero()).toBe(true);
      expect(zero.isPositive()).toBe(false);
      expect(zero.isNegative()).toBe(false);
      expect(zero.toDecimalString()).toBe('0.00');
    });

    it('creates money from rupees accurately', () => {
      const m = Money.fromRupees(150.75);
      expect(m.minorUnits).toBe(15075n);
      expect(m.toDecimalString()).toBe('150.75');
    });

    it('handles negative minor units properly', () => {
      const neg = new Money(-500n);
      expect(neg.minorUnits).toBe(-500n);
      expect(neg.isNegative()).toBe(true);
      expect(neg.isPositive()).toBe(false);
      expect(neg.isZero()).toBe(false);
      expect(neg.toDecimalString()).toBe('-5.00');
    });

    it('supports custom currency codes and normalizes to uppercase', () => {
      const usd = new Money(2500n, 'usd');
      expect(usd.currencyCode).toBe('USD');
      expect(usd.toDecimalString()).toBe('25.00');
    });
  });

  describe('Decimal Formatting & Precision', () => {
    it('formats single digit paisa with leading zero', () => {
      const m = Money.fromPaisa(7n);
      expect(m.toDecimalString()).toBe('0.07');
    });

    it('formats negative single digit paisa with leading zero', () => {
      const m = Money.fromPaisa(-9n);
      expect(m.toDecimalString()).toBe('-0.09');
    });

    it('formats double digit paisa without extra zeros', () => {
      const m = Money.fromPaisa(45n);
      expect(m.toDecimalString()).toBe('0.45');
    });

    it('formats exact hundreds without fractional paisa', () => {
      const m = Money.fromPaisa(10000n);
      expect(m.toDecimalString()).toBe('100.00');
    });

    it('formats massive financial amounts without scientific notation', () => {
      const large = Money.fromPaisa(10000000000000n); // NPR 100,000,000,000.00
      expect(large.toDecimalString()).toBe('100000000000.00');
    });
  });

  describe('Arithmetic Operations', () => {
    it('performs exact addition of multiple paisa amounts', () => {
      const m1 = Money.fromPaisa(200050n); // NPR 2000.50
      const m2 = Money.fromPaisa(100025n); // NPR 1000.25
      const sum = m1.add(m2);

      expect(sum.minorUnits).toBe(300075n);
      expect(sum.toDecimalString()).toBe('3000.75');
    });

    it('performs exact subtraction without precision loss', () => {
      const m1 = Money.fromPaisa(50000n);
      const m2 = Money.fromPaisa(12550n);
      const diff = m1.subtract(m2);

      expect(diff.minorUnits).toBe(37450n);
      expect(diff.toDecimalString()).toBe('374.50');
    });

    it('subtracting to negative returns correct negative money', () => {
      const small = Money.fromPaisa(100n);
      const big = Money.fromPaisa(350n);
      const result = small.subtract(big);

      expect(result.minorUnits).toBe(-250n);
      expect(result.isNegative()).toBe(true);
      expect(result.toDecimalString()).toBe('-2.50');
    });

    it('adding zero preserves identity', () => {
      const m = Money.fromPaisa(9999n);
      const result = m.add(Money.zero());
      expect(result.equals(m)).toBe(true);
    });

    it('subtracting identical amount returns zero', () => {
      const m = Money.fromPaisa(4321n);
      const diff = m.subtract(m);
      expect(diff.isZero()).toBe(true);
      expect(diff.minorUnits).toBe(0n);
    });

    it('rejects addition with currency mismatch', () => {
      const npr = new Money(1000n, 'NPR');
      const inr = new Money(1000n, 'INR');
      expect(() => npr.add(inr)).toThrow(DomainError);
    });

    it('rejects subtraction with currency mismatch', () => {
      const npr = new Money(1000n, 'NPR');
      const eur = new Money(1000n, 'EUR');
      expect(() => npr.subtract(eur)).toThrow(DomainError);
    });
  });

  describe('Comparison Operators', () => {
    it('evaluates equality correctly', () => {
      const a = Money.fromPaisa(1500n);
      const b = Money.fromPaisa(1500n);
      const c = Money.fromPaisa(1501n);
      const diffCurrency = new Money(1500n, 'USD');

      expect(a.equals(b)).toBe(true);
      expect(a.equals(c)).toBe(false);
      expect(a.equals(diffCurrency)).toBe(false);
    });

    it('evaluates isGreaterThan correctly', () => {
      const low = Money.fromPaisa(100n);
      const high = Money.fromPaisa(200n);

      expect(high.isGreaterThan(low)).toBe(true);
      expect(low.isGreaterThan(high)).toBe(false);
      expect(low.isGreaterThan(low)).toBe(false);
    });

    it('evaluates isLessThan correctly', () => {
      const low = Money.fromPaisa(100n);
      const high = Money.fromPaisa(200n);

      expect(low.isLessThan(high)).toBe(true);
      expect(high.isLessThan(low)).toBe(false);
      expect(high.isLessThan(high)).toBe(false);
    });

    it('rejects comparisons between different currencies', () => {
      const m1 = new Money(100n, 'NPR');
      const m2 = new Money(100n, 'USD');

      expect(() => m1.isGreaterThan(m2)).toThrow(DomainError);
      expect(() => m1.isLessThan(m2)).toThrow(DomainError);
    });

    it('converts to number safely within safe integer bounds', () => {
      const m = Money.fromPaisa(987654n);
      expect(m.toNumber()).toBe(987654);
    });
  });
});
