// apps/api/tests/unit/status-calculator.test.ts
import { describe, it, expect } from 'vitest';
import { StatusCalculator } from '../../src/modules/ledger/domain/status-calculator.js';

describe('StatusCalculator Exhaustive Tests', () => {
  const referenceToday = '2026-11-26';

  describe('UPCOMING Status', () => {
    it('returns UPCOMING when obligation due date is strictly in future with zero allocations', () => {
      const result = StatusCalculator.calculate({
        dueDate: '2026-12-01',
        dueAmountMinor: 500000n,
        allocations: [],
        currentDateInZone: referenceToday,
      });

      expect(result.status).toBe('UPCOMING');
      expect(result.outstandingAmountMinor).toBe(500000n);
      expect(result.allocatedAmountMinor).toBe(0n);
      expect(result.isOverdue).toBe(false);
    });

    it('returns UPCOMING when obligation is due today and not yet past due', () => {
      const result = StatusCalculator.calculate({
        dueDate: referenceToday,
        dueAmountMinor: 100000n,
        allocations: [],
        currentDateInZone: referenceToday,
      });

      expect(result.status).toBe('UPCOMING');
      expect(result.isOverdue).toBe(false);
      expect(result.outstandingAmountMinor).toBe(100000n);
    });
  });

  describe('UNPAID_OVERDUE Status', () => {
    it('returns UNPAID_OVERDUE when due date is in past and zero payments received', () => {
      const result = StatusCalculator.calculate({
        dueDate: '2026-11-25', // Yesterday
        dueAmountMinor: 200000n,
        allocations: [],
        currentDateInZone: referenceToday,
      });

      expect(result.status).toBe('UNPAID_OVERDUE');
      expect(result.outstandingAmountMinor).toBe(200000n);
      expect(result.allocatedAmountMinor).toBe(0n);
      expect(result.isOverdue).toBe(true);
    });

    it('returns UNPAID_OVERDUE for obligations from months ago', () => {
      const result = StatusCalculator.calculate({
        dueDate: '2026-08-01',
        dueAmountMinor: 150000n,
        allocations: [],
        currentDateInZone: referenceToday,
      });

      expect(result.status).toBe('UNPAID_OVERDUE');
      expect(result.isOverdue).toBe(true);
    });
  });

  describe('PAID_ON_TIME Status', () => {
    it('returns PAID_ON_TIME when fully covered days before due date', () => {
      const result = StatusCalculator.calculate({
        dueDate: '2026-11-30',
        dueAmountMinor: 250000n,
        allocations: [
          {
            amountMinor: 250000n,
            receivedAt: '2026-11-20T10:00:00Z',
          },
        ],
        currentDateInZone: referenceToday,
      });

      expect(result.status).toBe('PAID_ON_TIME');
      expect(result.outstandingAmountMinor).toBe(0n);
      expect(result.allocatedAmountMinor).toBe(250000n);
      expect(result.isOverdue).toBe(false);
    });

    it('returns PAID_ON_TIME when paid on the exact due date', () => {
      const result = StatusCalculator.calculate({
        dueDate: '2026-11-20',
        dueAmountMinor: 100000n,
        allocations: [
          {
            amountMinor: 100000n,
            receivedAt: '2026-11-20T17:00:00+05:45',
          },
        ],
        currentDateInZone: referenceToday,
      });

      expect(result.status).toBe('PAID_ON_TIME');
      expect(result.outstandingAmountMinor).toBe(0n);
      expect(result.isOverdue).toBe(false);
    });

    it('returns PAID_ON_TIME when settled by multiple payments all on or before due date', () => {
      const result = StatusCalculator.calculate({
        dueDate: '2026-11-20',
        dueAmountMinor: 100000n,
        allocations: [
          {
            amountMinor: 60000n,
            receivedAt: '2026-11-18T10:00:00Z',
          },
          {
            amountMinor: 40000n,
            receivedAt: '2026-11-20T14:00:00+05:45',
          },
        ],
        currentDateInZone: referenceToday,
      });

      expect(result.status).toBe('PAID_ON_TIME');
      expect(result.outstandingAmountMinor).toBe(0n);
      expect(result.allocatedAmountMinor).toBe(100000n);
    });
  });

  describe('PAID_LATE Status', () => {
    it('returns PAID_LATE when paid in full 1 day after due date', () => {
      const result = StatusCalculator.calculate({
        dueDate: '2026-11-20',
        dueAmountMinor: 200000n,
        allocations: [
          {
            amountMinor: 200000n,
            receivedAt: '2026-11-21T09:00:00+05:45',
          },
        ],
        currentDateInZone: referenceToday,
      });

      expect(result.status).toBe('PAID_LATE');
      expect(result.outstandingAmountMinor).toBe(0n);
      expect(result.isOverdue).toBe(false); // Fully settled, so no remaining overdue
    });

    it('returns PAID_LATE when initial payment is on-time but completion payment is late', () => {
      const result = StatusCalculator.calculate({
        dueDate: '2026-11-10',
        dueAmountMinor: 200000n,
        allocations: [
          {
            amountMinor: 100000n,
            receivedAt: '2026-11-09T10:00:00Z', // On time partial
          },
          {
            amountMinor: 100000n,
            receivedAt: '2026-11-22T10:00:00+05:45', // Late completion
          },
        ],
        currentDateInZone: referenceToday,
      });

      expect(result.status).toBe('PAID_LATE');
      expect(result.outstandingAmountMinor).toBe(0n);
      expect(result.allocatedAmountMinor).toBe(200000n);
    });
  });

  describe('PARTIALLY_PAID Status', () => {
    it('returns PARTIALLY_PAID before due date with visible remainder', () => {
      const result = StatusCalculator.calculate({
        dueDate: '2026-11-30', // Future
        dueAmountMinor: 100000n,
        allocations: [
          {
            amountMinor: 40000n,
            receivedAt: '2026-11-20T10:00:00Z',
          },
        ],
        currentDateInZone: referenceToday,
      });

      expect(result.status).toBe('PARTIALLY_PAID');
      expect(result.allocatedAmountMinor).toBe(40000n);
      expect(result.outstandingAmountMinor).toBe(60000n);
      expect(result.isOverdue).toBe(false); // Not past due date yet
    });

    it('returns PARTIALLY_PAID after due date with isOverdue=true', () => {
      const result = StatusCalculator.calculate({
        dueDate: '2026-11-15', // Past
        dueAmountMinor: 100000n,
        allocations: [
          {
            amountMinor: 40000n,
            receivedAt: '2026-11-15T10:00:00Z',
          },
        ],
        currentDateInZone: referenceToday,
      });

      expect(result.status).toBe('PARTIALLY_PAID');
      expect(result.allocatedAmountMinor).toBe(40000n);
      expect(result.outstandingAmountMinor).toBe(60000n);
      expect(result.isOverdue).toBe(true);
    });
  });

  describe('Complex Arrears & Reversal Scenarios', () => {
    it('handles 5 missed dues fully covered on the 26th', () => {
      const missedDueDates = [
        '2026-11-01',
        '2026-11-05',
        '2026-11-10',
        '2026-11-15',
        '2026-11-20',
      ];
      const receivedDate = '2026-11-26T14:30:00+05:45';

      for (const dueDate of missedDueDates) {
        const state = StatusCalculator.calculate({
          dueDate,
          dueAmountMinor: 200000n,
          allocations: [
            {
              amountMinor: 200000n,
              receivedAt: receivedDate,
            },
          ],
          currentDateInZone: '2026-11-26',
        });

        expect(state.status).toBe('PAID_LATE');
        expect(state.outstandingAmountMinor).toBe(0n);
        expect(state.allocatedAmountMinor).toBe(200000n);
      }
    });

    it('handles 5 missed dues where lump sum only covers first 3 fully and 4th partially', () => {
      const dues = [
        { date: '2026-11-01', allocated: 200000n, expectedStatus: 'PAID_LATE' },
        { date: '2026-11-05', allocated: 200000n, expectedStatus: 'PAID_LATE' },
        { date: '2026-11-10', allocated: 200000n, expectedStatus: 'PAID_LATE' },
        { date: '2026-11-15', allocated: 75000n, expectedStatus: 'PARTIALLY_PAID' },
        { date: '2026-11-20', allocated: 0n, expectedStatus: 'UNPAID_OVERDUE' },
      ];

      for (const item of dues) {
        const state = StatusCalculator.calculate({
          dueDate: item.date,
          dueAmountMinor: 200000n,
          allocations:
            item.allocated > 0n
              ? [{ amountMinor: item.allocated, receivedAt: '2026-11-26T12:00:00+05:45' }]
              : [],
          currentDateInZone: '2026-11-26',
        });

        expect(state.status).toBe(item.expectedStatus);
        if (item.expectedStatus === 'PARTIALLY_PAID') {
          expect(state.outstandingAmountMinor).toBe(125000n);
          expect(state.isOverdue).toBe(true);
        } else if (item.expectedStatus === 'UNPAID_OVERDUE') {
          expect(state.outstandingAmountMinor).toBe(200000n);
          expect(state.isOverdue).toBe(true);
        } else {
          expect(state.outstandingAmountMinor).toBe(0n);
        }
      }
    });

    it('recalculates back to UNPAID_OVERDUE when collection is reversed', () => {
      // Prior state: paid
      const paidState = StatusCalculator.calculate({
        dueDate: '2026-11-10',
        dueAmountMinor: 100000n,
        allocations: [{ amountMinor: 100000n, receivedAt: '2026-11-10T10:00:00Z' }],
        currentDateInZone: referenceToday,
      });
      expect(paidState.status).toBe('PAID_ON_TIME');

      // Reversal: allocation removed
      const reversedState = StatusCalculator.calculate({
        dueDate: '2026-11-10',
        dueAmountMinor: 100000n,
        allocations: [], // Zero allocations after reversal
        currentDateInZone: referenceToday,
      });
      expect(reversedState.status).toBe('UNPAID_OVERDUE');
      expect(reversedState.outstandingAmountMinor).toBe(100000n);
      expect(reversedState.isOverdue).toBe(true);
    });
  });
});
