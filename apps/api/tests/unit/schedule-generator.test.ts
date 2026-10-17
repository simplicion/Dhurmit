// apps/api/tests/unit/schedule-generator.test.ts
import { describe, it, expect } from 'vitest';
import { ScheduleGenerator } from '../../src/modules/schedule/domain/schedule-generator.js';

describe('ScheduleGenerator Exhaustive Tests', () => {
  describe('Daily Schedules', () => {
    it('generates single day schedule', () => {
      const dates = ScheduleGenerator.generateDueDates({
        startDate: '2026-05-15',
        durationCount: 1,
        durationUnit: 'DAY',
        frequency: 'DAILY',
      });
      expect(dates).toEqual(['2026-05-15']);
    });

    it('generates 7 consecutive days', () => {
      const dates = ScheduleGenerator.generateDueDates({
        startDate: '2026-06-01',
        durationCount: 7,
        durationUnit: 'DAY',
        frequency: 'DAILY',
      });
      expect(dates).toHaveLength(7);
      expect(dates[0]).toBe('2026-06-01');
      expect(dates[6]).toBe('2026-06-07');
    });

    it('generates consecutive days crossing month boundaries', () => {
      const dates = ScheduleGenerator.generateDueDates({
        startDate: '2026-04-29',
        durationCount: 4,
        durationUnit: 'DAY',
        frequency: 'DAILY',
      });
      expect(dates).toEqual(['2026-04-29', '2026-04-30', '2026-05-01', '2026-05-02']);
    });

    it('generates consecutive days crossing year boundaries', () => {
      const dates = ScheduleGenerator.generateDueDates({
        startDate: '2026-12-30',
        durationCount: 3,
        durationUnit: 'DAY',
        frequency: 'DAILY',
      });
      expect(dates).toEqual(['2026-12-30', '2026-12-31', '2027-01-01']);
    });

    it('handles daily schedule specified in MONTH duration units (30 days/month)', () => {
      const dates = ScheduleGenerator.generateDueDates({
        startDate: '2026-01-01',
        durationCount: 2,
        durationUnit: 'MONTH',
        frequency: 'DAILY',
      });
      expect(dates).toHaveLength(60);
      expect(dates[0]).toBe('2026-01-01');
      expect(dates[59]).toBe('2026-03-01');
    });

    it('skips Saturdays when skipWeekends is enabled', () => {
      // 2026-10-17 is Saturday, 2026-10-18 is Sunday
      const dates = ScheduleGenerator.generateDueDates({
        startDate: '2026-10-16', // Friday
        durationCount: 3,
        durationUnit: 'DAY',
        frequency: 'DAILY',
        rule: { skipWeekends: true },
      });
      // 2026-10-16 (Fri), skip 17 (Sat), 2026-10-18 (Sun), 2026-10-19 (Mon)
      expect(dates).toEqual(['2026-10-16', '2026-10-18', '2026-10-19']);
    });
  });

  describe('Weekly Schedules', () => {
    it('generates weekly occurrences with exactly 7-day intervals', () => {
      const dates = ScheduleGenerator.generateDueDates({
        startDate: '2026-11-01',
        durationCount: 4,
        durationUnit: 'MONTH',
        frequency: 'WEEKLY',
      });
      expect(dates).toEqual([
        '2026-11-01',
        '2026-11-08',
        '2026-11-15',
        '2026-11-22',
      ]);
    });

    it('generates weekly dates crossing year boundary', () => {
      const dates = ScheduleGenerator.generateDueDates({
        startDate: '2026-12-25',
        durationCount: 3,
        durationUnit: 'DAY',
        frequency: 'WEEKLY',
      });
      expect(dates).toEqual(['2026-12-25', '2027-01-01', '2027-01-08']);
    });

    it('generates 52 weeks for a full year committee', () => {
      const dates = ScheduleGenerator.generateDueDates({
        startDate: '2026-01-01',
        durationCount: 52,
        durationUnit: 'DAY',
        frequency: 'WEEKLY',
      });
      expect(dates).toHaveLength(52);
      expect(dates[0]).toBe('2026-01-01');
      expect(dates[51]).toBe('2026-12-24');
    });
  });

  describe('Monthly Schedules & Day Clamping', () => {
    it('generates standard mid-month day schedules without clamping', () => {
      const dates = ScheduleGenerator.generateDueDates({
        startDate: '2026-01-15',
        durationCount: 6,
        durationUnit: 'MONTH',
        frequency: 'MONTHLY',
        rule: { dayOfMonth: 15 },
      });
      expect(dates).toEqual([
        '2026-01-15',
        '2026-02-15',
        '2026-03-15',
        '2026-04-15',
        '2026-05-15',
        '2026-06-15',
      ]);
    });

    it('generates 1st of the month schedule across 12 months', () => {
      const dates = ScheduleGenerator.generateDueDates({
        startDate: '2026-01-01',
        durationCount: 12,
        durationUnit: 'MONTH',
        frequency: 'MONTHLY',
        rule: { dayOfMonth: 1 },
      });
      expect(dates).toHaveLength(12);
      expect(dates[0]).toBe('2026-01-01');
      expect(dates[11]).toBe('2026-12-01');
    });

    it('clamps day 31 across all 12 months in a non-leap year (2025)', () => {
      const dates = ScheduleGenerator.generateDueDates({
        startDate: '2025-01-31',
        durationCount: 12,
        durationUnit: 'MONTH',
        frequency: 'MONTHLY',
        rule: { dayOfMonth: 31 },
      });

      expect(dates).toEqual([
        '2025-01-31', // Jan 31
        '2025-02-28', // Feb 28 (non-leap)
        '2025-03-31', // Mar 31
        '2025-04-30', // Apr 30
        '2025-05-31', // May 31
        '2025-06-30', // Jun 30
        '2025-07-31', // Jul 31
        '2025-08-31', // Aug 31
        '2025-09-30', // Sep 30
        '2025-10-31', // Oct 31
        '2025-11-30', // Nov 30
        '2025-12-31', // Dec 31
      ]);
    });

    it('clamps day 31 to Feb 29 in leap year 2024', () => {
      const dates = ScheduleGenerator.generateDueDates({
        startDate: '2024-01-31',
        durationCount: 3,
        durationUnit: 'MONTH',
        frequency: 'MONTHLY',
        rule: { dayOfMonth: 31 },
      });
      expect(dates[1]).toBe('2024-02-29');
    });

    it('clamps day 31 to Feb 29 in next leap year 2028', () => {
      const dates = ScheduleGenerator.generateDueDates({
        startDate: '2028-01-31',
        durationCount: 3,
        durationUnit: 'MONTH',
        frequency: 'MONTHLY',
        rule: { dayOfMonth: 31 },
      });
      expect(dates[1]).toBe('2028-02-29');
    });

    it('clamps day 30 to Feb 28 in non-leap year and Feb 29 in leap year', () => {
      const nonLeap = ScheduleGenerator.generateDueDates({
        startDate: '2026-01-30',
        durationCount: 2,
        durationUnit: 'MONTH',
        frequency: 'MONTHLY',
        rule: { dayOfMonth: 30 },
      });
      expect(nonLeap[1]).toBe('2026-02-28');

      const leap = ScheduleGenerator.generateDueDates({
        startDate: '2024-01-30',
        durationCount: 2,
        durationUnit: 'MONTH',
        frequency: 'MONTHLY',
        rule: { dayOfMonth: 30 },
      });
      expect(leap[1]).toBe('2024-02-29');
    });

    it('clamps day 29 to Feb 28 in non-leap years', () => {
      const nonLeap = ScheduleGenerator.generateDueDates({
        startDate: '2027-01-29',
        durationCount: 2,
        durationUnit: 'MONTH',
        frequency: 'MONTHLY',
        rule: { dayOfMonth: 29 },
      });
      expect(nonLeap[1]).toBe('2027-02-28');
    });

    it('spans multi-year duration count (24 months)', () => {
      const dates = ScheduleGenerator.generateDueDates({
        startDate: '2026-06-10',
        durationCount: 24,
        durationUnit: 'MONTH',
        frequency: 'MONTHLY',
        rule: { dayOfMonth: 10 },
      });
      expect(dates).toHaveLength(24);
      expect(dates[0]).toBe('2026-06-10');
      expect(dates[12]).toBe('2027-06-10');
      expect(dates[23]).toBe('2028-05-10');
    });
  });

  describe('Custom Frequency', () => {
    it('sorts and deduplicates custom dates', () => {
      const dates = ScheduleGenerator.generateDueDates({
        startDate: '2026-01-01',
        durationCount: 0,
        durationUnit: 'DAY',
        frequency: 'CUSTOM',
        rule: {
          customDates: ['2026-03-15', '2026-01-10', '2026-03-15', '2026-02-20'],
        },
      });
      expect(dates).toEqual(['2026-01-10', '2026-02-20', '2026-03-15']);
    });
  });

  describe('Validation & Edge Cases', () => {
    it('throws error on invalid date string format', () => {
      expect(() =>
        ScheduleGenerator.generateDueDates({
          startDate: 'invalid-date',
          durationCount: 5,
          durationUnit: 'DAY',
          frequency: 'DAILY',
        })
      ).toThrow();
    });

    it('returns empty array when durationCount is 0 for daily/monthly', () => {
      const dates = ScheduleGenerator.generateDueDates({
        startDate: '2026-01-01',
        durationCount: 0,
        durationUnit: 'DAY',
        frequency: 'DAILY',
      });
      expect(dates).toEqual([]);
    });

    it('calculates getDaysInMonth correctly for all months in leap and non-leap years', () => {
      expect(ScheduleGenerator.getDaysInMonth(2024, 1)).toBe(29); // Feb 2024
      expect(ScheduleGenerator.getDaysInMonth(2025, 1)).toBe(28); // Feb 2025
      expect(ScheduleGenerator.getDaysInMonth(2026, 0)).toBe(31); // Jan
      expect(ScheduleGenerator.getDaysInMonth(2026, 3)).toBe(30); // Apr
      expect(ScheduleGenerator.getDaysInMonth(2026, 6)).toBe(31); // Jul
      expect(ScheduleGenerator.getDaysInMonth(2026, 7)).toBe(31); // Aug
      expect(ScheduleGenerator.getDaysInMonth(2026, 8)).toBe(30); // Sep
    });
  });
});
