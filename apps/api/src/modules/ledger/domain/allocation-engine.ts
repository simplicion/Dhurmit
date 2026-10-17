// modules/ledger/domain/allocation-engine.ts
// Pure domain allocation engine for collections, obligations, and partial/FIFO policies.

import { DomainError } from '../../../shared/domain/errors.js';

export interface ObligationCandidate {
  id: string;
  dueDate: string;
  dueAmountMinor: bigint;
  alreadyAllocatedMinor: bigint;
  remainingAmountMinor: bigint;
  memberId?: string;
  committeeId?: string;
}

export interface RequestedAllocation {
  obligationId: string;
  amountMinor: bigint;
}

export interface AllocationEngineParams {
  collectionAmountMinor: bigint;
  obligations: ObligationCandidate[];
  manualAllocations?: RequestedAllocation[];
  allowPartialPayment?: boolean;
  allowUnallocatedCredit?: boolean;
  allocationPolicy?: 'FIFO_OLDEST_FIRST' | 'MANUAL';
}

export interface AllocationEngineResult {
  allocations: {
    obligationId: string;
    amountMinor: bigint;
  }[];
  unallocatedRemainderMinor: bigint;
  totalAllocatedMinor: bigint;
}

export class AllocationEngine {
  static computeAllocations(params: AllocationEngineParams): AllocationEngineResult {
    const {
      collectionAmountMinor,
      obligations,
      manualAllocations,
      allowPartialPayment = true,
      allowUnallocatedCredit = false,
      allocationPolicy = 'FIFO_OLDEST_FIRST',
    } = params;

    if (collectionAmountMinor <= 0n) {
      throw new DomainError('VALIDATION_ERROR', 'Collection amount must be positive');
    }

    // 1. Manual Allocation Mode
    if (manualAllocations && manualAllocations.length > 0) {
      let sumAllocated = 0n;
      const finalAllocations: { obligationId: string; amountMinor: bigint }[] = [];

      for (const item of manualAllocations) {
        if (item.amountMinor <= 0n) {
          throw new DomainError('VALIDATION_ERROR', 'Individual allocation amount must be positive');
        }

        const target = obligations.find((o) => o.id === item.obligationId);
        if (!target) {
          throw new DomainError(
            'VALIDATION_ERROR',
            `Obligation ${item.obligationId} does not belong to this member and committee`
          );
        }

        if (item.amountMinor > target.remainingAmountMinor) {
          throw new DomainError(
            'ALLOCATION_EXCEEDS_COLLECTION',
            `Allocation of ${item.amountMinor} paisa exceeds remaining due ${target.remainingAmountMinor} on obligation ${item.obligationId}`
          );
        }

        if (item.amountMinor < target.remainingAmountMinor && !allowPartialPayment) {
          throw new DomainError(
            'PARTIAL_PAYMENT_NOT_ALLOWED',
            `Partial payment is not enabled for this committee on obligation ${item.obligationId}`
          );
        }

        sumAllocated += item.amountMinor;
        finalAllocations.push({
          obligationId: item.obligationId,
          amountMinor: item.amountMinor,
        });
      }

      if (sumAllocated > collectionAmountMinor) {
        throw new DomainError(
          'ALLOCATION_EXCEEDS_COLLECTION',
          `Sum of allocations (${sumAllocated}) exceeds total collection amount (${collectionAmountMinor})`
        );
      }

      const remainder = collectionAmountMinor - sumAllocated;
      if (remainder > 0n && !allowUnallocatedCredit) {
        throw new DomainError(
          'OVERPAYMENT_NOT_ALLOWED',
          `Collection amount (${collectionAmountMinor}) exceeds allocated amount (${sumAllocated}), and unallocated credit is not permitted`
        );
      }

      return {
        allocations: finalAllocations,
        unallocatedRemainderMinor: remainder,
        totalAllocatedMinor: sumAllocated,
      };
    }

    // 2. FIFO Oldest-First Mode
    if (allocationPolicy === 'MANUAL') {
      throw new DomainError(
        'ALLOCATION_REQUIRED',
        'Committee requires manual allocation per obligation'
      );
    }

    // Sort obligations chronologically by dueDate ascending
    const sortedObligations = [...obligations].sort((a, b) => a.dueDate.localeCompare(b.dueDate));

    let unallocatedRemaining = collectionAmountMinor;
    const finalAllocations: { obligationId: string; amountMinor: bigint }[] = [];
    let sumAllocated = 0n;

    for (const ob of sortedObligations) {
      if (unallocatedRemaining === 0n) break;
      if (ob.remainingAmountMinor <= 0n) continue;

      const alloc =
        unallocatedRemaining < ob.remainingAmountMinor
          ? unallocatedRemaining
          : ob.remainingAmountMinor;

      if (alloc < ob.remainingAmountMinor && !allowPartialPayment) {
        throw new DomainError(
          'PARTIAL_PAYMENT_NOT_ALLOWED',
          `Partial payment is not enabled for this committee (obligation ${ob.id} requires ${ob.remainingAmountMinor}, but only ${alloc} available)`
        );
      }

      finalAllocations.push({
        obligationId: ob.id,
        amountMinor: alloc,
      });

      sumAllocated += alloc;
      unallocatedRemaining -= alloc;
    }

    if (unallocatedRemaining > 0n && !allowUnallocatedCredit) {
      throw new DomainError(
        'OVERPAYMENT_NOT_ALLOWED',
        `Collection of ${collectionAmountMinor} paisa exceeds all open dues by ${unallocatedRemaining} paisa`
      );
    }

    return {
      allocations: finalAllocations,
      unallocatedRemainderMinor: unallocatedRemaining,
      totalAllocatedMinor: sumAllocated,
    };
  }
}
