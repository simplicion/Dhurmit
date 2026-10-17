// modules/schedule/domain/schedule-generator.ts
// Deterministic schedule generator with month-end day clamping and leap-year handling.

export type ContributionFrequency = 'DAILY' | 'WEEKLY' | 'MONTHLY' | 'CUSTOM';
export type DurationUnit = 'DAY' | 'MONTH';

export interface ScheduleRuleConfig {
  dayOfMonth?: number;
  monthEndPolicy?: 'CLAMP_TO_LAST_DAY' | 'SKIP';
  dayOfWeek?: number; // 0=Sunday, 6=Saturday
  skipWeekends?: boolean;
  customDates?: string[]; // YYYY-MM-DD
}

export interface GenerateScheduleParams {
  startDate: string; // YYYY-MM-DD
  durationCount: number;
  durationUnit: DurationUnit;
  frequency: ContributionFrequency;
  rule?: ScheduleRuleConfig;
}

export class ScheduleGenerator {
  static generateDueDates(params: GenerateScheduleParams): string[] {
    const { startDate, durationCount, durationUnit, frequency, rule } = params;

    if (frequency === 'CUSTOM' && rule?.customDates && rule.customDates.length > 0) {
      return [...new Set(rule.customDates)].sort();
    }

    const dueDates: string[] = [];
    const start = this.parseDateString(startDate);

    if (frequency === 'DAILY') {
      const totalDays = durationUnit === 'MONTH' ? durationCount * 30 : durationCount;
      const current = new Date(start);

      while (dueDates.length < totalDays) {
        // If skipWeekends is specified, skip Saturday (day 6 in Nepal or standard)
        if (rule?.skipWeekends && current.getDay() === 6) {
          current.setDate(current.getDate() + 1);
          continue;
        }
        dueDates.push(this.formatDateString(current));
        current.setDate(current.getDate() + 1);
      }
      return dueDates;
    }

    if (frequency === 'WEEKLY') {
      const current = new Date(start);
      for (let i = 0; i < durationCount; i++) {
        dueDates.push(this.formatDateString(current));
        current.setDate(current.getDate() + 7);
      }
      return dueDates;
    }

    if (frequency === 'MONTHLY') {
      const targetDay = rule?.dayOfMonth ?? start.getDate();
      const startYear = start.getFullYear();
      const startMonth = start.getMonth();

      for (let m = 0; m < durationCount; m++) {
        const year = startYear + Math.floor((startMonth + m) / 12);
        const month = (startMonth + m) % 12;

        const maxDaysInMonth = this.getDaysInMonth(year, month);
        const clampedDay = Math.min(targetDay, maxDaysInMonth);

        const obligationDate = new Date(year, month, clampedDay);
        dueDates.push(this.formatDateString(obligationDate));
      }
      return dueDates;
    }

    return dueDates;
  }

  static getDaysInMonth(year: number, monthIndex: number): number {
    // monthIndex is 0-based. Day 0 of next month returns last day of current month
    return new Date(year, monthIndex + 1, 0).getDate();
  }

  static parseDateString(dateStr: string): Date {
    const [y, m, d] = dateStr.split('-').map(Number);
    if (!y || !m || !d) {
      throw new Error(`Invalid date format: ${dateStr}. Expected YYYY-MM-DD`);
    }
    return new Date(y, m - 1, d);
  }

  static formatDateString(d: Date): string {
    const year = d.getFullYear();
    const month = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  }
}
