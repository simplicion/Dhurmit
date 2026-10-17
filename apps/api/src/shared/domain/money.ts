// shared/domain/money.ts
// Money value object enforcing integer minor units (NPR paisa) and strictly no floating-point math.

import { DomainError } from './errors.js';

export class Money {
  readonly minorUnits: bigint;
  readonly currencyCode: string;

  constructor(minorUnits: bigint | number, currencyCode: string = 'NPR') {
    if (typeof minorUnits === 'number') {
      if (!Number.isSafeInteger(minorUnits)) {
        throw new DomainError('VALIDATION_ERROR', 'Money minor units must be a safe integer');
      }
      this.minorUnits = BigInt(minorUnits);
    } else {
      this.minorUnits = minorUnits;
    }
    this.currencyCode = currencyCode.toUpperCase();
  }

  static fromPaisa(paisa: number | bigint): Money {
    return new Money(paisa, 'NPR');
  }

  static fromRupees(rupees: number, currencyCode: string = 'NPR'): Money {
    // 1 NPR = 100 paisa
    const paisa = Math.round(rupees * 100);
    return new Money(paisa, currencyCode);
  }

  static zero(currencyCode: string = 'NPR'): Money {
    return new Money(0n, currencyCode);
  }

  add(other: Money): Money {
    this.assertSameCurrency(other);
    return new Money(this.minorUnits + other.minorUnits, this.currencyCode);
  }

  subtract(other: Money): Money {
    this.assertSameCurrency(other);
    return new Money(this.minorUnits - other.minorUnits, this.currencyCode);
  }

  isZero(): boolean {
    return this.minorUnits === 0n;
  }

  isPositive(): boolean {
    return this.minorUnits > 0n;
  }

  isNegative(): boolean {
    return this.minorUnits < 0n;
  }

  equals(other: Money): boolean {
    return this.currencyCode === other.currencyCode && this.minorUnits === other.minorUnits;
  }

  isGreaterThan(other: Money): boolean {
    this.assertSameCurrency(other);
    return this.minorUnits > other.minorUnits;
  }

  isLessThan(other: Money): boolean {
    this.assertSameCurrency(other);
    return this.minorUnits < other.minorUnits;
  }

  toNumber(): number {
    return Number(this.minorUnits);
  }

  toDecimalString(): string {
    const isNeg = this.minorUnits < 0n;
    const abs = isNeg ? -this.minorUnits : this.minorUnits;
    const rupees = abs / 100n;
    const paisa = abs % 100n;
    const paddedPaisa = paisa.toString().padStart(2, '0');
    return `${isNeg ? '-' : ''}${rupees}.${paddedPaisa}`;
  }

  private assertSameCurrency(other: Money): void {
    if (this.currencyCode !== other.currencyCode) {
      throw new DomainError('VALIDATION_ERROR', `Currency mismatch: ${this.currencyCode} vs ${other.currencyCode}`);
    }
  }
}
