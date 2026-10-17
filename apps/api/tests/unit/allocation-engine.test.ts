// apps/api/tests/unit/allocation-engine.test.ts
import { describe, it, expect } from 'vitest';
import {
  AllocationEngine,
  ObligationCandidate,
} from '../../src/modules/ledger/domain/allocation-engine.js';
import { DomainError } from '../../src/shared/domain/errors.js';

describe('AllocationEngine Exhaustive Domain Tests', () => {
  const dummyObligations: ObligationCandidate[] = [
    {
      id: 'ob-1',
      dueDate: '2026-11-01',
      dueAmountMinor: 200000n, // NPR 2000
      alreadyAllocatedMinor: 0n,
      remainingAmountMinor: 200000n,
    },
    {
      id: 'ob-2',
      dueDate: '2026-11-05',
      dueAmountMinor: 200000n,
      alreadyAllocatedMinor: 0n,
      remainingAmountMinor: 200000n,
    },
    {
      id: 'ob-3',
      dueDate: '2026-11-10',
      dueAmountMinor: 200000n,
      alreadyAllocatedMinor: 0n,
      remainingAmountMinor: 200000n,
    },
    {
      id: 'ob-4',
      dueDate: '2026-11-15',
      dueAmountMinor: 200000n,
      alreadyAllocatedMinor: 50000n, // partially paid before
      remainingAmountMinor: 150000n, // NPR 1500 remaining
    },
    {
      id: 'ob-5',
      dueDate: '2026-11-20',
      dueAmountMinor: 200000n,
      alreadyAllocatedMinor: 0n,
      remainingAmountMinor: 200000n,
    },
  ];

  describe('Validation & Invariants', () => {
    it('rejects zero collection amounts', () => {
      expect(() =>
        AllocationEngine.computeAllocations({
          collectionAmountMinor: 0n,
          obligations: dummyObligations,
        })
      ).toThrow(DomainError);
    });

    it('rejects negative collection amounts', () => {
      expect(() =>
        AllocationEngine.computeAllocations({
          collectionAmountMinor: -50000n,
          obligations: dummyObligations,
        })
      ).toThrow(DomainError);
    });

    it('rejects manual allocation when allocation policy is MANUAL but no allocations provided', () => {
      expect(() =>
        AllocationEngine.computeAllocations({
          collectionAmountMinor: 200000n,
          obligations: dummyObligations,
          allocationPolicy: 'MANUAL',
        })
      ).toThrow(DomainError);
    });
  });

  describe('FIFO Oldest-First Allocation', () => {
    it('allocates collection exactly to the single oldest due obligation', () => {
      const res = AllocationEngine.computeAllocations({
        collectionAmountMinor: 200000n,
        obligations: dummyObligations,
      });

      expect(res.allocations).toHaveLength(1);
      expect(res.allocations[0]).toEqual({
        obligationId: 'ob-1',
        amountMinor: 200000n,
      });
      expect(res.totalAllocatedMinor).toBe(200000n);
      expect(res.unallocatedRemainderMinor).toBe(0n);
    });

    it('allocates collection across multiple obligations in chronological order (FIFO)', () => {
      // NPR 5000 (500000 paisa) covers ob-1 (200000), ob-2 (200000), and half of ob-3 (100000)
      const res = AllocationEngine.computeAllocations({
        collectionAmountMinor: 500000n,
        obligations: dummyObligations,
        allowPartialPayment: true,
      });

      expect(res.allocations).toEqual([
        { obligationId: 'ob-1', amountMinor: 200000n },
        { obligationId: 'ob-2', amountMinor: 200000n },
        { obligationId: 'ob-3', amountMinor: 100000n },
      ]);
      expect(res.totalAllocatedMinor).toBe(500000n);
      expect(res.unallocatedRemainderMinor).toBe(0n);
    });

    it('correctly accounts for obligations with existing partial payments in FIFO order', () => {
      // NPR 7500 (750000 paisa)
      // ob-1 takes 200000 -> 550000 left
      // ob-2 takes 200000 -> 350000 left
      // ob-3 takes 200000 -> 150000 left
      // ob-4 remaining is 150000 -> takes exact 150000 -> 0 left!
      const res = AllocationEngine.computeAllocations({
        collectionAmountMinor: 750000n,
        obligations: dummyObligations,
      });

      expect(res.allocations).toEqual([
        { obligationId: 'ob-1', amountMinor: 200000n },
        { obligationId: 'ob-2', amountMinor: 200000n },
        { obligationId: 'ob-3', amountMinor: 200000n },
        { obligationId: 'ob-4', amountMinor: 150000n },
      ]);
      expect(res.totalAllocatedMinor).toBe(750000n);
      expect(res.unallocatedRemainderMinor).toBe(0n);
    });

    it('rejects partial payment when allowPartialPayment is false and collection cannot cover obligation in full', () => {
      expect(() =>
        AllocationEngine.computeAllocations({
          collectionAmountMinor: 150000n, // ob-1 needs 200000n
          obligations: dummyObligations,
          allowPartialPayment: false,
        })
      ).toThrow(DomainError);
    });

    it('rejects overpayment when collection exceeds all open dues and allowUnallocatedCredit is false', () => {
      // Total open dues in dummy: 200000 + 200000 + 200000 + 150000 + 200000 = 950000 paisa
      expect(() =>
        AllocationEngine.computeAllocations({
          collectionAmountMinor: 1000000n, // 1,000,000 > 950,000
          obligations: dummyObligations,
          allowUnallocatedCredit: false,
        })
      ).toThrow(DomainError);
    });

    it('allows unallocated remainder when allowUnallocatedCredit is true', () => {
      const res = AllocationEngine.computeAllocations({
        collectionAmountMinor: 1000000n,
        obligations: dummyObligations,
        allowUnallocatedCredit: true,
      });

      expect(res.totalAllocatedMinor).toBe(950000n);
      expect(res.unallocatedRemainderMinor).toBe(50000n); // NPR 500 unallocated credit
      expect(res.allocations).toHaveLength(5);
    });

    it('skips obligations that already have 0 remaining amount', () => {
      const withZeroRemaining: ObligationCandidate[] = [
        {
          id: 'ob-already-paid',
          dueDate: '2026-10-01',
          dueAmountMinor: 200000n,
          alreadyAllocatedMinor: 200000n,
          remainingAmountMinor: 0n,
        },
        ...dummyObligations,
      ];

      const res = AllocationEngine.computeAllocations({
        collectionAmountMinor: 200000n,
        obligations: withZeroRemaining,
      });

      expect(res.allocations[0].obligationId).toBe('ob-1');
    });
  });

  describe('Manual Allocation Rules', () => {
    it('accepts explicit manual allocations targeting specific obligations', () => {
      const res = AllocationEngine.computeAllocations({
        collectionAmountMinor: 400000n,
        obligations: dummyObligations,
        manualAllocations: [
          { obligationId: 'ob-2', amountMinor: 200000n },
          { obligationId: 'ob-5', amountMinor: 200000n },
        ],
      });

      expect(res.allocations).toEqual([
        { obligationId: 'ob-2', amountMinor: 200000n },
        { obligationId: 'ob-5', amountMinor: 200000n },
      ]);
      expect(res.totalAllocatedMinor).toBe(400000n);
      expect(res.unallocatedRemainderMinor).toBe(0n);
    });

    it('rejects manual allocation targeting obligation not in candidates', () => {
      expect(() =>
        AllocationEngine.computeAllocations({
          collectionAmountMinor: 200000n,
          obligations: dummyObligations,
          manualAllocations: [
            { obligationId: 'non-existent-or-other-member', amountMinor: 200000n },
          ],
        })
      ).toThrow(DomainError);
    });

    it('rejects manual allocation with zero or negative amount', () => {
      expect(() =>
        AllocationEngine.computeAllocations({
          collectionAmountMinor: 200000n,
          obligations: dummyObligations,
          manualAllocations: [{ obligationId: 'ob-1', amountMinor: 0n }],
        })
      ).toThrow(DomainError);
    });

    it('rejects manual allocation exceeding remaining due of target obligation', () => {
      // ob-4 has remainingAmountMinor 150000n
      expect(() =>
        AllocationEngine.computeAllocations({
          collectionAmountMinor: 200000n,
          obligations: dummyObligations,
          manualAllocations: [{ obligationId: 'ob-4', amountMinor: 200000n }],
        })
      ).toThrow(DomainError);
    });

    it('rejects manual allocations whose sum exceeds collection amount', () => {
      expect(() =>
        AllocationEngine.computeAllocations({
          collectionAmountMinor: 200000n,
          obligations: dummyObligations,
          manualAllocations: [
            { obligationId: 'ob-1', amountMinor: 150000n },
            { obligationId: 'ob-2', amountMinor: 150000n },
          ],
        })
      ).toThrow(DomainError);
    });

    it('rejects manual allocations where sum is less than collection and unallocated credit is disallowed', () => {
      expect(() =>
        AllocationEngine.computeAllocations({
          collectionAmountMinor: 200000n,
          obligations: dummyObligations,
          manualAllocations: [{ obligationId: 'ob-1', amountMinor: 150000n }],
          allowUnallocatedCredit: false,
        })
      ).toThrow(DomainError);
    });

    it('allows manual partial payment when allowPartialPayment is true', () => {
      const res = AllocationEngine.computeAllocations({
        collectionAmountMinor: 100000n,
        obligations: dummyObligations,
        manualAllocations: [{ obligationId: 'ob-1', amountMinor: 100000n }],
        allowPartialPayment: true,
      });

      expect(res.allocations).toEqual([{ obligationId: 'ob-1', amountMinor: 100000n }]);
      expect(res.totalAllocatedMinor).toBe(100000n);
    });

    it('rejects manual partial payment when allowPartialPayment is false', () => {
      expect(() =>
        AllocationEngine.computeAllocations({
          collectionAmountMinor: 100000n,
          obligations: dummyObligations,
          manualAllocations: [{ obligationId: 'ob-1', amountMinor: 100000n }],
          allowPartialPayment: false,
        })
      ).toThrow(DomainError);
    });
  });
});
