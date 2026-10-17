// modules/ledger/domain/status-calculator.ts
// Authoritative obligation status calculation based on dates, allocations, and amounts.

export type ObligationStatus =
  | 'UPCOMING'
  | 'UNPAID_OVERDUE'
  | 'PARTIALLY_PAID'
  | 'PAID_ON_TIME'
  | 'PAID_LATE';

export interface AllocationDetail {
  amountMinor: bigint;
  receivedAt: string | Date; // UTC or ISO timestamp
}

export interface CalculateStatusParams {
  dueDate: string; // YYYY-MM-DD
  dueAmountMinor: bigint;
  allocations: AllocationDetail[];
  currentDateInZone?: string; // YYYY-MM-DD in committee timezone
}

export interface CalculatedObligationState {
  dueAmountMinor: bigint;
  allocatedAmountMinor: bigint;
  outstandingAmountMinor: bigint;
  status: ObligationStatus;
  isOverdue: boolean;
  latestReceivedDate?: string;
}

export class StatusCalculator {
  static calculate(params: CalculateStatusParams): CalculatedObligationState {
    const { dueDate, dueAmountMinor, allocations } = params;

    const todayStr =
      params.currentDateInZone ??
      new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Kathmandu' }).format(new Date());

    let totalAllocated = 0n;
    let anyReceivedAfterDueDate = false;
    let latestReceived: Date | null = null;

    for (const alloc of allocations) {
      totalAllocated += alloc.amountMinor;
      const allocDate = new Date(alloc.receivedAt);

      if (!latestReceived || allocDate > latestReceived) {
        latestReceived = allocDate;
      }

      // Format allocation date in committee timezone
      const allocDateStr = new Intl.DateTimeFormat('en-CA', {
        timeZone: 'Asia/Kathmandu',
      }).format(allocDate);

      if (allocDateStr > dueDate) {
        anyReceivedAfterDueDate = true;
      }
    }

    const outstanding = dueAmountMinor > totalAllocated ? dueAmountMinor - totalAllocated : 0n;
    const isPastDue = dueDate < todayStr;

    let status: ObligationStatus;

    if (totalAllocated >= dueAmountMinor) {
      status = anyReceivedAfterDueDate ? 'PAID_LATE' : 'PAID_ON_TIME';
    } else if (totalAllocated > 0n) {
      status = 'PARTIALLY_PAID';
    } else if (isPastDue) {
      status = 'UNPAID_OVERDUE';
    } else {
      status = 'UPCOMING';
    }

    return {
      dueAmountMinor,
      allocatedAmountMinor: totalAllocated,
      outstandingAmountMinor: outstanding,
      status,
      isOverdue: isPastDue && outstanding > 0n,
      latestReceivedDate: latestReceived ? latestReceived.toISOString() : undefined,
    };
  }
}
